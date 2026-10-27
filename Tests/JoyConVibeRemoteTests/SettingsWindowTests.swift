import XCTest
import JoyConVibeCore
@testable import JoyConVibeRemote

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testEveryButtonHasAPointOnTheDrawing() {
        let canvas = CGRect(origin: .zero, size: JoyConGeometry.size)
        for side in JoyConSide.allCases {
            for button in JoyConButton.allCases {
                let part = JoyConPart(button)
                XCTAssertEqual(part.button, button)
                XCTAssertTrue(
                    canvas.contains(JoyConGeometry.center(of: part, side: side)),
                    "\(button) is off the \(side) drawing"
                )
            }
        }
    }

    func testMappingCardsCoverEveryButtonExactlyOnce() {
        for side in JoyConSide.allCases {
            let columns = MappingLayout.columns(for: side)
            let cards = columns.left + columns.right
            XCTAssertEqual(cards.count, Set(cards).count)
            XCTAssertEqual(Set(cards.map(\.button)), Set(JoyConButton.allCases))
            // Every configurable button gets an editable card; only the trigger and the layer key are fixed.
            XCTAssertEqual(
                Set(cards.filter { !MappingLayout.fixed.contains($0) }.map(\.button)),
                Set(RemoteButtonAction.configurableButtons)
            )
        }
    }

    func testCardsAreOrderedTopToBottomByPositionOnTheController() {
        for side in JoyConSide.allCases {
            let columns = MappingLayout.columns(for: side)
            for column in [columns.left, columns.right] {
                let heights = column.map { JoyConGeometry.center(of: $0, side: side).y }
                XCTAssertEqual(heights, heights.sorted(), "\(side)")
            }
        }
    }

    func testRightLayoutIsUnchanged() {
        let columns = MappingLayout.columns(for: .right)
        XCTAssertEqual(columns.left, [.plus, .sr, .y, .home, .sl])
        XCTAssertEqual(columns.right, [.zr, .r, .x, .a, .b, .stick])
        XCTAssertEqual(JoyConGeometry.center(of: .a, side: .right), JoyConGeometry.center(of: .a))
    }

    func testLeftCardsSitOnTheSameSideAsTheirParts() {
        let middle = JoyConGeometry.size.width / 2
        let columns = MappingLayout.columns(for: .left)
        for part in columns.left {
            XCTAssertLessThan(JoyConGeometry.center(of: part, side: .left).x, middle, "\(part)")
        }
        for part in columns.right {
            XCTAssertGreaterThan(JoyConGeometry.center(of: part, side: .left).x, middle, "\(part)")
        }
    }

    func testLeftControllerHasTheStickAboveTheButtons() {
        let stick = JoyConGeometry.center(of: .stick, side: .left)
        let up = JoyConGeometry.center(of: .x, side: .left)
        XCTAssertLessThan(stick.y, up.y)
        XCTAssertLessThan(
            JoyConGeometry.center(of: .a, side: .left).x,
            JoyConGeometry.center(of: .y, side: .left).x,
            "← sits left of →"
        )
    }

    func testLeftLabelsAreTheRealKeyNames() {
        let expected: [JoyConButton: String] = [
            .zr: "ZL", .r: "L", .a: "←", .y: "→", .x: "↑", .b: "↓",
            .plus: "−", .home: "截图", .stick: "摇杆按下", .sl: "SR", .sr: "SL"
        ]
        for button in JoyConButton.allCases {
            XCTAssertEqual(JoyConSide.left.keyLabel(button), expected[button], "\(button)")
            XCTAssertEqual(JoyConSide.right.keyLabel(button), button.mappingTitle)
        }
        XCTAssertEqual(JoyConSide.left.partName(.zr), "扳机 ZL")
        XCTAssertEqual(JoyConSide.left.partName(.home), "截图键")
        XCTAssertEqual(JoyConSide.left.partName(.sl), "侧键 SR")
        XCTAssertEqual(JoyConSide.right.partName(.zr), "扳机 ZR")
        XCTAssertEqual(JoyConSide.right.partName(.a), "A 键")
        XCTAssertEqual(JoyConSide.left.displayName, "左手柄")
    }

    func testResetAllRestoresMappingsAndTuning() {
        let suite = "SettingsWindowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = RemoteSettings(defaults: defaults)
        settings.setPrimaryMapping(.space, for: .a, side: .right)
        settings.sensitivity = 3
        settings.invertVertical = true
        let revision = settings.pointerTuningRevision

        settings.resetAll()

        let standard = PointerSettings()
        XCTAssertEqual(settings.binding(for: .a, side: .right), RemoteButtonBinding.defaultBindings[.a])
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
