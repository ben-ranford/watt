import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J71ShowInMenuBarTests: XCTestCase {
    func testExactNativeMenuOrderingSelectionAndShortcuts() throws {
        let preferences = J71FixtureLaunch.makePreferences()
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences,
                                                  componentsAvailable: { true })
        XCTAssertEqual(menu.items.map(\.title), ["Show in Menu Bar", "", "Open Watt?", "Settings…", "",
                                               "About Watt?", "Check for Updates…", "", "Quit Watt?"])
        XCTAssertEqual(menu.items.map(\.isSeparatorItem), [false, true, false, false, true, false, false, true, false])
        let readings = try submenu(menu)
        XCTAssertEqual(readings.items.map(\.title), ["Delta", "Charger", "Draw", "Components", "", "Icon"])
        XCTAssertEqual(readings.items.map(\.isSeparatorItem), [false, false, false, false, true, false])
        XCTAssertEqual(readings.items.filter { $0.state == .on }.map(\.title), ["Delta"])
        XCTAssertTrue(menu.showsStateColumn)
        XCTAssertTrue(readings.showsStateColumn)
        XCTAssertFalse(readings.autoenablesItems)
        XCTAssertNil(menu.appearance)
        XCTAssertNil(readings.appearance)
        for item in menu.items + readings.items where !item.isSeparatorItem {
            XCTAssertNil(item.view, "AppKit owns rows, highlighting and keyboard tracking")
            XCTAssertEqual(item.isEnabled, item.title != "Check for Updates…")
            let key = item.title == "Settings…" ? "," : item.title == "Quit Watt?" ? "q" : ""
            XCTAssertEqual(item.keyEquivalent, key)
            XCTAssertEqual(item.keyEquivalentModifierMask, key.isEmpty ? [] : .command)
        }
        XCTAssertTrue(readings.supermenu === menu)
    }

    func testEveryModeMutatesSharedPreferencesAndRebuildsCheckmark() throws {
        let preferences = J71FixtureLaunch.makePreferences()
        let router = AppRouter()
        let baseline = preferences.onboarding
        for (title, mode) in [("Charger", WattDisplayMode.charger), ("Draw", .draw),
                              ("Components", .components), ("Icon", .iconOnly), ("Delta", .delta)] {
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
            try invoke(try item(title, in: submenu(menu)))
            XCTAssertEqual(preferences.displayMode, mode)
            XCTAssertEqual(preferences.onboarding, baseline)
            XCTAssertTrue(preferences.componentReadings)
            let rebuilt = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
            XCTAssertEqual(try submenu(rebuilt).items.filter { $0.state == .on }.map(\.title), [title])
        }
    }

    func testComponentsRechecksAvailabilityAndPreferenceAtInvocation() throws {
        for disablePreference in [false, true] {
            let preferences = J71FixtureLaunch.makePreferences()
            let router = AppRouter()
            var available = true
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { available })
            let components = try item("Components", in: submenu(menu))
            XCTAssertTrue(components.isEnabled)
            if disablePreference { preferences.componentReadings = false } else { available = false }
            try invoke(components)
            XCTAssertEqual(preferences.displayMode, .delta)
            let rebuilt = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { available })
            let readings = try submenu(rebuilt)
            XCTAssertFalse(try item("Components", in: readings).isEnabled)
            XCTAssertEqual(readings.items.map(\.title), ["Delta", "Charger", "Draw", "Components", "", "Icon", "", "Turn On Helper…"])
            var routes: [AppDestination] = []
            router.present = { routes.append($0) }
            try invoke(try item("Turn On Helper…", in: readings))
            XCTAssertEqual(routes, [.settings])
        }
    }

    func testComponentsRechecksHelperLossAndPreservesSavedSelection() async throws {
        let session = J25FixtureSession()
        await session.connect()
        session.preferences.onboarding.completed = true
        let menu = StatusItemContextMenu.makeMenu(router: session.router, preferences: session.preferences,
                                                  componentsAvailable: { true })
        let components = try item("Components", in: submenu(menu))
        XCTAssertTrue(components.isEnabled)
        session.preferences.displayMode = .charger
        session.helper.disconnect()
        XCTAssertTrue(session.router.settingsHelperSetup.helperSwitchedOff)
        try invoke(components)
        XCTAssertEqual(session.preferences.displayMode, .charger)
        let rebuilt = StatusItemContextMenu.makeMenu(router: session.router, preferences: session.preferences,
                                                     componentsAvailable: { true })
        let readings = try submenu(rebuilt)
        XCTAssertFalse(try item("Components", in: readings).isEnabled)
        XCTAssertEqual(readings.items.filter { $0.state == .on }.map(\.title), ["Delta"])
        XCTAssertEqual(readings.items.last?.title, "Turn On Helper…")
    }

    func testNavigationAndSystemActionCallbacks() throws {
        for title in ["Open Watt?", "Settings…", "About Watt?", "Check for Updates…", "Quit Watt?"] {
            let preferences = J71FixtureLaunch.makePreferences()
            let router = AppRouter()
            var destinations: [AppDestination] = []
            var about = 0
            var quit = 0
            router.present = { destinations.append($0) }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences,
                componentsAvailable: { true }, onAbout: { about += 1 }, onQuit: { quit += 1 })
            try invoke(try item(title, in: menu))
            let expected: [AppDestination] = title == "Open Watt?" ? [.statusPanel] :
                title == "Settings…" ? [.settings] : []
            XCTAssertEqual(destinations, expected)
            XCTAssertEqual(about, title == "About Watt?" ? 1 : 0)
            XCTAssertEqual(quit, title == "Quit Watt?" ? 1 : 0)
            XCTAssertEqual(preferences.displayMode, .delta)
            XCTAssertTrue(preferences.onboarding.completed)
        }
    }

    func testFinishSetupRemainsConditionalAndResumesPicker() throws {
        let preferences = J71FixtureLaunch.makePreferences()
        preferences.onboarding.completed = false
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
        XCTAssertEqual(Array(menu.items.prefix(3)).map(\.title), ["Finish Setup…", "", "Show in Menu Bar"])
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        try invoke(menu.items[0])
        XCTAssertEqual(routes, [.onboarding])
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertTrue(preferences.onboarding.helperOptIn)
        try invoke(menu.items[0])
        XCTAssertEqual(routes, [.onboarding])
    }

    func testExactFixtureSelectorAndMalformedRejections() throws {
        let fixture = try ScenarioRegistry.resolve("J7.1")
        XCTAssertEqual(fixture.story.node, "31:6173")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let arguments = ["Watt", "--watt-fixture", "J7.1/base"]
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(arguments))
        XCTAssertEqual(try launch.smokeLaunchArguments(), Array(arguments.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J71FixtureLaunch.matches(arguments: arguments))
        XCTAssertFalse(J71FixtureLaunch.requested)
        #else
        XCTAssertTrue(J71FixtureLaunch.matches(arguments: arguments))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: arguments))
        #endif
        for selector in ["J7.1/light", "J7.1/dark", "J7.1/unknown", "J7.1/base/extra", "J7.1/", "j7.1/base", "/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J71FixtureLaunch.matches(arguments: invalid))
        }
        for invalid in [[], ["Watt", "--watt-fixture"], ["Watt", "--watt-fixture", "J6.5/base"],
                        arguments + ["--watt-fixture", "J7.1/base"]] {
            XCTAssertFalse(J71FixtureLaunch.matches(arguments: invalid))
        }
    }

    func testFreshIsolatedChargingFixtureAndNativeLightStatusLabel() {
        let first = J71FixtureLaunch.makePreferences()
        let second = J71FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertTrue(first.onboarding.completed)
        XCTAssertTrue(first.onboarding.helperOptIn)
        XCTAssertTrue(first.componentReadings)
        XCTAssertEqual(first.displayMode, .delta)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertTrue(first.showSymbol)
        XCTAssertNil(first.persistenceFailure)
        first.displayMode = .draw
        first.componentReadings = false
        first.onboarding.completed = false
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.componentReadings)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        let store = J71FixtureLaunch.makeStore()
        let other = J71FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        XCTAssertEqual(store.statusReading, .sampleCharging)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let label = MenuBarStatusLabel(reading: store.statusReading, preferences: second)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(J71FixtureLaunch.appearanceName, .aqua)
        let generation = store.generation
        store.disconnect()
        XCTAssertFalse(store.accept(.sampleCharging, generation: generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(other.statusReading, .sampleCharging)
    }

    func testFixtureHelperConnectionIsIsolatedAndDoesNotRoute() async {
        let router = AppRouter()
        let untouched = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        await J71FixtureLaunch.prepare(router: router)
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertFalse(router.settingsHelperSetup.helperSwitchedOff)
        XCTAssertFalse(untouched.settingsHelperSetup.helperOn)
        XCTAssertTrue(routes.isEmpty)
    }

    private func submenu(_ menu: NSMenu) throws -> NSMenu {
        try XCTUnwrap(menu.items.first { $0.title == "Show in Menu Bar" }?.submenu)
    }

    private func item(_ title: String, in menu: NSMenu) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.title == title })
    }

    private func invoke(_ item: NSMenuItem) throws {
        let action = try XCTUnwrap(item.action)
        XCTAssertTrue(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }
}
