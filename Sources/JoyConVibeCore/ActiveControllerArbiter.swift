import Foundation

/// Decides which of two connected Joy-Cons is in control: whoever presses a
/// button. Sticks and motion never switch, since a controller lying on the
/// desk gets nudged, and nothing switches while the controller in use still
/// holds a button, so a drag or a clutch is never cut short.
public struct ActiveControllerArbiter: Sendable {
    public enum Decision: Equatable, Sendable {
        case accept
        case ignore
        case switchTo(JoyConSide)
    }

    public private(set) var active: JoyConSide?
    public private(set) var connected: Set<JoyConSide> = []
    private var lastButtons: [JoyConSide: Set<JoyConButton>] = [:]

    public init() {}

    /// The first controller to connect takes control.
    public mutating func connect(_ side: JoyConSide) -> JoyConSide? {
        connected.insert(side)
        lastButtons[side] = []
        if active == nil { active = side }
        return active
    }

    /// Hands control to the remaining controller when the one in use leaves.
    public mutating func disconnect(_ side: JoyConSide) -> JoyConSide? {
        connected.remove(side)
        lastButtons[side] = nil
        if active == side { active = connected.first }
        return active
    }

    public mutating func route(_ frame: JoyConInputFrame, from side: JoyConSide) -> Decision {
        let previous = lastButtons[side] ?? []
        lastButtons[side] = frame.buttons
        guard let current = active else {
            active = side
            return .switchTo(side)
        }
        if side == current { return .accept }
        let newlyPressed = !frame.buttons.subtracting(previous).isEmpty
        let currentIsIdle = (lastButtons[current] ?? []).isEmpty
        guard newlyPressed, currentIsIdle else { return .ignore }
        active = side
        return .switchTo(side)
    }

    public mutating func reset() {
        active = nil
        connected = []
        lastButtons = [:]
    }
}
