import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J93AfterQuitTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndFailClosedSelection() throws {
        let fixture = try ScenarioRegistry.resolve("J9.3")
        XCTAssertEqual(fixture.story.node, "32:6494")
        XCTAssertEqual(fixture.story.status, "implemented")
        let args = ["--watt-fixture", "J9.3/base"]
        XCTAssertEqual(try FixtureLaunchSelection.parse(args)?.smokeLaunchArguments(), args)
        #if SWIFT_PACKAGE
        XCTAssertFalse(J93FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J93FixtureLaunch.matches(arguments: args))
        #endif
        for value in ["J9.3", "J9.3/", "J9.3/dark", "J9.3/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
    }

    func testNativeQuitActionAndShortcutPreservePreferences() throws {
        let preferences = J93FixtureLaunch.makePreferences()
        let before = preferences.onboarding
        var quits = 0
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences,
                                                   onQuit: { quits += 1 })
        let index = try XCTUnwrap(menu.items.firstIndex { $0.title == "Quit Watt?" })
        XCTAssertEqual(menu.items[index].keyEquivalent, "q")
        XCTAssertEqual(menu.items[index].keyEquivalentModifierMask, .command)
        menu.performActionForItem(at: index)
        XCTAssertEqual(quits, 1)
        XCTAssertEqual(preferences.onboarding, before)
    }
    #endif

    func testTerminationIsIdempotentAndRejectsStaleReopen() {
        let delegate = WattApplicationDelegate()
        var cleanup = 0
        var reopen = 0
        delegate.onTerminate = { cleanup += 1 }
        delegate.onReopen = { reopen += 1 }
        let note = Notification(name: NSApplication.willTerminateNotification)
        delegate.applicationWillTerminate(note)
        delegate.applicationWillTerminate(note)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertTrue(delegate.isTerminating)
        XCTAssertNil(delegate.onTerminate)
        XCTAssertNil(delegate.onReopen)
        XCTAssertEqual(cleanup, 1)
        XCTAssertEqual(reopen, 0)
        XCTAssertFalse(NSApplication.shared.windows.contains { $0.isVisible })
    }

    func testAnchorTeardownReleasesCallbacksAndIsRepeatable() {
        let anchor = StatusAnchorView()
        anchor.install = {}
        anchor.makeMenu = { NSMenu() }
        anchor.tearDown()
        anchor.tearDown()
        XCTAssertNil(anchor.install)
        XCTAssertNil(anchor.makeMenu)
        XCTAssertNil(anchor.window)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFreshLaunchKeepsSettingsAndDeferredSetupRouting() {
        let preferences = J93FixtureLaunch.makePreferences()
        for _ in 0..<2 {
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = { destinations.append($0) }
            router.launch(preferences: preferences)
            router.launch(preferences: preferences)
            XCTAssertEqual(destinations, [.settings])
            XCTAssertFalse(router.statusPanelPresented)
            XCTAssertFalse(WattApplicationDelegate().isTerminating)
        }
        preferences.onboarding = .init(checkpoint: .runningDefaults, completed: false)
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        router.launch(preferences: preferences)
        XCTAssertTrue(destinations.isEmpty)
    }
    #endif

    func testNativeCompositionHasNoAfterQuitSurface() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try String(contentsOf: root.appendingPathComponent("App/J93FixtureLaunch.swift"), encoding: .utf8)
        for token in ["NSWindow(", "NSStatusBar.system.statusItem", "LinearGradient", "NSHostingView", "DesktopTemplate"] {
            XCTAssertFalse(fixture.contains(token), token)
        }
        XCTAssertTrue(fixture.contains("menu.performActionForItem"))
        let menu = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusItemContextMenu.swift"), encoding: .utf8)
        XCTAssertTrue(menu.contains("NSApplication.shared.terminate(nil)"))
    }
}
