import XCTest
import JoyConVibeCore
@testable import JoyConVibeRemote

@MainActor
final class RemoteSettingsMigrationTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "RemoteSettingsMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    func testInversionsSavedBeforeTheDirectionFixAreCleared() {
        withDefaults { defaults in
            defaults.set(true, forKey: "pointer.invertHorizontal")
            defaults.set(true, forKey: "pointer.invertVertical")

            let settings = RemoteSettings(defaults: defaults)

            XCTAssertFalse(settings.invertHorizontal)
            XCTAssertFalse(settings.invertVertical)
            XCTAssertNil(defaults.object(forKey: "pointer.invertHorizontal"))
        }
    }

    func testFreshInstallStartsWithoutInversions() {
        withDefaults { defaults in
            let settings = RemoteSettings(defaults: defaults)

            XCTAssertFalse(settings.invertHorizontal)
            XCTAssertFalse(settings.invertVertical)
        }
    }

    func testInversionChosenAfterTheFixSurvivesRelaunch() {
        withDefaults { defaults in
            let first = RemoteSettings(defaults: defaults)
            first.invertVertical = true

            let relaunched = RemoteSettings(defaults: defaults)

            XCTAssertTrue(relaunched.invertVertical)
            XCTAssertFalse(relaunched.invertHorizontal)
        }
    }

    func testExistingRightMappingsSurviveUpgrade() {
        withDefaults { defaults in
            defaults.set("space", forKey: "mapping.button.a")
            defaults.set("arrowKeys", forKey: "mapping.stick.vertical.primary")

            let settings = RemoteSettings(defaults: defaults)

            XCTAssertEqual(settings.binding(for: .a, side: .right).primary, .space)
            XCTAssertEqual(settings.stickVerticalBinding(for: .right).primary, .arrowKeys)
            XCTAssertEqual(settings.binding(for: .a, side: .left).primary, .escape)
            XCTAssertEqual(settings.stickVerticalBinding(for: .left), .defaultBinding)
        }
    }

    func testSidesAreStoredSeparately() {
        withDefaults { defaults in
            let settings = RemoteSettings(defaults: defaults)
            settings.setPrimaryMapping(.tab, for: .y, side: .left)
            settings.setSLMapping(.space, for: .y, side: .left)
            settings.setStickVerticalSL(.none, side: .left)

            XCTAssertEqual(defaults.string(forKey: "mapping.left.button.y"), "tab")
            XCTAssertEqual(defaults.string(forKey: "mapping.left.button.y.sl"), "space")
            XCTAssertEqual(defaults.string(forKey: "mapping.left.stick.vertical.sl"), "none")
            XCTAssertEqual(settings.binding(for: .y, side: .right).primary, .leftClick)
            XCTAssertNil(defaults.object(forKey: "mapping.button.y"))

            let relaunched = RemoteSettings(defaults: defaults)
            XCTAssertEqual(relaunched.binding(for: .y, side: .left), RemoteButtonBinding(primary: .tab, withSL: .space))
            XCTAssertEqual(relaunched.stickVerticalBinding(for: .left).withSL, RemoteStickVerticalAction.none)
            XCTAssertEqual(relaunched.buttonBindings(for: .left)[.y]?.primary, .tab)
        }
    }

    func testResetAllRestoresBothSides() {
        withDefaults { defaults in
            let settings = RemoteSettings(defaults: defaults)
            settings.setPrimaryMapping(.space, for: .a, side: .right)
            settings.setPrimaryMapping(.space, for: .a, side: .left)

            settings.resetAll()

            for side in JoyConSide.allCases {
                XCTAssertEqual(settings.binding(for: .a, side: side), RemoteButtonBinding.defaultBindings[.a])
            }
            XCTAssertNil(defaults.object(forKey: "mapping.button.a"))
            XCTAssertNil(defaults.object(forKey: "mapping.left.button.a"))
        }
    }

    func testResetMappingsForOneSideLeavesTheOther() {
        withDefaults { defaults in
            let settings = RemoteSettings(defaults: defaults)
            settings.setPrimaryMapping(.space, for: .a, side: .right)
            settings.setPrimaryMapping(.space, for: .a, side: .left)

            settings.resetButtonMappings(side: .left)

            XCTAssertEqual(settings.binding(for: .a, side: .left).primary, .escape)
            XCTAssertEqual(settings.binding(for: .a, side: .right).primary, .space)
            XCTAssertEqual(defaults.string(forKey: "mapping.button.a"), "space")
        }
    }
}
