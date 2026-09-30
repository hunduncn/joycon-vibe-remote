import Foundation

/// Counts consecutive presses of one mouse button at one location.
///
/// Synthetic mouse events carry their own click count; macOS does not derive
/// it from timing. Without it, two quick presses arrive as two single clicks
/// and never select a word or open a file.
public struct MouseClickSequence: Sendable {
    private var button: RemoteMouseButton?
    private var pressedAt: TimeInterval = 0
    private var x = 0.0
    private var y = 0.0
    private var count = 0

    public init() {}

    public mutating func registerPress(
        of button: RemoteMouseButton,
        at timestamp: TimeInterval,
        x: Double,
        y: Double,
        multiClickInterval: TimeInterval,
        movementTolerance: Double = 5
    ) -> Int {
        let continuesSequence = self.button == button
            && timestamp - pressedAt <= multiClickInterval
            && hypot(x - self.x, y - self.y) <= movementTolerance
        count = continuesSequence ? count + 1 : 1
        self.button = button
        pressedAt = timestamp
        self.x = x
        self.y = y
        return count
    }

    /// The count to report on the release that matches the latest press.
    public func clickCount(for button: RemoteMouseButton) -> Int {
        self.button == button ? count : 1
    }
}
