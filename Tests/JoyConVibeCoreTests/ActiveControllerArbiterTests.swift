import XCTest
@testable import JoyConVibeCore

final class ActiveControllerArbiterTests: XCTestCase {
    private func frame(_ buttons: Set<JoyConButton>, stick: StickPosition = .zero, moving: Bool = false) -> JoyConInputFrame {
        let sample = GyroSample(degreesPerSecond: Vector3(x: 0, y: moving ? 200 : 0, z: 0))
        return JoyConInputFrame(buttons: buttons, stick: stick, gyroSamples: moving ? [sample, sample, sample] : [])
    }

    private func bothConnected() -> ActiveControllerArbiter {
        var arbiter = ActiveControllerArbiter()
        _ = arbiter.connect(.right)
        _ = arbiter.connect(.left)
        return arbiter
    }

    func testFirstConnectedControllerBecomesActive() {
        var arbiter = ActiveControllerArbiter()
        XCTAssertEqual(arbiter.connect(.right), .right)
        XCTAssertEqual(arbiter.connect(.left), .right)
        XCTAssertEqual(arbiter.active, .right)
        XCTAssertEqual(arbiter.connected, [.right, .left])
    }

    func testFramesFromActiveAreAccepted() {
        var arbiter = bothConnected()
        XCTAssertEqual(arbiter.route(frame([.a]), from: .right), .accept)
    }

    func testPressOnIdleControllerSwitches() {
        var arbiter = bothConnected()
        XCTAssertEqual(arbiter.route(frame([]), from: .right), .accept)
        XCTAssertEqual(arbiter.route(frame([.y]), from: .left), .switchTo(.left))
        XCTAssertEqual(arbiter.active, .left)
    }

    func testStickAndMotionDoNotSwitch() {
        var arbiter = bothConnected()
        XCTAssertEqual(arbiter.route(frame([], stick: StickPosition(x: 1, y: 0), moving: true), from: .left), .ignore)
        XCTAssertEqual(arbiter.active, .right)
    }

    func testNoSwitchWhileActiveHoldsAnyButton() {
        var arbiter = bothConnected()
        _ = arbiter.route(frame([.zr]), from: .right)
        XCTAssertEqual(arbiter.route(frame([.a]), from: .left), .ignore)
        _ = arbiter.route(frame([]), from: .right)
        // Still held from before, so it is not a new press.
        XCTAssertEqual(arbiter.route(frame([.a]), from: .left), .ignore)
        XCTAssertEqual(arbiter.route(frame([]), from: .left), .ignore)
        XCTAssertEqual(arbiter.route(frame([.a]), from: .left), .switchTo(.left))
    }

    func testHeldButtonOnStandbyNeverSteals() {
        var arbiter = bothConnected()
        for step in 0..<10 {
            _ = arbiter.route(frame(step.isMultiple(of: 2) ? [.a] : []), from: .right)
            XCTAssertEqual(arbiter.route(frame([.b]), from: .left), .ignore)
        }
        XCTAssertEqual(arbiter.active, .right)
    }

    func testActiveDisconnectFallsBackToOther() {
        var arbiter = bothConnected()
        XCTAssertEqual(arbiter.disconnect(.right), .left)
        XCTAssertEqual(arbiter.active, .left)
        XCTAssertNil(arbiter.disconnect(.left))
        XCTAssertNil(arbiter.active)
        XCTAssertEqual(arbiter.connected, [])
    }

    func testStandbyDisconnectKeepsActive() {
        var arbiter = bothConnected()
        XCTAssertEqual(arbiter.disconnect(.left), .right)
        XCTAssertEqual(arbiter.connected, [.right])
    }

    func testLateConnectionDoesNotTakeOver() {
        var arbiter = ActiveControllerArbiter()
        _ = arbiter.connect(.left)
        _ = arbiter.connect(.right)
        XCTAssertEqual(arbiter.active, .left)
    }

    func testReconnectedControllerStartsWithNoHeldButtons() {
        var arbiter = bothConnected()
        _ = arbiter.route(frame([.a]), from: .left)
        _ = arbiter.disconnect(.left)
        _ = arbiter.connect(.left)
        XCTAssertEqual(arbiter.route(frame([.a]), from: .left), .switchTo(.left))
    }
}
