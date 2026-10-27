import Foundation

public struct LiveInputSnapshot: Equatable, Sendable {
    public var buttons: Set<JoyConButton>
    public var stick: StickPosition
    /// Recent motion intensity, oldest first, each in 0...1.
    public var motionLevels: [Double]

    public init(buttons: Set<JoyConButton>, stick: StickPosition, motionLevels: [Double]) {
        self.buttons = buttons
        self.stick = stick
        self.motionLevels = motionLevels
    }
}

/// Reduces the 60 Hz report stream to the few changes a status display needs.
///
/// A snapshot is produced only when pressed buttons change, the stick moves by
/// a visible step, or a new motion level is due, so a view bound to it does not
/// redraw for every identical report.
public struct LiveInputSampler: Sendable {
    private let levelInterval: TimeInterval
    private let stickStep: Double
    private let fullScaleDegreesPerSecond: Double
    private var snapshot: LiveInputSnapshot
    private var levelStartedAt: TimeInterval?
    private var peakMotion = 0.0

    public init(
        levelCount: Int = 24,
        levelInterval: TimeInterval = 0.1,
        stickStep: Double = 0.05,
        fullScaleDegreesPerSecond: Double = 240
    ) {
        self.levelInterval = levelInterval
        self.stickStep = stickStep
        self.fullScaleDegreesPerSecond = fullScaleDegreesPerSecond
        snapshot = LiveInputSnapshot(
            buttons: [],
            stick: .zero,
            motionLevels: Array(repeating: 0, count: levelCount)
        )
    }

    public var current: LiveInputSnapshot { snapshot }

    /// Returns the buttons that went down in this report, in a stable order,
    /// and a new snapshot when anything visible changed.
    public mutating func process(
        frame: JoyConInputFrame,
        timestamp: TimeInterval
    ) -> (snapshot: LiveInputSnapshot?, newlyPressed: [JoyConButton]) {
        var next = snapshot
        let newlyPressed = JoyConButton.allCases.filter {
            frame.buttons.contains($0) && !snapshot.buttons.contains($0)
        }
        next.buttons = frame.buttons
        next.stick = StickPosition(
            x: (frame.stick.x / stickStep).rounded() * stickStep,
            y: (frame.stick.y / stickStep).rounded() * stickStep
        )

        for sample in frame.gyroSamples {
            peakMotion = max(peakMotion, sample.degreesPerSecond.magnitude)
        }
        if let started = levelStartedAt {
            if timestamp - started >= levelInterval {
                next.motionLevels.removeFirst()
                next.motionLevels.append(min(1, peakMotion / fullScaleDegreesPerSecond))
                peakMotion = 0
                levelStartedAt = timestamp
            }
        } else {
            levelStartedAt = timestamp
        }

        guard next != snapshot else { return (nil, newlyPressed) }
        snapshot = next
        return (next, newlyPressed)
    }

    public mutating func reset() {
        snapshot = LiveInputSnapshot(
            buttons: [],
            stick: .zero,
            motionLevels: Array(repeating: 0, count: snapshot.motionLevels.count)
        )
        levelStartedAt = nil
        peakMotion = 0
    }
}
