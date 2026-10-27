import AppKit
import Combine
import Foundation
import IOKit.hid
import JoyConVibeCore
import os

private let modelLog = Logger(subsystem: "com.aqxp.JoyConVibeRemote", category: "model")

enum InputMonitoringAccess: Equatable {
    case granted
    case denied
    case undetermined
}

enum RemoteStatus: Equatable {
    case disconnected
    case initializing
    case calibrating(Double)
    case connected
    case paused
    case sleeping
    case active
    case precision
    case error

    var title: String {
        switch self {
        case .disconnected: return "等待 Joy-Con"
        case .initializing: return "正在初始化"
        case .calibrating: return "请将手柄静置"
        case .connected: return "已连接"
        case .paused: return "遥控已暂停"
        case .sleeping: return "手柄已休眠"
        case .active: return "体感鼠标开启"
        case .precision: return "精准瞄准"
        case .error: return "需要处理"
        }
    }

    var symbolName: String {
        switch self {
        case .disconnected: return "gamecontroller"
        case .initializing: return "antenna.radiowaves.left.and.right"
        case .calibrating: return "gyroscope"
        case .connected: return "gamecontroller.fill"
        case .paused: return "pause.circle.fill"
        case .sleeping: return "moon.zzz"
        case .active: return "scope"
        case .precision: return "viewfinder"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var status: RemoteStatus = .disconnected
    @Published private(set) var deviceName = "Joy-Con (R)"
    @Published private(set) var batteryLevel = 0
    @Published private(set) var isCharging = false
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loginItemMessage: String?
    @Published private(set) var isConnected = false
    @Published private(set) var inputMonitoringAccess = InputMonitoringAccess.undetermined
    /// The controller whose input is used. Whoever presses a button takes over.
    @Published private(set) var activeSide: JoyConSide?
    /// The other controller, while it is connected but not in use.
    @Published private(set) var standbySide: JoyConSide?

    let settings: RemoteSettings
    let liveInput = LiveInput()
    let pressHighlight = PressHighlight()
    var onShowStatus: (() -> Void)?
    var onOpenSettings: ((SettingsPage) -> Void)?

    private let eventEmitter = SystemEventEmitter()
    private let loginItemManager: LoginItemManager
    private let managesLoginItem: Bool
    private lazy var pointerMotionEmitter = PointerMotionEmitter(eventEmitter: eventEmitter)
    private var mapper = RemoteActionMapper()
    // Each controller keeps its own gyro zero, so switching never applies one
    // controller's bias to the other.
    private var pointerEngines: [JoyConSide: GyroPointerEngine] = [:]
    private var pointerFrameBuffer = ClutchedPointerFrameBuffer()
    private var pointerTuningLifecycle = PointerTuningLifecycle()
    private let transport: any JoyConTransport
    private var hasStarted = false
    private var arbiter = ActiveControllerArbiter()
    /// Buttons each controller held in its last report, including reports
    /// ignored while it was on standby.
    private var heldButtons: [JoyConSide: Set<JoyConButton>] = [:]
    /// Buttons the active controller already held when it took over. They
    /// do nothing until released, so a button squashed on a standby
    /// controller never fires, repeats or moves the pointer on a hand-off.
    private var mustRelease = Set<JoyConButton>()
    /// What each controller was last told: standby or full reports.
    private var standbyState: [JoyConSide: Bool] = [:]
    private var deviceNames: [JoyConSide: String] = [:]
    private var telemetry: [JoyConSide: (level: Int, charging: Bool)] = [:]
    private var idlePolicies: [JoyConSide: IdleSleepPolicy] = [:]
    private var sleepRequested = Set<JoyConSide>()
    private var idleTimer: Timer?
    private let actionSink: ((RemoteAction) -> Void)?
    private let clock: () -> TimeInterval

    init(
        settings: RemoteSettings,
        transport: (any JoyConTransport)? = nil,
        loginItemManager: LoginItemManager? = nil,
        managesLoginItem: Bool = Bundle.main.bundleURL.pathExtension == "app",
        actionSink: ((RemoteAction) -> Void)? = nil,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.settings = settings
        self.actionSink = actionSink
        self.clock = clock
        self.transport = transport ?? JoyConHIDTransport()
        self.loginItemManager = loginItemManager ?? LoginItemManager()
        self.managesLoginItem = managesLoginItem
        configureTransport()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        accessibilityTrusted = eventEmitter.requestAccessibility(prompt: true)
        refreshInputMonitoringAccess()
        setLaunchAtLogin(settings.launchAtLogin)
        transport.start()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdleSleep() }
        }
    }

    func stop() {
        hasStarted = false
        idleTimer?.invalidate()
        idleTimer = nil
        transport.stop()
        releaseAllInputs()
    }

