import XCTest
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
}
