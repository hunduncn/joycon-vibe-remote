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

    private static func isDelete(_ action: RemoteAction) -> Bool {
        action == .keyTap(.deleteBackward) || action == .keyShortcut(.deleteBackward, modifiers: [])
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
            harness.transport.onFrame?(.left, TestFrames.pressing([]))

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
            harness.transport.onFrame?(.left, TestFrames.pressing([]))
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

    func testStandbyLineNamesTheIdleController() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            XCTAssertNil(model.standbyLine)
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            XCTAssertEqual(model.standbyLine, "Joy-Con (L) · 待机")
        }
    }

    func testDisconnectedDetailDoesNotNameASide() {
        withModel { model, _ in
            XCTAssertEqual(model.statusDetail, "请配对并唤醒 Joy-Con")
            XCTAssertEqual(model.status.title, "等待 Joy-Con")
        }
    }

    func testHighlightOnlyForTheActiveSide() {
        XCTAssertEqual(MappingPage.highlightedPart(button: .a, editingSide: .left, activeSide: .left, enabled: true), .a)
        XCTAssertNil(MappingPage.highlightedPart(button: .a, editingSide: .left, activeSide: .right, enabled: true))
        XCTAssertNil(MappingPage.highlightedPart(button: .a, editingSide: .right, activeSide: nil, enabled: true))
        XCTAssertNil(MappingPage.highlightedPart(button: .a, editingSide: .right, activeSide: .right, enabled: false))
        XCTAssertNil(MappingPage.highlightedPart(button: nil, editingSide: .right, activeSide: .right, enabled: true))
    }

    func testHeldStandbyButtonDoesNothingWhenItTakesOver() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            // Squashed in a bag: X is held from its very first report.
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            harness.transport.onFrame?(.left, TestFrames.pressing([.x]))
            harness.transport.onFrame?(.left, TestFrames.pressing([.x]))
            XCTAssertEqual(model.activeSide, .right)
            harness.transport.onDisconnected?(.right)
            XCTAssertEqual(model.activeSide, .left)
            for _ in 0..<5 {
                harness.now += 1
                harness.transport.onFrame?(.left, TestFrames.pressing([.x]))
            }
            XCTAssertFalse(harness.actions.contains(where: Self.isDelete), "\(harness.actions)")

            harness.transport.onFrame?(.left, TestFrames.pressing([]))
            harness.transport.onFrame?(.left, TestFrames.pressing([.x]))
            XCTAssertTrue(harness.actions.contains(where: Self.isDelete), "\(harness.actions)")
        }
    }

    func testSquashedTriggerOnStandbyDoesNotMoveThePointerAfterHandOff() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            var squashed = TestFrames.still(1)[0]
            squashed.buttons = [.zr]
            harness.transport.onConnected?(.left, "Joy-Con (L)")
            for _ in 0..<60 { harness.transport.onFrame?(.left, squashed) }
            squashed.gyroSamples = TestFrames.moving.gyroSamples
            harness.transport.onDisconnected?(.right)
            harness.transport.onFrame?(.left, squashed)
            XCTAssertNotEqual(model.status, .active)
        }
    }

    func testOnlyTheSwitchingPressActsNotAButtonAlreadyHeld() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            harness.transport.onFrame?(.right, TestFrames.pressing([.y]))
            harness.transport.onFrame?(.left, TestFrames.pressing([.x]))
            harness.transport.onFrame?(.right, TestFrames.pressing([]))
            harness.actions.removeAll()
            harness.transport.onFrame?(.left, TestFrames.pressing([.x, .a]))
            XCTAssertEqual(model.activeSide, .left)
            XCTAssertTrue(harness.actions.contains(.keyTap(.escape)), "\(harness.actions)")
            XCTAssertFalse(harness.actions.contains(where: Self.isDelete), "\(harness.actions)")
        }
    }

    func testStallWhileHoldingTriggerDoesNotBlockSwitching() {
        withModel { model, harness in
            connectCalibrated(.right, harness)
            connectCalibrated(.left, harness)
            harness.transport.onFrame?(.right, TestFrames.pressing([.zr]))
            harness.transport.onRecovering?(.right)
            harness.transport.onFrame?(.left, TestFrames.pressing([.a]))
            XCTAssertEqual(model.activeSide, .left)
        }
    }
}
