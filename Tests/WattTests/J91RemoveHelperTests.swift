import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J91RemoveHelperTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndFailClosedSelectors() throws {
        let fixture = try ScenarioRegistry.resolve("J9.1")
        XCTAssertEqual(fixture.story.node, "32:5397")
        XCTAssertEqual(fixture.story.expectedScene, "alert")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let args = ["Watt", "--watt-fixture", "J9.1/base"]
        XCTAssertEqual(try FixtureLaunchSelection.parse(args)?.smokeLaunchArguments(), ["--watt-fixture", "J9.1/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J91FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J91FixtureLaunch.matches(arguments: args))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        #endif
        for value in ["J9.1", "J9.1/", "J9.1/dark", "J9.1//base", "J9.1/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
    }

    func testSettingsLaunchAndWaitingForConfirmationPreserveHelper() async {
        let preferences = J91FixtureLaunch.makePreferences()
        let router = AppRouter()
        await J91FixtureLaunch.prepare(router: router)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var removals = 0
        router.removeFromSettings = { _ in removals += 1; return .verifiedAbsent }
        router.launch(preferences: preferences)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(removals, 0)
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertEqual(MenuBarStatusLabel(reading: J91FixtureLaunch.makeStore().currentReading, preferences: preferences).text,
                       "CPU 9.8 · GPU 4.1 W")
    }

    func testConfirmedVerifiedRemovalSwitchesToDeltaOnlyAfterCompletion() async {
        let preferences = J91FixtureLaunch.makePreferences()
        let router = AppRouter()
        await J91FixtureLaunch.prepare(router: router)
        router.removeFromSettings = { target in
            XCTAssertEqual(target, .helper)
            XCTAssertTrue(preferences.componentReadings)
            XCTAssertEqual(preferences.displayMode, .components)
            return .verifiedAbsent
        }
        let outcome = await router.removeVerifiedHelper(preferences: preferences)
        XCTAssertEqual(outcome, .verifiedAbsent)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
        XCTAssertEqual(preferences.displayMode, .delta)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
    }

    func testCancelledAndFailedRemovalDoNotReportSuccessOrSwitchMode() async {
        for outcome: RemovalOutcome in [.cancelled, .failed(.denied)] {
            let preferences = J91FixtureLaunch.makePreferences()
            let router = AppRouter()
            await J91FixtureLaunch.prepare(router: router)
            router.removeFromSettings = { _ in outcome }
            let actual = await router.removeVerifiedHelper(preferences: preferences)
            XCTAssertEqual(actual, outcome)
            XCTAssertTrue(preferences.componentReadings)
            XCTAssertTrue(router.settingsHelperSetup.helperOn)
            XCTAssertEqual(preferences.displayMode, .components)
        }
    }

    func testUnverifiedHelperNeverInvokesRemoval() async {
        let router = AppRouter()
        let preferences = J91FixtureLaunch.makePreferences()
        router.removeFromSettings = { _ in XCTFail("Unverified removal"); return .verifiedAbsent }
        let result = await router.removeVerifiedHelper(preferences: preferences)
        XCTAssertEqual(result, .failed(.unknownStatus))
        XCTAssertEqual(preferences.displayMode, .components)
    }

    func testNativeAlertCopyRolesNoOpCancelAndSettingsComposition() throws {
        XCTAssertEqual(SettingsRootView.removeHelperTitle, "Remove the helper?")
        XCTAssertEqual(SettingsRootView.removeHelperMessage,
                       "Components stop and the menu bar switches to Delta. Turn it back on any time.")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
        for token in [".alert(", "Button(\"Cancel\", role: .cancel)", "role: .destructive",
                      "await router.removeVerifiedHelper(preferences: preferences)", "Text(target == .helper ? Self.removeHelperMessage : Self.uninstallMessage)",
                      ".formStyle(.grouped)", "LabeledContent", "Button(\"Remove…\", action: remove)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "LinearGradient", "NSWindow(contentRect"] { XCTAssertFalse(source.contains(token)) }
        let host = NSHostingView(rootView: SettingsRootView(removalExcerpt: true)
            .environmentObject(J91FixtureLaunch.makePreferences()).environmentObject(AppRouter())
            .environmentObject(J91FixtureLaunch.makeStore()))
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(host.fittingSize.width, 0)
    }
    #endif
}