    func setRemoteEnabled(_ enabled: Bool) {
        settings.enabled = enabled
        if enabled {
            reconnect()
        } else {
            releaseAllInputs()
            for side in pointerEngines.keys { pointerEngines[side]?.resetMotion() }
            pointerFrameBuffer.reset()
            if isConnected { updateStatus(.paused) }
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard managesLoginItem else { return }
        do {
            try loginItemManager.setEnabled(enabled)
            refreshLoginItemStatus()
        } catch {
            settings.launchAtLogin = loginItemManager.isRegistered
            loginItemMessage = "登录启动设置失败：\(error.localizedDescription)"
        }
    }

    private func refreshLoginItemStatus() {
        guard managesLoginItem else { return }
        let registered = loginItemManager.isRegistered
        if settings.launchAtLogin != registered { settings.launchAtLogin = registered }
        loginItemMessage = loginItemManager.requiresApproval
            ? "登录启动等待批准，请在系统设置 → 通用 → 登录项中允许。也可取消勾选以撤销注册。"
            : nil
    }

    func reconnect() {
        hasStarted = true
        releaseAllInputs()
        transport.stop()
        arbiter.reset()
        heldButtons = [:]
        standbyState = [:]
        mustRelease = []
        refreshControllers()
        telemetry = [:]
        sleepRequested = []
        updateTelemetry(batteryLevel: 0, isCharging: false)
        pointerEngines = [:]
        errorMessage = nil
        updateStatus(.disconnected)
        transport.start()
    }

    func recalibrate() {
        if let activeSide { pointerEngines[activeSide, default: GyroPointerEngine()].beginCalibration() }
        pointerFrameBuffer.reset()
        pointerMotionEmitter.reset()
        updateStatus(.calibrating(0))
    }

    func setPointerTuningEditing(_ isEditing: Bool) {
        guard pointerTuningLifecycle.update(isEditing: isEditing) else { return }
        // A slider drag may span several IMU reports and leave scheduled mouse
        // deltas using intermediate gains. Commit the final value at a clean
        // clutch boundary without throwing away the established gyro bias.
        restartPointerMotion()
    }

    /// Picks pointer tracking back up after a reconnect or stream recovery.
    /// The gyro zero measured earlier stays valid: it is refined whenever the
    /// controller rests between clutches, and a woken controller is usually
    /// already in hand, where a stationary recalibration would never finish.
    private func resumePointerTracking(_ side: JoyConSide) {
        var engine = pointerEngines[side] ?? GyroPointerEngine()
        if engine.calibrationState == .ready {
            engine.resetMotion()
        } else {
            engine.beginCalibration()
        }
        pointerEngines[side] = engine
        if side == activeSide {
            pointerFrameBuffer.reset()
            pointerMotionEmitter.reset()
        }
    }

    private func restartPointerMotion() {
        for side in pointerEngines.keys { pointerEngines[side]?.resetMotion() }
        pointerFrameBuffer.reset()
        pointerMotionEmitter.reset()
    }

    func updateTelemetry(batteryLevel newBatteryLevel: Int, isCharging newIsCharging: Bool) {
        if batteryLevel != newBatteryLevel {
            batteryLevel = newBatteryLevel
        }
        if isCharging != newIsCharging {
            isCharging = newIsCharging
        }
    }

    func updateStatus(_ newStatus: RemoteStatus) {
        guard status != newStatus else { return }
        if case .calibrating = newStatus, case .calibrating = status {} else {
            modelLog.notice("status \(String(describing: self.status), privacy: .public) -> \(String(describing: newStatus), privacy: .public)")
        }
        status = newStatus
    }

    /// Puts each controller to sleep once it has gone untouched for the
    /// configured time, to save its battery.
    func checkIdleSleep(at now: TimeInterval? = nil) {
        let now = now ?? clock()
        let timeout = TimeInterval(settings.idleSleepMinutes) * 60
        for side in JoyConSide.allCases
        where arbiter.connected.contains(side)
            && !sleepRequested.contains(side)
            && idlePolicies[side, default: IdleSleepPolicy()].shouldSleep(at: now, timeout: timeout)
        {
            sleep(side)
        }
    }

    /// Sleeps every connected controller.
    func sleepController() {
        for side in JoyConSide.allCases where arbiter.connected.contains(side) {
            sleep(side)
        }
    }

    private func sleep(_ side: JoyConSide) {
        modelLog.notice("sleep \(side.rawValue, privacy: .public)")
        sleepRequested.insert(side)
        if side == activeSide { releaseAllInputs() }
        transport.requestSleep(side)
    }

    func deviceName(for side: JoyConSide) -> String {
        deviceNames[side] ?? side.defaultName
    }

    func openSettings(_ page: SettingsPage) {
        onOpenSettings?(page)
    }

    func resetPointerTuning() {
        settings.resetPointerTuning()
        restartPointerMotion()
    }

    func resetAllSettings() {
        settings.resetAll()
        restartPointerMotion()
    }

    func requestInputMonitoring() {
        if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
            openInputMonitoringSettings()
        }
        refreshInputMonitoringAccess()
    }

