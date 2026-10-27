import XCTest
@testable import JoyConVibeCore

final class LiveInputSamplerTests: XCTestCase {
    private func frame(
        _ buttons: Set<JoyConButton> = [],
        stick: StickPosition = .zero,
        rate: Double = 0
    ) -> JoyConInputFrame {
        JoyConInputFrame(
            buttons: buttons,
            stick: stick,
            gyroSamples: [GyroSample(degreesPerSecond: Vector3(x: rate, y: 0, z: 0))]
        )
    }

    func testIdenticalReportsProduceNoSnapshot() {
        var sampler = LiveInputSampler()

        _ = sampler.process(frame: frame([.a]), timestamp: 0)
        let repeated = (1...20).map { sampler.process(frame: frame([.a]), timestamp: Double($0) * 0.004) }

        XCTAssertTrue(repeated.allSatisfy { $0.snapshot == nil })
    }

    func testButtonChangesAreReportedOnceAsNewlyPressed() {
        var sampler = LiveInputSampler()

        let press = sampler.process(frame: frame([.a, .zr]), timestamp: 0)
        let hold = sampler.process(frame: frame([.a, .zr]), timestamp: 0.016)
        let release = sampler.process(frame: frame([.zr]), timestamp: 0.032)

        XCTAssertEqual(press.newlyPressed, [.a, .zr])
        XCTAssertEqual(press.snapshot?.buttons, [.a, .zr])
        XCTAssertEqual(hold.newlyPressed, [])
        XCTAssertEqual(release.snapshot?.buttons, [.zr])
    }

    func testStickJitterBelowOneStepIsIgnored() {
        var sampler = LiveInputSampler(stickStep: 0.05)

        _ = sampler.process(frame: frame(stick: StickPosition(x: 0.50, y: 0)), timestamp: 0)
        let jitter = sampler.process(frame: frame(stick: StickPosition(x: 0.51, y: 0.01)), timestamp: 0.01)
        let move = sampler.process(frame: frame(stick: StickPosition(x: 0.60, y: 0)), timestamp: 0.02)

        XCTAssertNil(jitter.snapshot)
        XCTAssertEqual(move.snapshot?.stick.x ?? 0, 0.60, accuracy: 1e-9)
    }

    func testMotionLevelIsThePeakOfEachInterval() {
        var sampler = LiveInputSampler(levelCount: 3, levelInterval: 0.1, fullScaleDegreesPerSecond: 200)

        _ = sampler.process(frame: frame(rate: 50), timestamp: 0)
        _ = sampler.process(frame: frame(rate: 100), timestamp: 0.05)
        let due = sampler.process(frame: frame(rate: 20), timestamp: 0.1)

        XCTAssertEqual(due.snapshot?.motionLevels, [0, 0, 0.5])
    }

    func testResetClearsHeldButtonsSoTheyCountAsPressedAgain() {
        var sampler = LiveInputSampler()

        _ = sampler.process(frame: frame([.b]), timestamp: 0)
        sampler.reset()

        XCTAssertEqual(sampler.process(frame: frame([.b]), timestamp: 1).newlyPressed, [.b])
    }
}
