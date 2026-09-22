import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J122ConfirmUninstallTests: XCTestCase {
    func testExactFixtureAndReleasePackageGate() throws {
        let fixture = try ScenarioRegistry.resolve("J12.2")
        XCTAssertEqual(fixture.story.node, "35:5144")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J12.2/base"])
        for value in ["J12.2", "J12.2/", "J12.2/dark", "J12.2//base", "J12.2/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J122FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.2/base"]))
        #else
        XCTAssertTrue(J122FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.2/base"]))
        #endif
    }

    func testOnlyExplicitExactConfirmationCallsRemovalOnce() async throws {
        let router = AppRouter()
        var calls: [AppRouter.SettingsRemoval] = []
        router.removeFromSettings = { calls.append($0); return .verifiedAbsent }
        let presentation = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: presentation, removing: false))
        let intent = try XCTUnwrap(router.uninstallIntent)
        XCTAssertTrue(calls.isEmpty)
        let result = await router.confirmUninstall(intent)
        XCTAssertEqual(result, .verifiedAbsent)
        let duplicate = await router.confirmUninstall(intent)
        XCTAssertNil(duplicate)
        XCTAssertEqual(calls, [.uninstall])
        XCTAssertNil(router.uninstallIntent)
        XCTAssertFalse(router.uninstallInFlight)
    }

    func testCancelRetryCloseAndStaleGeneration() async throws {
        let router = AppRouter()
        var calls = 0
        router.removeFromSettings = { _ in calls += 1; return .cancelled }
        let presentation = router.beginUninstallPresentation()
        router.requestUninstall(presentation: presentation, removing: false)
        let old = try XCTUnwrap(router.uninstallIntent)
        router.cancelUninstall(old)
        router.requestUninstall(presentation: presentation, removing: false)
        let retry = try XCTUnwrap(router.uninstallIntent)
        XCTAssertNotEqual(old.generation, retry.generation)
        router.cancelUninstall(old)
        XCTAssertEqual(router.uninstallIntent, retry)
        let stale = await router.confirmUninstall(old)
        XCTAssertNil(stale)
        router.closeUninstallPresentation(presentation)
        let closed = await router.confirmUninstall(retry)
        XCTAssertNil(closed)
        XCTAssertEqual(calls, 0)
        let reopened = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: reopened, removing: false))
        XCTAssertNil(AppRouter().uninstallIntent)
    }

    func testInFlightBlocksConcurrentRemovalAcrossReopenAndFailureAllowsRetry() async throws {
        let router = AppRouter()
        var reply: CheckedContinuation<RemovalOutcome, Never>?
        router.removeFromSettings = { _ in await withCheckedContinuation { reply = $0 } }
        let presentation = router.beginUninstallPresentation()
        router.requestUninstall(presentation: presentation, removing: false)
        let intent = try XCTUnwrap(router.uninstallIntent)
        let task = Task { await router.confirmUninstall(intent) }
        for _ in 0..<100 where reply == nil { await Task.yield() }
        XCTAssertNotNil(reply)
        XCTAssertTrue(router.uninstallInFlight)
        router.closeUninstallPresentation(presentation)
        let reopened = router.beginUninstallPresentation()
        XCTAssertFalse(router.requestUninstall(presentation: reopened, removing: false))
        reply?.resume(returning: .failed(.persistence))
        let outcome = await task.value
        XCTAssertEqual(outcome, .failed(.persistence))
        XCTAssertFalse(router.isCurrentUninstallPresentation(presentation))
        XCTAssertTrue(router.isCurrentUninstallPresentation(reopened))
        XCTAssertTrue(router.requestUninstall(presentation: reopened, removing: false))
    }

    func testPersistenceFailureAndCancelDoNotMutatePreferences() async throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.openAtLogin = true
        let before = try storage.read(key: "preferences.v1")
        storage.failWrites = true
        preferences.checkForUpdatesAutomatically = false
        let router = AppRouter()
        router.removeFromSettings = { _ in .failed(.persistence) }
        let presentation = router.beginUninstallPresentation()
        router.requestUninstall(presentation: presentation, removing: false)
        let intent = try XCTUnwrap(router.uninstallIntent)
        router.cancelUninstall(intent)
        XCTAssertNil(router.uninstallIntent)
        router.requestUninstall(presentation: presentation, removing: false)
        let retry = try XCTUnwrap(router.uninstallIntent)
        let result = await router.confirmUninstall(retry)
        XCTAssertEqual(result, .failed(.persistence))
        XCTAssertEqual(try storage.read(key: "preferences.v1"), before)
        XCTAssertNotNil(preferences.persistenceFailure)
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertFalse(preferences.checkForUpdatesAutomatically)
    }

    func testNativeAlertAndFixtureContract() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"))
        XCTAssertTrue(source.contains(".alert("))
        XCTAssertTrue(source.contains("Button(\"Cancel\", role: .cancel)"))
        XCTAssertTrue(source.contains("role: .destructive"))
        XCTAssertTrue(source.contains("router.confirmUninstall(intent)"))
        XCTAssertFalse(source.contains("await router.removeFromSettings"))
        XCTAssertEqual(SettingsRootView.uninstallMessage, "Removes the helper, your settings and the login item, then moves Watt? to the Trash. Nothing is left behind.")
        let prefs = J122FixtureLaunch.makePreferences()
        XCTAssertTrue(prefs.openAtLogin)
        XCTAssertEqual(MenuBarStatusLabel(reading: J122FixtureLaunch.makeStore().currentReading, preferences: prefs).text, "+42.1 W")
    }
}
