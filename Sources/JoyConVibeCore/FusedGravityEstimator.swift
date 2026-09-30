import Foundation

/// Six-axis gravity tracking adapted from the approach used by
/// GamepadMotionHelpers: gyro propagation supplies responsive motion while a
/// shakiness-aware accelerometer correction removes long-term tilt drift.
struct FusedGravityEstimator: Sendable {
    private static let sampleInterval = JoyConIMUTiming.sampleInterval
    private static let smoothFactor = pow(0.5, sampleInterval / 0.25)

    private var gravity = Vector3.zero
    private var smoothAcceleration = Vector3.zero
    private var shakiness = 0.0
    private var hasEstimate = false

    mutating func reset() {
        gravity = .zero
        smoothAcceleration = .zero
        shakiness = 0
        hasEstimate = false
    }

    mutating func update(
        angularVelocity: Vector3,
        acceleration: Vector3
    ) -> Vector3 {
        if hasEstimate {
            gravity = rotatedByInverseGyro(gravity, angularVelocity: angularVelocity)
            smoothAcceleration = rotatedByInverseGyro(
                smoothAcceleration,
                angularVelocity: angularVelocity
            )
        }

        let accelerationMagnitude = acceleration.magnitude
        guard accelerationMagnitude > 0.001 else {
            return hasEstimate ? gravity.normalized : Vector3(x: 0, y: -1, z: 0)
        }

        // An accelerometer reports support force, which points opposite the
        // gravity vector used by GamepadMotionHelpers' world-space mapping.
        // Joy-Con report polarity is fixed; it must never be guessed from the
        // first grip's dominant component.
        let measuredGravity = acceleration.scaled(by: -1 / accelerationMagnitude)
        if !hasEstimate {
            gravity = measuredGravity
            smoothAcceleration = measuredGravity
            hasEstimate = true
            return gravity
        }

        let smoothFactor = Self.smoothFactor
        shakiness *= smoothFactor
        shakiness = max(shakiness, (measuredGravity - smoothAcceleration).magnitude)
        smoothAcceleration = measuredGravity.scaled(by: 1 - smoothFactor)
            + smoothAcceleration.scaled(by: smoothFactor)

        let shakinessAmount = clamp((shakiness - 0.01) / (0.40 - 0.01))
        var correctionSpeed = 1.0 + (0.1 - 1.0) * shakinessAmount
        let angularSpeed = angularVelocity.magnitude * .pi / 180
        let gyroCorrectionLimit = max(angularSpeed * 0.1, 0.01)
        let difference = measuredGravity - gravity
        let differenceMagnitude = difference.magnitude

        if correctionSpeed > gyroCorrectionLimit {
            let closeEnough = clamp((differenceMagnitude - 0.05) / (0.25 - 0.05))
            correctionSpeed = gyroCorrectionLimit
                + (correctionSpeed - gyroCorrectionLimit) * closeEnough
        }

        let correctionDistance = correctionSpeed * Self.sampleInterval
        if differenceMagnitude > correctionDistance, differenceMagnitude > 0.001 {
            gravity = gravity
                + difference.scaled(by: correctionDistance / differenceMagnitude)
        } else {
            gravity = measuredGravity
        }
        gravity = gravity.normalized
        return gravity
    }

    private func rotatedByInverseGyro(
        _ vector: Vector3,
        angularVelocity: Vector3
    ) -> Vector3 {
        let speed = angularVelocity.magnitude
        guard speed > 0.0001 else { return vector }

        let axis = angularVelocity.scaled(by: 1 / speed)
        let angle = -speed * .pi / 180 * Self.sampleInterval
        let cosine = cos(angle)
        let sine = sin(angle)
        let axisProjection = axis.dot(vector) * (1 - cosine)
        let cross = axis.cross(vector)
        return Vector3(
            x: vector.x * cosine + cross.x * sine + axis.x * axisProjection,
            y: vector.y * cosine + cross.y * sine + axis.y * axisProjection,
            z: vector.z * cosine + cross.z * sine + axis.z * axisProjection
        )
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
