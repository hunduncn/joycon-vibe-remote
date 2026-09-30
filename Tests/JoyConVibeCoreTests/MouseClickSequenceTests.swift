import XCTest
@testable import JoyConVibeCore

final class MouseClickSequenceTests: XCTestCase {
    private func press(
        _ sequence: inout MouseClickSequence,
        _ button: RemoteMouseButton = .left,
        at timestamp: TimeInterval,
        x: Double = 100,
        y: Double = 100
    ) -> Int {
        sequence.registerPress(
            of: button,
            at: timestamp,
            x: x,
            y: y,
            multiClickInterval: 0.5
        )
    }

    func testQuickRepeatedPressesCountAsDoubleAndTripleClicks() {
        var sequence = MouseClickSequence()

        XCTAssertEqual(press(&sequence, at: 10.0), 1)
        XCTAssertEqual(press(&sequence, at: 10.3), 2)
        XCTAssertEqual(press(&sequence, at: 10.6), 3)
    }

    func testReleaseReportsTheCountOfItsPress() {
        var sequence = MouseClickSequence()

        _ = press(&sequence, at: 10.0)
        _ = press(&sequence, at: 10.3)

        XCTAssertEqual(sequence.clickCount(for: .left), 2)
        XCTAssertEqual(sequence.clickCount(for: .right), 1)
    }

    func testSlowSecondPressStartsANewSequence() {
        var sequence = MouseClickSequence()

        XCTAssertEqual(press(&sequence, at: 10.0), 1)
        XCTAssertEqual(press(&sequence, at: 10.51), 1)
    }

    func testPressAwayFromThePreviousClickStartsANewSequence() {
        var sequence = MouseClickSequence()

        XCTAssertEqual(press(&sequence, at: 10.0), 1)
        XCTAssertEqual(press(&sequence, at: 10.2, x: 103, y: 100), 2)
        XCTAssertEqual(press(&sequence, at: 10.4, x: 140, y: 100), 1)
    }

    func testOtherButtonStartsANewSequence() {
        var sequence = MouseClickSequence()

        XCTAssertEqual(press(&sequence, .left, at: 10.0), 1)
        XCTAssertEqual(press(&sequence, .right, at: 10.2), 1)
        XCTAssertEqual(press(&sequence, .left, at: 10.4), 1)
    }
}
