import XCTest
import JoyConVibeCore
@testable import JoyConVibeRemote

@MainActor
final class ControllerSwitchingTests: XCTestCase {
    private final class Harness {
        let transport = FakeTransport()
        var actions: [RemoteAction] = []
        var now: TimeInterval = 1000
    }

    private func withModel(_ body: (AppModel, Harness) -> Void) {
        let suite = "ControllerSwitchingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let harness = Harness()
        let model = AppModel(
            settings: RemoteSettings(defaults: defaults),
            transport: harness.transport,
            managesLoginItem: false,
            actionSink: { [unowned harness] in harness.actions.append($0) },
            clock: { [unowned harness] in harness.now }
        )
        model.reconnect()
        body(model, harness)
    }

    private func connectCalibrated(_ side: JoyConSide, _ harness: Harness) {
        harness.transport.onConnected?(side, side.defaultName)
        TestFrames.still(60).forEach { harness.transport.onFrame?(side, $0) }
    }

    func testLeftAloneWorksLikeRight() {
        withModel { model, harness in
            connectCalibrated(.left, harness)
            XCTAssertEqual(model.activeSide, .left)
            XCTAssertNil(model.standbySide)
            XCTAssertEqual(model.deviceName, "Joy-Con (L)")
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testPressOnOtherControllerSwitchesAndTheSwitchingPressActs() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            XCTAssertEqual(model.activeSide, .right)
            XCTAssertEqual(model.standbySide, .left)

            harness.transport.onFrame?(.right, TestFrames.pressing([.y]))
            harness.transport.onFrame?(.right, TestFrames.pressing([]))
            harness.actions.removeAll()
            harness.transport.onFrame?(.left, TestFrames.pressing([.a]))

            XCTAssertEqual(model.activeSide, .left)
            XCTAssertEqual(model.standbySide, .right)
            XCTAssertEqual(model.deviceName, "Joy-Con (L)")
            XCTAssertTrue(harness.actions.contains(.keyTap(.escape)), "\(harness.actions)")
        }
    }

    func testNoSwitchWhileHoldingTrigger() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            harness.transport.onFrame?(.right, TestFrames.pressing([.zr]))
            harness.actions.removeAll()
            harness.transport.onFrame?(.left, TestFrames.pressing([.y]))
            XCTAssertEqual(model.activeSide, .right)
            XCTAssertEqual(harness.actions, [])
        }
    }

    func testActiveDisconnectWhileHoldingReleasesAndFallsBack() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            harness.transport.onFrame?(.right, TestFrames.pressing([.y]))
            XCTAssertEqual(harness.actions.last, .mouseButton(.left, isDown: true))

            harness.transport.onDisconnected?(.right)

            XCTAssertTrue(harness.actions.contains(.mouseButton(.left, isDown: false)), "\(harness.actions)")
            XCTAssertEqual(model.activeSide, .left)
            XCTAssertNil(model.standbySide)
            XCTAssertEqual(model.deviceName, "Joy-Con (L)")
            XCTAssertEqual(model.status, .connected)
            XCTAssertTrue(model.isConnected)
        }
    }

    func testBothGoneShowsDisconnectedNotStandby() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            harness.transport.onDisconnected?(.right)
            harness.transport.onDisconnected?(.left)
            XCTAssertNil(model.activeSide)
            XCTAssertNil(model.standbySide)
            XCTAssertFalse(model.isConnected)
            XCTAssertEqual(model.status, .disconnected)
        }
    }

    func testStandbyDisconnectLeavesActiveUntouched() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            harness.transport.onDisconnected?(.left)
            XCTAssertEqual(model.activeSide, .right)
            XCTAssertNil(model.standbySide)
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testSleepNowSleepsEveryController() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            model.sleepController()
            XCTAssertEqual(Set(harness.transport.sleptSides), [.right, .left])

            harness.transport.onDisconnected?(.right)
            harness.transport.onDisconnected?(.left)
            XCTAssertEqual(model.status, .sleeping)
        }
    }

    func testIdleTimersArePerController() {
        withModel { model, harness in
            model.settings.idleSleepMinutes = 30
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            harness.now += 20 * 60
            harness.transport.onFrame?(.right, TestFrames.pressing([.a]))

            model.checkIdleSleep(at: harness.now + 11 * 60)
            XCTAssertEqual(harness.transport.sleptSides, [.left])
            model.checkIdleSleep(at: harness.now + 12 * 60)
            XCTAssertEqual(harness.transport.sleptSides, [.left])
        }
    }

    func testCalibrationIsPerController() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            harness.transport.onFrame?(.left, TestFrames.pressing([.a]))
            harness.transport.onFrame?(.left, TestFrames.moving)
            XCTAssertEqual(model.status, .calibrating(0))

            harness.transport.onFrame?(.right, TestFrames.pressing([.b]))
            XCTAssertEqual(model.activeSide, .right)
            harness.transport.onFrame?(.right, TestFrames.moving)
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testLateConnectionDoesNotTakeOver() {
        withModel { model, harness in
            connectCalibrated(.left, harness)
            harness.transport.onConnected?(.right, "Joy-Con (R)")
            XCTAssertEqual(model.activeSide, .left)
            XCTAssertEqual(model.status, .connected)
        }
    }

    func testStandbyFramesDoNotTouchTheDisplayedBattery() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            harness.transport.onFrame?(.right, JoyConInputFrame(buttons: [], stick: .zero, batteryLevel: 3))
            harness.transport.onFrame?(.left, JoyConInputFrame(buttons: [], stick: .zero, batteryLevel: 1))
            XCTAssertEqual(model.batteryLevel, 3)
        }
    }
}
