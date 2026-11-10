import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J113DestructiveKeyboardTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndLaunchGate() throws {
        let fixture = try ScenarioRegistry.resolve("J11.3")
        XCTAssertEqual(fixture.story.node, "J11.3")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J11.3/base"])
        for invalid in ["J11.3", "J11.3/", "J11.3/dark", "J11.3//base", "J11.3/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", invalid]))
        }
        // Launch instrumentation remains DEBUG-only, including in package builds.
        #if DEBUG
        #if SWIFT_PACKAGE
        XCTAssertFalse(J113FixtureLaunch.matches(arguments: ["--watt-fixture", "J11.3/base"]))
        #else
        XCTAssertTrue(J113FixtureLaunch.matches(arguments: ["--watt-fixture", "J11.3/base"]))
        #endif
        XCTAssertFalse(J113FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.2/base"]))
        XCTAssertTrue(J113FixtureLaunch.makePreferences().openAtLogin)
        XCTAssertEqual(MenuBarStatusLabel(reading: J113FixtureLaunch.makeStore().currentReading,
                                        preferences: J113FixtureLaunch.makePreferences()).text, "+42.1 W")
        #endif
    }
    #endif

    func testNativeAlertHasEscapeCancelAndNoDestructiveReturnDefault() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"))
        let start = try XCTUnwrap(source.range(of: ".alert("))
        let end = try XCTUnwrap(source.range(of: ".onAppear", range: start.upperBound..<source.endIndex))
        let alert = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertTrue(alert.contains("Button(\"Cancel\", role: .cancel)"))
        XCTAssertTrue(alert.contains(".keyboardShortcut(.cancelAction)"))
        XCTAssertTrue(alert.contains("role: .destructive"))
        XCTAssertFalse(alert.contains(".defaultAction"))
        XCTAssertFalse(alert.contains(".keyboardShortcut(.return"))
        XCTAssertEqual(alert.components(separatedBy: ".keyboardShortcut(").count - 1, 1)
        XCTAssertTrue(alert.contains("router.cancelUninstall(intent)"))
        XCTAssertTrue(alert.contains("router.confirmUninstall(intent)"))
        XCTAssertTrue(source.contains("Text(confirmUninstallExcerpt ? Self.uninstallMessage"))
        XCTAssertEqual(SettingsRootView.uninstallMessage, "Removes the helper, your settings and the login item, then moves Watt? to the Trash. Nothing is left behind.")
        for native in ["Form {", ".formStyle(.grouped)", ".toggleStyle(.switch)", ".buttonStyle(.bordered)"] {
            XCTAssertTrue(source.contains(native))
        }
        for painted in ["LinearGradient", "RoundedRectangle", ".tint(", "NSAlert("] {
            XCTAssertFalse(source.contains(painted))
        }
    }

    func testPresentCancelAndStaleConfirmNeverRemoveOrChangePreferences() async throws {
        // Exercise production routing in Release without importing launch fixtures.
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.openAtLogin = true
        let router = AppRouter()
        var removals = 0
        router.removeFromSettings = { _ in removals += 1; return .verifiedAbsent }
        let presentation = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: presentation, removing: false))
        let intent = try XCTUnwrap(router.uninstallIntent)
        XCTAssertEqual(removals, 0)
        router.cancelUninstall(intent)
        XCTAssertNil(router.uninstallIntent)
        let staleResult = await router.confirmUninstall(intent)
        XCTAssertNil(staleResult)
        XCTAssertEqual(removals, 0)
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertTrue(router.requestUninstall(presentation: presentation, removing: false))
        let confirmed = try XCTUnwrap(router.uninstallIntent)
        let result = await router.confirmUninstall(confirmed)
        XCTAssertEqual(result, .verifiedAbsent)
        let duplicate = await router.confirmUninstall(confirmed)
        XCTAssertNil(duplicate)
        XCTAssertEqual(removals, 1)
    }
}
