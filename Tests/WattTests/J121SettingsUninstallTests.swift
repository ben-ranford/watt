import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J121SettingsUninstallTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndReleasePackageGate() throws {
        let fixture = try ScenarioRegistry.resolve("J12.1")
        XCTAssertEqual(fixture.story.node, "35:4360")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J12.1/base"])
        for value in ["J12.1", "J12.1/", "J12.1/dark", "J12.1//base", "J12.1/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J121FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.1/base"]))
        #else
        XCTAssertTrue(J121FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.1/base"]))
        #endif
    }
    #endif

    func testHandoffIsScopedAndNeverPerformsCleanup() {
        let router = AppRouter()
        var calls = 0
        router.removeFromSettings = { _ in calls += 1; return .verifiedAbsent }
        XCTAssertFalse(router.requestUninstall(presentation: nil, removing: false))
        let token = router.beginUninstallPresentation()
        XCTAssertNil(router.uninstallIntent)
        XCTAssertFalse(router.requestUninstall(presentation: token, removing: true))
        XCTAssertTrue(router.requestUninstall(presentation: token, removing: false))
        XCTAssertEqual(router.uninstallIntent?.destination, "J12.2")
        XCTAssertEqual(router.uninstallIntent?.presentation, token)
        XCTAssertFalse(router.requestUninstall(presentation: token, removing: false))
        XCTAssertEqual(calls, 0)
    }

    func testCancelCloseAndStaleCallbacksAreSafeAndRetryable() {
        let router = AppRouter()
        let old = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: old, removing: false))
        router.dismissUninstallIntent(presentation: old)
        XCTAssertNil(router.uninstallIntent)
        XCTAssertTrue(router.requestUninstall(presentation: old, removing: false))
        router.closeUninstallPresentation(old)
        XCTAssertFalse(router.requestUninstall(presentation: old, removing: false))
        let next = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: next, removing: false))
        router.closeUninstallPresentation(old)
        router.dismissUninstallIntent(presentation: old)
        XCTAssertEqual(router.uninstallIntent?.presentation, next)
        XCTAssertNil(AppRouter().uninstallIntent)
    }

    func testUnsavedPreferencesAreNotClearedOrPersistedByIntent() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.openAtLogin = true
        let before = try storage.read(key: "preferences.v1")
        storage.failWrites = true
        preferences.checkForUpdatesAutomatically = false
        XCTAssertNotNil(preferences.persistenceFailure)
        let router = AppRouter()
        let token = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: token, removing: false))
        router.dismissUninstallIntent(presentation: token)
        XCTAssertEqual(try storage.read(key: "preferences.v1"), before)
        XCTAssertNotNil(preferences.persistenceFailure)
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertFalse(preferences.checkForUpdatesAutomatically)
        storage.failWrites = false
        XCTAssertTrue(preferences.save())
        XCTAssertTrue(router.requestUninstall(presentation: token, removing: false))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixtureSettingsAndNativeStatusReading() {
        let preferences = J121FixtureLaunch.makePreferences()
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        router.launch(preferences: preferences)
        XCTAssertEqual(routes, [.settings])
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertTrue(preferences.checkForUpdatesAutomatically)
        XCTAssertTrue(preferences.showSymbol)
        XCTAssertEqual(MenuBarStatusLabel(reading: J121FixtureLaunch.makeStore().currentReading, preferences: preferences).text, "+42.1 W")
    }
    #endif

    func testGeneralRowsUseNativeSemanticsAndOrder() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"))
        let general = try XCTUnwrap(source.components(separatedBy: "private var generalSection: some View {").last)
        let labels = ["Section(\"General\")", "Toggle(\"Open at login\"", "Toggle(\"Check for updates automatically\"", "Button(\"Uninstall…\", role: .destructive)", "LabeledContent(\"Version\""]
        var previous = general.startIndex
        for label in labels {
            let range = try XCTUnwrap(general.range(of: label))
            XCTAssertGreaterThanOrEqual(range.lowerBound, previous)
            previous = range.upperBound
        }
        XCTAssertFalse(general.contains("removeFromSettings"))
        XCTAssertTrue(source.contains(".formStyle(.grouped)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"settings.uninstall\")"))
    }
}
