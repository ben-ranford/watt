import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J83OpeningSettingsTests: XCTestCase {
    func testExactStoryMetadataAndSelector() throws {
        let fixture = try ScenarioRegistry.resolve("J8.3")
        XCTAssertEqual(fixture.story.node, "32:4575")
        XCTAssertEqual(fixture.story.frame, "8.3 Opening Watt? again from Finder or Spotlight shows Settings")
        XCTAssertEqual(fixture.story.expectedScene, "settings")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())

        let args = ["Watt", "--watt-fixture", "J8.3/base"]
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J8.3/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J83FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J83FixtureLaunch.matches(arguments: args))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        #endif

        for selector in ["J8.3", "J8.3/stale", "J8.3/", "J8.3//base", "J8.3/base/extra", "j8.3/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J83FixtureLaunch.matches(arguments: invalid))
        }
    }

    func testConfiguredNormalLaunchRoutesSettingsAndIsIdempotent() {
        let preferences = J83FixtureLaunch.makePreferences()
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }

        router.launch(preferences: preferences)
        router.launch(preferences: preferences)

        XCTAssertEqual(routes, [.settings])
        XCTAssertTrue(preferences.onboarding.completed)
        XCTAssertEqual(preferences.onboarding.checkpoint, .livePanel)
    }

    func testFirstCompletedLaunchStillShowsCoachMarkBeforeSettings() {
        let preferences = J83FixtureLaunch.makePreferences()
        preferences.onboarding.checkpoint = .coachMark
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }

        router.launch(preferences: preferences)

        XCTAssertEqual(routes, [.coachMark])
    }

    func testConfiguredValuesSurviveSettingsLaunchAndRestore() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.displayMode = .delta
        preferences.showSymbol = true
        preferences.openAtLogin = true
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        let expected = (preferences.displayMode, preferences.showSymbol, preferences.openAtLogin, preferences.onboarding)
        let router = AppRouter()
        router.present = { XCTAssertEqual($0, .settings) }

        router.launch(preferences: preferences)

        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.displayMode, expected.0)
        XCTAssertEqual(restored.showSymbol, expected.1)
        XCTAssertEqual(restored.openAtLogin, expected.2)
        XCTAssertEqual(restored.onboarding, expected.3)
    }

    func testRelaunchExcerptUsesNativeSettingsFormRowsAndSystemControls() throws {
        let view = SettingsRootView(relaunchExcerpt: true)
            .environmentObject(J83FixtureLaunch.makePreferences())
            .environmentObject(J83FixtureLaunch.makeStore())
            .environmentObject(AppRouter())
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: J83FixtureLaunch.appearanceName)
        host.layoutSubtreeIfNeeded()

        XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
        XCTAssertGreaterThan(host.fittingSize.width, 0)
        XCTAssertGreaterThan(host.fittingSize.height, 0)

        let source = try source("Features/Settings/Views/SettingsRootView.swift")
        for token in ["var relaunchExcerpt = false", "Section(\"Menu Bar\")", "Picker(\"Show\"",
                      "Toggle(\"Show symbol\"", "Section(\"General\")", "Toggle(\"Open at login\"",
                      "LabeledContent(\"Version\", value: version)", ".formStyle(.grouped)", ".toggleStyle(.switch)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for forbidden in ["RoundedRectangle", "LinearGradient", "NSWindow(contentRect", "traffic"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testNativeAppCompositionReusesSettingsSceneAndRoutesConfiguredLaunch() throws {
        let app = try source("App/WattApp.swift")
        let router = try source("App/AppRouter.swift")
        for token in ["SettingsRootView(menuBarExcerpt: settingsMenuBarExcerpt,",
                      "relaunchExcerpt: settingsRelaunchExcerpt", "openSettings()", "router.launch(preferences: preferences)"] {
            XCTAssertTrue(app.contains(token), token)
        }
        XCTAssertTrue(router.contains("else if state.completed { showSettings() }"))
        XCTAssertFalse(app.contains("J83FixtureLaunch.requested { router.showStatusPanel()"))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
