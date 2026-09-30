import XCTest
@testable import JoyConVibeCore

final class ScrollRemainderAccumulatorTests: XCTestCase {
    func testSlowScrollIsNotLostToPerFrameRounding() {
        var accumulator = ScrollRemainderAccumulator()

        // A light stick deflection asks for less than half a point per report.
        let emitted = (0..<8).map { _ in accumulator.wholePoints(adding: 0.375) }

        XCTAssertEqual(emitted.reduce(0, +), 3)
        XCTAssertTrue(emitted.allSatisfy { $0 == 0 || $0 == 1 })
    }

    func testEmittedDistanceMatchesRequestedDistance() {
        var accumulator = ScrollRemainderAccumulator()

        let emitted = (0..<8).map { _ in accumulator.wholePoints(adding: -1.25) }

        XCTAssertEqual(emitted.reduce(0, +), -10)
    }

    func testReversingDirectionDiscardsTheOppositeRemainder() {
        var accumulator = ScrollRemainderAccumulator()

        XCTAssertEqual(accumulator.wholePoints(adding: 0.75), 0)
        // The pending upward fraction must not delay the first downward point.
        XCTAssertEqual(accumulator.wholePoints(adding: -0.5), 0)
        XCTAssertEqual(accumulator.wholePoints(adding: -0.5), -1)
    }

    func testResetClearsThePendingFraction() {
        var accumulator = ScrollRemainderAccumulator()

        XCTAssertEqual(accumulator.wholePoints(adding: 0.75), 0)
        accumulator.reset()

        XCTAssertEqual(accumulator.wholePoints(adding: 0.5), 0)
    }
}
