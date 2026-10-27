import ServiceManagement
import XCTest
import JoyConVibeCore
@testable import JoyConVibeRemote

@MainActor
final class ReleaseLifecycleTests: XCTestCase {
    func testDisablingPendingLoginRegistrationActuallyUnregisters() throws {
        let service = FakeLoginService(status: .requiresApproval)
        let manager = LoginItemManager(service: service)
        try manager.setEnabled(false)
        XCTAssertEqual(service.unregisterCount, 1)
        XCTAssertFalse(manager.isRegistered)
    }

    func testEnablingPendingRegistrationDoesNotRegisterAgain() throws {
        let service = FakeLoginService(status: .requiresApproval)
        let manager = LoginItemManager(service: service)
        try manager.setEnabled(true)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertTrue(manager.requiresApproval)
    }

    func testLoginUnregisterFailureKeepsToggleConsistentWithSystem() {
        withModel { model, _, service in
            service.status = .requiresApproval
            service.failUnregister = true
            model.setLaunchAtLogin(false)
            XCTAssertTrue(model.settings.launchAtLogin)
            XCTAssertNotNil(model.loginItemMessage)
            service.failUnregister = false
            model.setLaunchAtLogin(false)
            XCTAssertFalse(model.settings.launchAtLogin)
            XCTAssertNil(model.loginItemMessage)
        }
    }

    func testFailedLoginRegistrationDoesNotLeaveToggleEnabled() {
        withModel { model, _, service in
            service.failRegister = true
            model.setLaunchAtLogin(true)
            XCTAssertFalse(model.settings.launchAtLogin)
            XCTAssertNotNil(model.loginItemMessage)
        }
    }

    func testPendingLoginApprovalIsExplainedAndExternalChangesAreReflected() {
        withModel { model, _, service in
            service.status = .requiresApproval
            model.refreshPermissions()
            XCTAssertTrue(model.settings.launchAtLogin)
            XCTAssertNotNil(model.loginItemMessage)
            service.status = .notRegistered
            model.refreshPermissions()
            XCTAssertFalse(model.settings.launchAtLogin)
            XCTAssertNil(model.loginItemMessage)
        }
    }

    func testPermissionsRefreshRetriesFailedOpenWithoutRestartingHealthyTransport() {
        withModel { model, transport, _ in
            transport.failStart = true
            model.reconnect()
            XCTAssertEqual(model.status, .error)
            XCTAssertFalse(transport.isRunning)
            transport.failStart = false
            model.refreshPermissions()
            XCTAssertEqual(transport.startCount, 2)
            XCTAssertTrue(transport.isRunning)
            XCTAssertNil(model.errorMessage)
            transport.onConnected?(.right, "Joy-Con (R)")
            XCTAssertEqual(model.status, .initializing)
            model.refreshPermissions()
            XCTAssertEqual(transport.startCount, 2)
        }
    }

    func testRemoteToggleReopensConnectionAndQuitPreventsRefreshRetry() {
        withModel { model, transport, _ in
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            model.setRemoteEnabled(false)
            XCTAssertEqual(model.status, .paused)
            model.setRemoteEnabled(true)
            XCTAssertEqual(transport.startCount, 2)
            XCTAssertEqual(transport.stopCount, 2)
            XCTAssertNil(model.errorMessage)
            model.stop()
            model.refreshPermissions()
            XCTAssertEqual(transport.startCount, 2)
        }
    }

    func testIdleControllerIsPutToSleepAndReportedAsSleeping() {
        withModel { model, transport, _ in
            model.settings.idleSleepMinutes = 30
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            transport.onFrame?(.right, JoyConInputFrame(buttons: [], stick: .zero))
            let now = ProcessInfo.processInfo.systemUptime

            model.checkIdleSleep(at: now + 29 * 60)
            XCTAssertEqual(transport.sleepCount, 0)
            model.checkIdleSleep(at: now + 31 * 60)
            XCTAssertEqual(transport.sleepCount, 1)
            // Repeated checks while the controller is going down send nothing more.
            model.checkIdleSleep(at: now + 32 * 60)
            XCTAssertEqual(transport.sleepCount, 1)

            transport.onDisconnected?(.right)
            XCTAssertEqual(model.status, .sleeping)

            // Pressing a button reconnects it and starts a fresh idle period.
            transport.onConnected?(.right, "Joy-Con (R)")
            XCTAssertEqual(model.status, .initializing)
            transport.onFrame?(.right, JoyConInputFrame(buttons: [.a], stick: .zero))
            model.checkIdleSleep(at: ProcessInfo.processInfo.systemUptime + 60)
            XCTAssertEqual(transport.sleepCount, 1)
        }
    }

