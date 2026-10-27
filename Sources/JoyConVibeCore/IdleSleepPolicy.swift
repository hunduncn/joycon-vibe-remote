import Foundation

/// Decides when an untouched controller should be put to sleep to save its
/// battery. Only deliberate input counts as activity: a controller resting on
/// a table still reports small gyro readings, which must not keep it awake.
public struct IdleSleepPolicy: Sendable {
    private static let stickDeadZone = 0.30
    private var lastActivity: TimeInterval?

    public init() {}

    public mutating func record(_ frame: JoyConInputFrame, at timestamp: TimeInterval) {
        let stickMoved = abs(frame.stick.x) > Self.stickDeadZone || abs(frame.stick.y) > Self.stickDeadZone
        if lastActivity == nil || !frame.buttons.isEmpty || stickMoved {
            lastActivity = timestamp
        }
    }

    /// True once nothing was pressed for `timeout` seconds. A timeout of zero
    /// or less disables sleeping.
    public func shouldSleep(at timestamp: TimeInterval, timeout: TimeInterval) -> Bool {
        guard timeout > 0, let lastActivity else { return false }
        return timestamp - lastActivity >= timeout
    }

    /// Forget the previous controller session, so a new one starts its own
    /// idle period from its first report.
    public mutating func reset() {
        lastActivity = nil
    }
}