    private func refreshInputMonitoringAccess() {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: inputMonitoringAccess = .granted
        case kIOHIDAccessTypeDenied: inputMonitoringAccess = .denied
        default: inputMonitoringAccess = .undetermined
        }
    }

    func refreshPermissions() {
        accessibilityTrusted = eventEmitter.isAccessibilityTrusted
        refreshInputMonitoringAccess()
        refreshLoginItemStatus()
        if hasStarted && !transport.isRunning { reconnect() }
    }

    func requestAccessibility() {
        accessibilityTrusted = eventEmitter.requestAccessibility(prompt: true)
        if !accessibilityTrusted {
            eventEmitter.openAccessibilitySettings()
        }
    }

    func openInputMonitoringSettings() {
        eventEmitter.openInputMonitoringSettings()
    }

    func openBluetoothSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func configureTransport() {
        transport.onConnected = { [weak self] side, name in
            self?.controllerConnected(side, name: name)
        }
        transport.onDisconnected = { [weak self] side in
            self?.controllerDisconnected(side)
        }
        transport.onRecovering = { [weak self] side in
            guard let self, self.arbiter.connected.contains(side) else { return }
            if side == self.activeSide {
                self.releaseAllInputs()
                self.updateStatus(.initializing)
            }
            // Its inputs were released; what it held must not block a switch.
            self.arbiter.clearHeld(side)
            self.resumePointerTracking(side)
        }
        transport.onFrame = { [weak self] side, frame in
            self?.handle(frame: frame, from: side)
        }
        transport.onError = { [weak self] message in
            guard let self else { return }
            self.errorMessage = message
            self.updateStatus(.error)
        }
    }

    private func controllerConnected(_ side: JoyConSide, name: String) {
        modelLog.notice("connected \(side.rawValue, privacy: .public)")
        let wasActive = activeSide
        deviceNames[side] = name
        errorMessage = nil
        sleepRequested.remove(side)
        // Start the idle timer now: on standby it may never send a report.
        var idlePolicy = IdleSleepPolicy()
        idlePolicy.record(JoyConInputFrame(buttons: [], stick: .zero), at: clock())
        idlePolicies[side] = idlePolicy
        heldButtons[side] = nil
        standbyState[side] = nil
        _ = arbiter.connect(side)
        refreshControllers()
        resumePointerTracking(side)
        if wasActive == nil, activeSide == side {
            updateStatus(.initializing)
        }
    }

    private func controllerDisconnected(_ side: JoyConSide) {
        guard arbiter.connected.contains(side) else { return }
        modelLog.notice("disconnected \(side.rawValue, privacy: .public)")
        let wasActive = side == activeSide
        // A controller we put to sleep is not lost; say how to wake it.
        let wasAsleep = sleepRequested.remove(side) != nil
        telemetry[side] = nil
        idlePolicies[side] = nil
        heldButtons[side] = nil
        standbyState[side] = nil
        pointerEngines[side]?.resetMotion()
        if wasActive {
            releaseAllInputs()
            liveInput.reset()
        }
        _ = arbiter.disconnect(side)
        refreshControllers()
        guard wasActive else { return }
        if let next = activeSide {
            modelLog.notice("switch \(side.rawValue, privacy: .public) -> \(next.rawValue, privacy: .public)")
            mustRelease = heldButtons[next] ?? []
            showTelemetry(of: next)
            resumePointerTracking(next)
            updateStatus(calibratedStatus(for: next))
        } else {
            updateStatus(wasAsleep ? .sleeping : .disconnected)
        }
    }

    private func keepCalibrating(_ side: JoyConSide, with frame: JoyConInputFrame) {
        let pointerSettings = settings.pointerSettings(screenWidthPoints: activeScreenWidthPoints)
        var engine = pointerEngines[side] ?? GyroPointerEngine()
        for sample in frame.gyroSamples {
            _ = engine.process(sample: sample, isActive: false, isPrecision: false, settings: pointerSettings)
        }
        pointerEngines[side] = engine
    }

    /// Mirrors the arbiter into the published controller state.
    private func refreshControllers() {
        let active = arbiter.active
        if activeSide != active { activeSide = active }
        let standby = arbiter.connected.subtracting(active.map { [$0] } ?? []).first
        if standbySide != standby { standbySide = standby }
        let connected = !arbiter.connected.isEmpty
        if isConnected != connected { isConnected = connected }
        let name = deviceName(for: active ?? .right)
        if deviceName != name { deviceName = name }
        for side in arbiter.connected {
            let isStandby = side != active
            guard standbyState[side] != isStandby else { continue }
            standbyState[side] = isStandby
            transport.setStandby(side, isStandby)
        }
    }

    private func showTelemetry(of side: JoyConSide) {
        let reading = telemetry[side] ?? (0, false)
        updateTelemetry(batteryLevel: reading.level, isCharging: reading.charging)
    }

    private func calibratedStatus(for side: JoyConSide) -> RemoteStatus {
        switch pointerEngines[side]?.calibrationState {
        case let .calibrating(progress)?: return .calibrating(progress)
        case .ready?: return .connected
        case nil: return .calibrating(0)
        }
    }

    private func handle(frame incoming: JoyConInputFrame, from side: JoyConSide) {
        let timestamp = clock()
        let heldBefore = heldButtons[side]
        heldButtons[side] = incoming.buttons
        if !incoming.isButtonOnly {
            telemetry[side] = (incoming.batteryLevel, incoming.isCharging)
        }
        idlePolicies[side, default: IdleSleepPolicy()].record(incoming, at: timestamp)
        var frame = incoming

        switch arbiter.route(frame, from: side) {
        case .ignore:
            // A controller resting on standby still settles its own gyro zero,
            // so picking it up works without a stationary recalibration.
            keepCalibrating(side, with: frame)
            return
        case let .switchTo(next):
            // The press that switched acts; anything held before it waits.
            // A press seen in a standby report only switches: full reports
            // resume shortly and a button still held then acts.
            mustRelease = frame.isButtonOnly
                ? []
                : (heldBefore ?? frame.buttons).intersection(frame.buttons)
            if frame.isButtonOnly { heldButtons[next] = nil }
            if let previous = activeSide, previous != next {
                modelLog.notice("switch \(previous.rawValue, privacy: .public) -> \(next.rawValue, privacy: .public)")
                releaseAllInputs()
                liveInput.reset()
                pointerEngines[previous]?.resetMotion()
            }
            refreshControllers()
            showTelemetry(of: next)
            resumePointerTracking(next)
        case .accept:
            break
        }
        // Standby reports carry no motion and untrusted face buttons; they
        // only matter for switching.
        guard !frame.isButtonOnly else { return }
        mustRelease.formIntersection(frame.buttons)
        frame.buttons.subtract(mustRelease)

        updateTelemetry(
            batteryLevel: frame.batteryLevel,
            isCharging: frame.isCharging
        )
        liveInput.ingest(frame, timestamp: timestamp)
        pressHighlight.ingest(frame.buttons)
        guard settings.enabled else {
            if isConnected { updateStatus(.paused) }
            return
        }

        for action in mapper.process(
            frame: frame,
            timestamp: timestamp,
            buttonBindings: settings.buttonBindings(for: side),
            stickVerticalBinding: settings.stickVerticalBinding(for: side)
        ) {
            if action == .showStatus {
                onShowStatus?()
            } else {
                emit(action)
            }
        }

        let gyroActive = frame.buttons.contains(.zr)
        let precision = gyroActive && frame.buttons.contains(.sl)
        let pointerSettings = settings.pointerSettings(
            screenWidthPoints: activeScreenWidthPoints
        )
        var engine = pointerEngines[side] ?? GyroPointerEngine()
        let frameDeltas = frame.gyroSamples.compactMap { sample in
            engine.process(
                sample: sample,
                isActive: gyroActive,
                isPrecision: precision,
                settings: pointerSettings
            )
        }
        pointerEngines[side] = engine
        let confirmedDeltas = pointerFrameBuffer.process(
            frameDeltas: frameDeltas,
            isActive: gyroActive
        )
        if gyroActive {
            pointerMotionEmitter.emit(confirmedDeltas)
        } else {
            pointerMotionEmitter.reset()
        }

        switch engine.calibrationState {
        case let .calibrating(progress):
            updateStatus(.calibrating(progress))
        case .ready:
            if precision {
                updateStatus(.precision)
            } else if gyroActive {
                updateStatus(.active)
            } else {
                updateStatus(.connected)
            }
        }
    }

    private var activeScreenWidthPoints: Double {
        let mouseLocation = NSEvent.mouseLocation
        let width = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.frame.width
            ?? NSScreen.main?.frame.width
            ?? 1920
        return Double(width)
    }

    private func releaseAllInputs() {
        pointerFrameBuffer.reset()
        pointerMotionEmitter.reset()
        for action in mapper.reset() {
            emit(action)
        }
        eventEmitter.releaseAll()
    }

    private func emit(_ action: RemoteAction) {
        if let actionSink {
            actionSink(action)
        } else {
            eventEmitter.emit(action)
        }
    }
}
