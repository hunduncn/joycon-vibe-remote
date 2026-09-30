import Foundation

extension Vector3 {
    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    func scaled(by scalar: Double) -> Vector3 {
        Vector3(x: x * scalar, y: y * scalar, z: z * scalar)
    }

    func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    /// Unit vector, or zero when the magnitude is too small to give a direction.
    var normalized: Vector3 {
        let magnitude = magnitude
        return magnitude > 0.001 ? scaled(by: 1 / magnitude) : .zero
    }
}
