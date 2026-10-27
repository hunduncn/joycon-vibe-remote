import Foundation
import JoyConVibeCore
@testable import JoyConVibeRemote

final class FakeTransport: JoyConTransport {
    var onConnected: ((JoyConSide, String) -> Void)?
    var onDisconnected: ((JoyConSide) -> Void)?
    var onRecovering: ((JoyConSide) -> Void)?
    var onFrame: ((JoyConSide, JoyConInputFrame) -> Void)?
    var onError: ((String) -> Void)?
    var isRunning = false
    var failStart = false
    var startCount = 0
    var stopCount = 0
    var sleptSides: [JoyConSide] = []
    var sleepCount: Int { sleptSides.count }

    func requestSleep(_ side: JoyConSide) {
        sleptSides.append(side)
    }

    func start() {
        startCount += 1
        isRunning = !failStart
        if failStart { onError?("Simulated permission denial") }
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }
}

enum TestFrames {
    static func still(_ count: Int) -> [JoyConInputFrame] {
        let resting = GyroSample(degreesPerSecond: .zero, acceleration: Vector3(x: 0, y: 0, z: 4096))
        return Array(repeating: JoyConInputFrame(buttons: [], stick: .zero, gyroSamples: [resting, resting, resting]), count: count)
    }

    static var moving: JoyConInputFrame {
        let moving = GyroSample(degreesPerSecond: Vector3(x: 0, y: 60, z: 0), acceleration: Vector3(x: 0, y: 0, z: 4096))
        return JoyConInputFrame(buttons: [], stick: .zero, gyroSamples: [moving, moving, moving])
    }

    static func pressing(_ buttons: Set<JoyConButton>) -> JoyConInputFrame {
        JoyConInputFrame(buttons: buttons, stick: .zero)
    }
}
