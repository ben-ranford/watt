import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J53FinishSetupTests: XCTestCase {
    private let checkpoints: [OnboardingCheckpoint] = [
        .welcome, .picker, .helperOffer, .approval, .preview, .allSet,
        .coachMark, .livePanel, .welcomeClosed, .runningDefaults
    ]

    func testExactNativeMenuContentOrderShortcutsAndConditionalFirstAction() throws {
        for completed in [false, true] {
            let preferences = PreferencesStore(storage: CountingStorage())
            preferences.onboarding.completed = completed
            let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences)
            let ordinary = ["Show in Menu Bar", "", "Open Watt?", "Settings…", "",
                            "About Watt?", "Check for Updates…", "", "Quit Watt?"]
            XCTAssertEqual(menu.items.map(\.title), (completed ? [] : ["Finish Setup…", ""]) + ordinary)
            XCTAssertEqual(menu.items.map(\.isSeparatorItem), menu.items.map { $0.title.isEmpty })
            XCTAssertTrue(menu.showsStateColumn)
            for item in menu.items where !item.isSeparatorItem {
                XCTAssertNil(item.view, "Native menu rows must not paint custom chrome")
                XCTAssertEqual(item.isEnabled, item.title != "Check for Updates…")
                XCTAssertEqual(item.keyEquivalent, item.title == "Settings…" ? "," : item.title == "Quit Watt?" ? "q" : "")
                XCTAssertEqual(item.keyEquivalentModifierMask, item.keyEquivalent.isEmpty ? [] : .command)
            }
            let submenu = try XCTUnwrap(menu.items.first { $0.title == "Show in Menu Bar" }?.submenu)
            XCTAssertTrue(submenu.showsStateColumn)
            XCTAssertFalse(submenu.autoenablesItems)
            XCTAssertEqual(submenu.items.map(\.title), ["Battery Delta", "Charger Input", "System Draw", "Per Component", "", "Icon Only", "", "Turn On Helper…"])
            XCTAssertEqual(submenu.items.filter { $0.state == .on }.map(\.title), ["System Draw"])
            XCTAssertFalse(submenu.items[3].isEnabled)
            XCTAssertTrue(submenu.items.filter { !$0.isSeparatorItem && $0.title != WattDisplayMode.components.title }.allSatisfy(\.isEnabled))
            XCTAssertTrue(submenu.items.allSatisfy { $0.view == nil })
        }
    }

    func testSubmenuUsesNativeSelectionAndGuardsUnavailableComponents() throws {
        let preferences = PreferencesStore(storage: CountingStorage())
        preferences.onboarding.completed = true
        preferences.displayMode = .charger
        let router = AppRouter()
        var available = true
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { available })
        let submenu = try XCTUnwrap(menu.items.first?.submenu)
        XCTAssertEqual(submenu.items.map(\.title), ["Battery Delta", "Charger Input", "System Draw", "Per Component", "", "Icon Only"])
        XCTAssertEqual(submenu.items.filter { $0.state == .on }.map(\.title), ["Charger Input"])
        XCTAssertTrue(submenu.items[3].isEnabled)
        available = false
        try invoke(submenu.items[3])
        XCTAssertEqual(preferences.displayMode, .charger)
        try invoke(submenu.items[2])
        XCTAssertEqual(preferences.displayMode, .draw)
    }

    func testEveryIncompleteCheckpointPersistsPickerBeforeNavigationAndPreservesOtherState() throws {
        for checkpoint in checkpoints {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = .init(checkpoint: checkpoint, helperOptIn: true, deferredSetupID: UUID())
            preferences.displayMode = .charger
            preferences.precision = .whole
            preferences.showSymbol = false
            preferences.updateInterval = "Every 5 seconds"
            preferences.smoothReadings = false
            preferences.componentReadings = false
            preferences.chargerNotification = false
            preferences.fullyChargedNotification = true
            preferences.openAtLogin = false
            preferences.checkForUpdatesAutomatically = false
            preferences.selectedComponents = ["GPU"]
            let before = try storedFields(storage)
            let router = AppRouter()
            let helper = router.settingsHelperSetup
            let helperState = helper.state
            router.statusPanelPresented = true
            var routes: [AppDestination] = []
            router.present = {
                routes.append($0)
                let disk = PreferencesStore(storage: storage)
                XCTAssertEqual(disk.onboarding, preferences.onboarding)
                XCTAssertEqual(disk.onboarding.checkpoint, .picker)
                XCTAssertFalse(disk.onboarding.completed)
                XCTAssertTrue(disk.onboarding.helperOptIn)
                XCTAssertNil(disk.onboarding.deferredSetupID)
                XCTAssertFalse(router.statusPanelPresented)
            }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
            let item = try finishItem(menu)
            let writes = storage.writes
            try invoke(item)
            try invoke(item)
            XCTAssertEqual(storage.writes, writes + 1)
            XCTAssertEqual(routes, [.onboarding])
            XCTAssertEqual(try storedFields(storage), before)
            XCTAssertTrue(router.settingsHelperSetup === helper)
            XCTAssertEqual(helper.state, helperState)
        }
    }

    func testChangedCapturedSnapshotsAndCompletedStateNeverWriteOrNavigate() throws {
        let original = OnboardingState(checkpoint: .runningDefaults, helperOptIn: true, deferredSetupID: UUID())
        for changed in [OnboardingState(checkpoint: .welcomeClosed),
                        .init(checkpoint: .runningDefaults, completed: true, helperOptIn: true, deferredSetupID: original.deferredSetupID),
                        .init(checkpoint: .runningDefaults, helperOptIn: false, deferredSetupID: original.deferredSetupID),
                        .init(checkpoint: .runningDefaults, helperOptIn: true, deferredSetupID: UUID())] {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = original
            let router = AppRouter()
            router.present = { _ in XCTFail("Changed menu snapshot navigated") }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
            preferences.onboarding = changed
            let writes = storage.writes
            try invoke(finishItem(menu))
            XCTAssertEqual(preferences.onboarding, changed)
            XCTAssertEqual(storage.writes, writes)
        }
    }

    func testFailedWriteConsumesActionAndFreshMenuCanRetry() throws {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .runningDefaults, helperOptIn: true)
        let before = preferences.onboarding
        let disk = storage.values
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        let item = try finishItem(menu)
        let writes = storage.writes
        storage.failWrites = true
        try invoke(item)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        storage.failWrites = false
        try invoke(item)
        XCTAssertEqual(storage.writes, writes + 1)
        XCTAssertEqual(preferences.onboarding, before)
        XCTAssertEqual(storage.values, disk)
        XCTAssertTrue(routes.isEmpty)
        let retry = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        try invoke(finishItem(retry))
        XCTAssertEqual(storage.writes, writes + 2)
        XCTAssertEqual(routes, [.onboarding])
        XCTAssertNil(preferences.persistenceFailure)
    }

    func testClosedAndReplacedMenusRejectRetainedActionsWithoutInvalidatingNewMenu() throws {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let closed = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        StatusItemContextMenu.endPresentation(closed)
        let writes = storage.writes
        try invoke(finishItem(closed))
        let replaced = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        let current = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        StatusItemContextMenu.endPresentation(replaced)
        try invoke(finishItem(replaced))
        XCTAssertEqual(storage.writes, writes)
        XCTAssertTrue(routes.isEmpty)
        try invoke(finishItem(current))
        XCTAssertEqual(routes, [.onboarding])
        XCTAssertEqual(storage.writes, writes + 1)
    }

    func testOtherMenuActionsConsumeFinishSetupAndRouteNormally() throws {
        for title in ["Open Watt?", "Settings…", "About Watt?", "Quit Watt?", "System Draw", "Turn On Helper…"] {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            let router = AppRouter()
            var routes: [AppDestination] = []
            var about = 0
            var quit = 0
            router.present = { routes.append($0) }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences,
                onAbout: { about += 1 }, onQuit: { quit += 1 })
            let submenu = try XCTUnwrap(menu.items.first { $0.title == "Show in Menu Bar" }?.submenu)
            let action = try XCTUnwrap((menu.items + submenu.items).first { $0.title == title })
            try invoke(action)
            let writes = storage.writes
            try invoke(finishItem(menu))
            XCTAssertEqual(storage.writes, writes)
            XCTAssertEqual(preferences.onboarding.checkpoint, .welcome)
            let expected: [AppDestination] = title == "Open Watt?" ? [.statusPanel] :
                ["Settings…", "Turn On Helper…"].contains(title) ? [.settings] : []
            XCTAssertEqual(routes, expected)
            XCTAssertEqual(about, title == "About Watt?" ? 1 : 0)
            XCTAssertEqual(quit, title == "Quit Watt?" ? 1 : 0)
        }
    }

    func testRoutingInvalidatesRetainedMenuEvenWhenSnapshotIsUnchanged() throws {
        let actions: [(AppRouter) -> Void] = [
            { $0.beginOnboarding() }, { $0.showCoachMark() }, { $0.showStatusPanel() },
            { $0.showSettings() }, { $0.showUpdate() },
            { $0.reopen(setupComplete: false) }, { $0.reopen(setupComplete: true) },
            { $0.launch(setupComplete: false) }
        ]
        for route in actions {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            let router = AppRouter()
            var routes: [AppDestination] = []
            router.present = { routes.append($0) }
            let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
            route(router)
            let expected = routes
            let writes = storage.writes
            try invoke(finishItem(menu))
            XCTAssertEqual(routes, expected)
            XCTAssertEqual(storage.writes, writes)
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureRegistrationAndIsolatedPreparation() throws {
        let fixture = try ScenarioRegistry.resolve("J5.3")
        XCTAssertEqual(fixture.story.node, "J5.3")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J5.3/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J5.3", variant: "dark"))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J5.3/unknown"]))
        let preferences = PreferencesStore(storage: CountingStorage())
        let untouched = PreferencesStore(storage: CountingStorage())
        J53FixtureLaunch.prepare(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .runningDefaults)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertEqual(preferences.displayMode, .draw)
        XCTAssertEqual(untouched.onboarding.checkpoint, .welcome)
        #if SWIFT_PACKAGE
        XCTAssertFalse(J53FixtureLaunch.requested)
        #endif
    }
    #endif

    private func finishItem(_ menu: NSMenu) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.title == "Finish Setup…" })
    }

    private func invoke(_ item: NSMenuItem) throws {
        let action = try XCTUnwrap(item.action)
        XCTAssertTrue(NSApplication.shared.sendAction(action, to: item.target, from: item))
    }

    private func storedFields(_ storage: CountingStorage) throws -> NSDictionary {
        let data = try XCTUnwrap(storage.values["preferences.v1"])
        var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        fields.removeValue(forKey: "onboarding")
        return fields as NSDictionary
    }

    @MainActor
    private final class CountingStorage: PreferenceStorage {
        var values: [String: Data] = [:]
        var writes = 0
        var failWrites = false
        func read(key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws {
            writes += 1
            if failWrites { throw ServiceFailure.persistence }
            values[key] = data
        }
    }
}