    private func stillFrames(_ count: Int) -> [JoyConInputFrame] {
        let resting = GyroSample(degreesPerSecond: .zero, acceleration: Vector3(x: 0, y: 0, z: 4096))
        return Array(repeating: JoyConInputFrame(buttons: [], stick: .zero, gyroSamples: [resting, resting, resting]), count: count)
    }

    private var movingFrame: JoyConInputFrame {
        let moving = GyroSample(degreesPerSecond: Vector3(x: 0, y: 60, z: 0), acceleration: Vector3(x: 0, y: 0, z: 4096))
        return JoyConInputFrame(buttons: [], stick: .zero, gyroSamples: [moving, moving, moving])
    }

    func testWakingFromSleepKeepsTheCalibrationSoItWorksInHand() {
        withModel { model, transport, _ in
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            stillFrames(60).forEach { transport.onFrame?(.right, $0) }
            XCTAssertEqual(model.status, .connected)

            model.sleepController()
            transport.onDisconnected?(.right)
            transport.onConnected?(.right, "Joy-Con (R)")
            // Picked up and moving: no stationary recalibration is required.
            transport.onFrame?(.right, movingFrame)
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testStreamRecoveryKeepsTheCalibration() {
        withModel { model, transport, _ in
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            stillFrames(60).forEach { transport.onFrame?(.right, $0) }

            transport.onRecovering?(.right)
            transport.onFrame?(.right, movingFrame)
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testFirstConnectionAndExplicitRecalibrationStillCalibrate() {
        withModel { model, transport, _ in
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            transport.onFrame?(.right, movingFrame)
            XCTAssertEqual(model.status, .calibrating(0))

            stillFrames(60).forEach { transport.onFrame?(.right, $0) }
            model.recalibrate()
            transport.onFrame?(.right, movingFrame)
            XCTAssertEqual(model.status, .calibrating(0))
        }
    }

    func testIdleSleepCanBeTurnedOff() {
        withModel { model, transport, _ in
            model.settings.idleSleepMinutes = 0
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            transport.onFrame?(.right, JoyConInputFrame(buttons: [], stick: .zero))

            model.checkIdleSleep(at: ProcessInfo.processInfo.systemUptime + 24 * 3600)
            XCTAssertEqual(transport.sleepCount, 0)
        }
    }

    func testControllerLostWithoutASleepRequestIsReportedDisconnected() {
        withModel { model, transport, _ in
            model.reconnect()
            transport.onConnected?(.right, "Joy-Con (R)")
            transport.onDisconnected?(.right)
            XCTAssertEqual(model.status, .disconnected)
        }
    }

    private func withModel(_ body: (AppModel, FakeTransport, FakeLoginService) -> Void) {
        let suite = "ReleaseLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeTransport()
        let service = FakeLoginService(status: .notRegistered)
        let model = AppModel(
            settings: RemoteSettings(defaults: defaults),
            transport: transport,
            loginItemManager: LoginItemManager(service: service),
            managesLoginItem: true
        )
        body(model, transport, service)
    }
}

@MainActor
private final class FakeLoginService: LoginItemService {
    var status: SMAppService.Status
    var registerCount = 0
    var unregisterCount = 0
    var failRegister = false
    var failUnregister = false

    init(status: SMAppService.Status) { self.status = status }

    func register() throws {
        registerCount += 1
        if failRegister { throw NSError(domain: "test", code: 1) }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if failUnregister { throw NSError(domain: "test", code: 2) }
        status = .notRegistered
    }
}
