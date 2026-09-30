import XCTest
@testable import JoyConVibeCore

final class MouseMovementEventDescriptorTests: XCTestCase {
    private let laptop = ScreenBounds(x: 0, y: 0, width: 1440, height: 900)
    private let external = ScreenBounds(x: 1440, y: 0, width: 1920, height: 1080)

    func testMovementCarriesBothAbsoluteDestinationAndRelativeMouseDelta() {
        var planner = MouseMovementPlanner()

        let descriptor = planner.plan(
            currentX: 400,
            currentY: 300,
            delta: PointerDelta(dx: 120, dy: -80),
            screens: [laptop]
        )

        XCTAssertEqual(descriptor.destinationX, 520)
        XCTAssertEqual(descriptor.destinationY, 220)
        XCTAssertEqual(descriptor.relativeDeltaX, 120)
        XCTAssertEqual(descriptor.relativeDeltaY, -80)
    }

    func testPushingPastAScreenEdgeStaysOnTheEdgeAndKeepsReportingThePush() {
        var planner = MouseMovementPlanner()

        // The auto-hidden Dock and the Stage Manager strip only react to a
        // pointer that rests on the edge while still being pushed outward.
        let descriptor = planner.plan(
            currentX: 0,
            currentY: 300,
            delta: PointerDelta(dx: -6, dy: 0),
            screens: [laptop]
        )

        XCTAssertEqual(descriptor.destinationX, 0)
        XCTAssertEqual(descriptor.destinationY, 300)
        XCTAssertEqual(descriptor.relativeDeltaX, -6)
    }

    func testFarEdgesClampToTheLastPointInsideTheScreen() {
        var planner = MouseMovementPlanner()

        let descriptor = planner.plan(
            currentX: 1430,
            currentY: 890,
            delta: PointerDelta(dx: 40, dy: 40),
            screens: [laptop]
        )

        XCTAssertEqual(descriptor.destinationX, 1439)
        XCTAssertEqual(descriptor.destinationY, 899)
    }

    func testPointerCanCrossOntoAnAdjacentScreen() {
        var planner = MouseMovementPlanner()

        let descriptor = planner.plan(
            currentX: 1436,
            currentY: 100,
            delta: PointerDelta(dx: 10, dy: 0),
            screens: [laptop, external]
        )

        XCTAssertEqual(descriptor.destinationX, 1446)
    }

    func testLeavingEveryScreenClampsToTheScreenThePointerIsOn() {
        var planner = MouseMovementPlanner()

        // Below the laptop panel there is no screen, even though the taller
        // external display continues further down next to it.
        let descriptor = planner.plan(
            currentX: 700,
            currentY: 890,
            delta: PointerDelta(dx: 0, dy: 60),
            screens: [laptop, external]
        )

        XCTAssertEqual(descriptor.destinationX, 700)
        XCTAssertEqual(descriptor.destinationY, 899)
    }

    func testSlowMovementStillReportsWholeRelativeSteps() {
        var planner = MouseMovementPlanner()

        let reported = (0..<8).map { _ in
            planner.plan(
                currentX: 0,
                currentY: 300,
                delta: PointerDelta(dx: -0.375, dy: 0),
                screens: [laptop]
            ).relativeDeltaX
        }

        XCTAssertEqual(reported.reduce(0, +), -3)
    }

    func testUnknownScreenLayoutLeavesTheDestinationUnclamped() {
        var planner = MouseMovementPlanner()

        let descriptor = planner.plan(
            currentX: 0,
            currentY: 0,
            delta: PointerDelta(dx: -6, dy: -4),
            screens: []
        )

        XCTAssertEqual(descriptor.destinationX, -6)
        XCTAssertEqual(descriptor.destinationY, -4)
    }
}
