import Foundation
import IOKit.hid
import JoyConVibeCore
import os

let transportLog = Logger(subsystem: "com.aqxp.JoyConVibeRemote", category: "transport")

private let nintendoVendorID = 0x057E
private let rightJoyConProductID = 0x2007

/// Delivers reports from up to one left and one right Joy-Con. Every event
/// names the controller it came from.
protocol JoyConTransport: AnyObject {
    var onConnected: ((JoyConSide, String) -> Void)? { get set }
    var onDisconnected: ((JoyConSide) -> Void)? { get set }
    var onRecovering: ((JoyConSide) -> Void)? { get set }
    var onFrame: ((JoyConSide, JoyConInputFrame) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var isRunning: Bool { get }
    func start()
    func stop()
    /// Asks a controller to drop its Bluetooth link and sleep. It wakes
    /// and reconnects when any button is pressed.
    func requestSleep(_ side: JoyConSide)
}

final class JoyConHIDTransport: JoyConTransport {
    var onConnected: ((JoyConSide, String) -> Void)?
    var onDisconnected: ((JoyConSide) -> Void)?
    var onRecovering: ((JoyConSide) -> Void)?
    var onFrame: ((JoyConSide, JoyConInputFrame) -> Void)?
    var onError: ((String) -> Void)?

    private var manager: IOHIDManager?
    private var session: JoyConHIDSession?
    private(set) var isRunning = false

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        transportLog.notice("transport start")

        // A manager that was closed and reopened keeps its device set but no
        // longer reports already-connected devices to the matching callback,
        // so turning the remote off and on never reconnected. Start fresh.
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: nintendoVendorID,
            kIOHIDProductIDKey: rightJoyConProductID,
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_GamePad
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, joyConDeviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, joyConDeviceRemoved, context)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            // Opening can fail after callbacks have already been scheduled.
            // Tear those down before allowing a later permission retry.
            stop()
            onError?("无法读取右 Joy-Con（IOKit 错误 \(result)）。请授予输入监控权限后点击「重新连接」；若系统要求退出并重新打开，请重启 App。")
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        transportLog.notice("transport stop")
        session?.stop()
        session = nil
        guard let manager else { return }
        self.manager = nil
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func requestSleep(_ side: JoyConSide) {
        transportLog.notice("sleep requested, session=\(self.session != nil)")
        session?.requestSleep()
    }

    fileprivate func didMatch(device: IOHIDDevice) {
        transportLog.notice("device matched, running=\(self.isRunning), hasSession=\(self.session != nil)")
        guard isRunning, session == nil else { return }
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
            ?? "Joy-Con (R)"
        let newSession = JoyConHIDSession(device: device)
        newSession.onFrame = { [weak self] frame in
            self?.onFrame?(.right, frame)
        }
        newSession.onRecovering = { [weak self] in
            self?.onRecovering?(.right)
        }
        newSession.onError = { [weak self] message in
            self?.onError?(message)
        }
        session = newSession
        newSession.start()
        onConnected?(.right, productName)
    }

    fileprivate func didRemove(device: IOHIDDevice) {
        transportLog.notice("device removed, ownsSession=\(self.session.map { CFEqual($0.device, device) } ?? false)")
        guard let session, CFEqual(session.device, device) else { return }
        session.stop()
        self.session = nil
        onDisconnected?(.right)
    }
}

private func joyConDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<JoyConHIDTransport>.fromOpaque(context).takeUnretainedValue().didMatch(device: device)
}

private func joyConDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    Unmanaged<JoyConHIDTransport>.fromOpaque(context).takeUnretainedValue().didRemove(device: device)
}

private final class JoyConHIDSession {
    let device: IOHIDDevice
    var onFrame: ((JoyConInputFrame) -> Void)?
    var onRecovering: (() -> Void)?
    var onError: ((String) -> Void)?

    private var parser = JoyConReportParser()
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportBufferSize: Int
    private var packetCounter: UInt8 = 0
    private var stopped = false
    private var streamWatchdog = JoyConStreamWatchdog()
    private var isRecoveringStream = false

