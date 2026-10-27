import Combine
import Foundation
import JoyConVibeCore

/// Live button, stick and motion state for the status page. It only publishes
/// while a view is observing it, and then only when something visible changed.
@MainActor
final class LiveInput: ObservableObject {
    @Published private(set) var snapshot: LiveInputSnapshot
    var isObserving = false {
        didSet { if !isObserving { reset() } }
    }

    private var sampler = LiveInputSampler()

    init() {
        snapshot = sampler.current
    }

    func ingest(_ frame: JoyConInputFrame, timestamp: TimeInterval) {
        guard isObserving else { return }
        if let next = sampler.process(frame: frame, timestamp: timestamp).snapshot {
            snapshot = next
        }
    }

    func reset() {
        sampler.reset()
        if snapshot != sampler.current { snapshot = sampler.current }
    }
}

/// The button most recently pressed, held briefly so the mapping page can
/// point at the setting that controls it.
@MainActor
final class PressHighlight: ObservableObject {
    @Published private(set) var button: JoyConButton?
    var isActive = false {
        didSet { if !isActive { clear() } }
    }

    private var previous = Set<JoyConButton>()
    private var generation = 0
    private let holdDuration: TimeInterval

    init(holdDuration: TimeInterval = 1.6) {
        self.holdDuration = holdDuration
    }

    func ingest(_ buttons: Set<JoyConButton>) {
        defer { previous = buttons }
        guard isActive,
              let pressed = JoyConButton.allCases.last(where: { buttons.contains($0) && !previous.contains($0) })
        else { return }
        button = pressed
        generation &+= 1
        let current = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            guard let self, self.generation == current else { return }
            self.button = nil
        }
    }

    private func clear() {
        generation &+= 1
        if button != nil { button = nil }
    }
}
