import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J21ComponentsUnavailableTests: XCTestCase {
    func testFixtureAndVariantsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J2.1")
        XCTAssertEqual(fixture.story.node, "29:1549")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J2.1/base"])
        for variant in ["dark", "unavailable", "helper-on", "alternate"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J2.1/" + variant]))
        }
    }

    func testNativeRowsDisabledStateAndShortcuts() throws {
        let prefs = PreferencesStore(storage: InMemoryStorage())
        prefs.onboarding.completed = true
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs)
        XCTAssertEqual(menu.items.map { $0.isSeparatorItem ? "|" : $0.title },
            ["Show in Menu Bar", "|", "Open Watt?", "Settings…", "|", "About Watt?",
             "Check for Updates…", "|", "Quit Watt?"])
        let sub = try XCTUnwrap(menu.item(withTitle: "Show in Menu Bar")?.submenu)
        sub.update()
        XCTAssertFalse(sub.autoenablesItems)
        XCTAssertEqual(sub.items.map { $0.isSeparatorItem ? "|" : $0.title },
                       ["Delta", "Charger", "Draw", "Components", "|", "Icon", "|", "Turn On Helper…"])
        XCTAssertFalse(sub.items[3].isEnabled)
        XCTAssertEqual(sub.items.filter { $0.state == .on }.map(\.title), ["Delta"])
        XCTAssertTrue((menu.items + sub.items).allSatisfy { $0.view == nil && $0.image == nil })
        XCTAssertEqual(menu.items[3].keyEquivalent, ",")
        XCTAssertEqual(menu.items[8].keyEquivalent, "q")
        XCTAssertEqual(menu.items[3].keyEquivalentModifierMask, .command)
        XCTAssertEqual(menu.items[8].keyEquivalentModifierMask, .command)
        XCTAssertEqual(MenuBarStatusLabel(reading: .sampleCharging, preferences: prefs).text, "+42.1 W")
    }

    func testUnavailableSelectionCannotMutatePersistedChoice() throws {
        let storage = InMemoryStorage()
        let prefs = PreferencesStore(storage: storage)
        var available = true
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs,
                                                  componentsAvailable: { available })
        let sub = try XCTUnwrap(menu.item(withTitle: "Show in Menu Bar")?.submenu)
        available = false // Capability loss while a menu is open must fail closed.
        try invoke("Components", in: sub)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .delta)
        try invoke("Charger", in: sub)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .charger)
        prefs.displayMode = .components
        let rebuilt = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs)
        XCTAssertFalse(try XCTUnwrap(rebuilt.item(withTitle: "Show in Menu Bar")?.submenu).items[3].isEnabled)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .components,
                       "Capability loss must not silently erase the saved selection")
    }

    func testPreferenceGateAndHelperNavigationDoNotGrantAvailability() throws {
        let storage = InMemoryStorage()
        let prefs = PreferencesStore(storage: storage)
        prefs.componentReadings = false
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: prefs,
                                                  componentsAvailable: { true })
        let sub = try XCTUnwrap(menu.item(withTitle: "Show in Menu Bar")?.submenu)
        XCTAssertFalse(sub.items[3].isEnabled)
        try invoke("Components", in: sub)
        try invoke("Turn On Helper…", in: sub)
        XCTAssertEqual(destinations, [.settings])
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertEqual(prefs.displayMode, .delta)
        prefs.componentReadings = true
        let enabled = StatusItemContextMenu.makeMenu(router: router, preferences: prefs,
                                                     componentsAvailable: { true })
        let enabledSub = try XCTUnwrap(enabled.item(withTitle: "Show in Menu Bar")?.submenu)
        XCTAssertTrue(enabledSub.items[3].isEnabled)
        XCTAssertFalse(enabledSub.items.contains { $0.title == "Turn On Helper…" })
        try invoke("Components", in: enabledSub)
        XCTAssertEqual(prefs.displayMode, .components)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .components)
    }

    // Invoke the real native action even when disabled, proving its guard fails closed.
    private func invoke(_ title: String, in menu: NSMenu) throws {
        let item = try XCTUnwrap(menu.item(withTitle: title))
        let action = try XCTUnwrap(item.action)
        let target = try XCTUnwrap(item.target as? NSObject)
        XCTAssertTrue(target.responds(to: action))
        target.perform(action, with: item)
    }
}