    init(device: IOHIDDevice) {
        self.device = device
        let configuredSize = (IOHIDDeviceGetProperty(
            device,
            kIOHIDMaxInputReportSizeKey as CFString
        ) as? NSNumber)?.intValue ?? 64
        reportBufferSize = max(64, configuredSize)
        reportBuffer = .allocate(capacity: reportBufferSize)
        reportBuffer.initialize(repeating: 0, count: reportBufferSize)
    }

    deinit {
        reportBuffer.deinitialize(count: reportBufferSize)
        reportBuffer.deallocate()
    }

    func start() {
        stopped = false
        isRecoveringStream = false
        streamWatchdog.start(at: ProcessInfo.processInfo.systemUptime)
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            reportBufferSize,
            joyConInputReport,
            Unmanaged.passUnretained(self).toOpaque()
        )

        // Joy-Con accepts subcommands serially. Small gaps keep initialization
        // reliable over Bluetooth while reports begin streaming.
        schedule(after: 0.05) { $0.readSPI(address: 0x6020, length: 0x18) }
        schedule(after: 0.14) { $0.readSPI(address: 0x6046, length: 0x09) }
        schedule(after: 0.24) { $0.sendStreamConfiguration() }
        scheduleStreamWatchdogTick()
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, reportBufferSize, nil, nil)
    }

    fileprivate func receive(reportID: UInt32, report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard !stopped, length > 0 else { return }
        let count = min(Int(length), reportBufferSize)
        let bytes = Array(UnsafeBufferPointer(start: report, count: count))
        if reportID == 0x30 {
            streamWatchdog.recordStandardReport(at: ProcessInfo.processInfo.systemUptime)
            isRecoveringStream = false
        }
        guard let decoded = parser.decode(reportID: UInt8(truncatingIfNeeded: reportID), bytes: bytes) else {
            return
        }
        if let frame = decoded.frame {
            onFrame?(frame)
        }
    }

    private func schedule(after delay: TimeInterval, operation: @escaping (JoyConHIDSession) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped else { return }
            operation(self)
        }
    }

    private func scheduleStreamWatchdogTick() {
        schedule(after: 0.25) { session in
            let now = ProcessInfo.processInfo.systemUptime
            if session.streamWatchdog.shouldRecover(at: now) {
                if !session.isRecoveringStream {
                    transportLog.notice("input stream stalled; reconfiguring")
                    session.isRecoveringStream = true
                    session.onRecovering?()
                }
                session.sendStreamConfiguration()
            }
            session.scheduleStreamWatchdogTick()
        }
    }

    func requestSleep() {
        // Subcommand 0x06 sets the HCI state; 0x00 disconnects into sleep.
        sendSubcommand(id: 0x06, data: [0x00])
    }

    private func sendStreamConfiguration() {
        sendSubcommand(id: 0x03, data: [0x30])
        schedule(after: 0.12) { $0.sendSubcommand(id: 0x40, data: [0x01]) }
        schedule(after: 0.24) { $0.sendSubcommand(id: 0x30, data: [0x01]) }
    }

    private func readSPI(address: UInt32, length: UInt8) {
        let data: [UInt8] = [
            UInt8(address & 0xFF),
            UInt8((address >> 8) & 0xFF),
            UInt8((address >> 16) & 0xFF),
            UInt8((address >> 24) & 0xFF),
            length
        ]
        sendSubcommand(id: 0x10, data: data)
    }

    private func sendSubcommand(id: UInt8, data: [UInt8]) {
        packetCounter = (packetCounter + 1) & 0x0F
        let neutralRumble: [UInt8] = [0x00, 0x01, 0x00, 0x40, 0x00, 0x01, 0x00, 0x40]
        var report = [UInt8(0x01), packetCounter] + neutralRumble + [id] + data
        let reportCount = report.count
        let result: IOReturn = report.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return kIOReturnBadArgument }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(0x01),
                base,
                reportCount
            )
        }
        if result != kIOReturnSuccess {
            transportLog.error("subcommand 0x\(String(id, radix: 16)) failed: \(result)")
            onError?("Joy-Con 初始化命令失败（IOKit 错误 \(result)）。")
        }
    }
}

private func joyConInputReport(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<JoyConHIDSession>.fromOpaque(context).takeUnretainedValue().receive(
        reportID: reportID,
        report: report,
        length: reportLength
    )
}
