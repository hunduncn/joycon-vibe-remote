import XCTest
@testable import JoyConVibeCore

final class IdleSleepPolicyTests: XCTestCase {
    private func frame(_ buttons: Set<JoyConButton> = [], stick: StickPosition = .zero, rate: Double = 0) -> JoyConInputFrame {
        JoyConInputFrame(buttons: buttons, stick: stick, gyroSamples: [GyroSample(degreesPerSecond: Vector3(x: rate, y: 0, z: 0))])
    }

    func testSleepsAfterTheTimeoutWithoutInput() {
        var policy = IdleSleepPolicy()
        policy.record(frame(), at: 100)

        XCTAssertFalse(policy.shouldSleep(at: 100 + 1799, timeout: 1800))
        XCTAssertTrue(policy.shouldSleep(at: 100 + 1800, timeout: 1800))
    }

    func testButtonsAndStickCountAsActivity() {
        var policy = IdleSleepPolicy()
        policy.record(frame(), at: 0)
        policy.record(frame([.a]), at: 1000)
        XCTAssertFalse(policy.shouldSleep(at: 2500, timeout: 1800))

        policy.record(frame(stick: StickPosition(x: 0, y: -0.8)), at: 2500)
        XCTAssertFalse(policy.shouldSleep(at: 4000, timeout: 1800))
        XCTAssertTrue(policy.shouldSleep(at: 4300, timeout: 1800))
    }

    func testRestingGyroNoiseAndStickDriftDoNotKeepItAwake() {
        var policy = IdleSleepPolicy()
        policy.record(frame(), at: 0)
        for second in stride(from: 1.0, through: 1800, by: 1) {
            policy.record(frame(stick: StickPosition(x: 0.08, y: -0.05), rate: 3), at: second)
        }

        XCTAssertTrue(policy.shouldSleep(at: 1800, timeout: 1800))
    }

    func testZeroTimeoutDisablesSleeping() {
        var policy = IdleSleepPolicy()
        policy.record(frame(), at: 0)

        XCTAssertFalse(policy.shouldSleep(at: 1_000_000, timeout: 0))
    }

    func testNothingToSleepBeforeAnyReport() {
        XCTAssertFalse(IdleSleepPolicy().shouldSleep(at: 1_000_000, timeout: 60))
    }

    func testResetStartsANewIdlePeriodAtTheNextReport() {
        var policy = IdleSleepPolicy()
        policy.record(frame(), at: 0)
        policy.reset()
        policy.record(frame(), at: 5000)

        XCTAssertFalse(policy.shouldSleep(at: 6000, timeout: 1800))
    }
}
