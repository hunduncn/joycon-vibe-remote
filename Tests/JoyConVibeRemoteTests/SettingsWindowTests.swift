import XCTest
import JoyConVibeCore
@testable import JoyConVibeRemote

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testEveryButtonHasAPointOnTheDrawing() {
        let canvas = CGRect(origin: .zero, size: JoyConGeometry.size)
        for button in JoyConButton.allCases {
            let part = JoyConPart(button)
            XCTAssertEqual(part.button, button)
            XCTAssertTrue(canvas.contains(JoyConGeometry.center(of: part)), "\(button) is off the drawing")
        }
    }

    func testMappingCardsCoverEveryButtonExactlyOnce() {
        let cards = MappingLayout.left + MappingLayout.right
        XCTAssertEqual(cards.count, Set(cards).count)
        XCTAssertEqual(Set(cards.map(\.button)), Set(JoyConButton.allCases))
        // Every configurable button gets an editable card; only ZR and SL are fixed.
        XCTAssertEqual(
            Set(cards.filter { !MappingLayout.fixed.contains($0) }.map(\.button)),
            Set(RemoteButtonAction.configurableButtons)
        )
    }

    func testCardsAreOrderedTopToBottomByPositionOnTheController() {
        for column in [MappingLayout.left, MappingLayout.right] {
            let heights = column.map { JoyConGeometry.center(of: $0).y }
            XCTAssertEqual(heights, heights.sorted())
        }
    }

    func testResetAllRestoresMappingsAndTuning() {
        let suite = "SettingsWindowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = RemoteSettings(defaults: defaults)
        settings.setPrimaryMapping(.space, for: .a)
        settings.sensitivity = 3
        settings.invertVertical = true
        let revision = settings.pointerTuningRevision

        settings.resetAll()

        let standard = PointerSettings()
        XCTAssertEqual(settings.binding(for: .a), RemoteButtonBinding.defaultBindings[.a])
        XCTAssertEqual(settings.sensitivity, standard.sensitivity)
        XCTAssertFalse(settings.invertVertical)
        XCTAssertGreaterThan(settings.pointerTuningRevision, revision)
        XCTAssertEqual(RemoteSettings(defaults: defaults).sensitivity, standard.sensitivity)
    }

    func testPressHighlightFollowsNewPressesOnlyWhileActive() {
        let highlight = PressHighlight()

        highlight.ingest([.a])
        XCTAssertNil(highlight.button)

        highlight.isActive = true
        highlight.ingest([])
        highlight.ingest([.b])
        XCTAssertEqual(highlight.button, .b)
        highlight.ingest([.b, .x])
        XCTAssertEqual(highlight.button, .x)

        highlight.isActive = false
        XCTAssertNil(highlight.button)
    }

    func testLiveInputIgnoresReportsWhenNobodyIsWatching() {
        let live = LiveInput()
        let frame = JoyConInputFrame(buttons: [.zr], stick: .zero)

        live.ingest(frame, timestamp: 0)
        XCTAssertEqual(live.snapshot.buttons, [])

        live.isObserving = true
        live.ingest(frame, timestamp: 0.1)
        XCTAssertEqual(live.snapshot.buttons, [.zr])

        live.isObserving = false
        XCTAssertEqual(live.snapshot.buttons, [])
    }
}
