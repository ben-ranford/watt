import AppKit
import Combine
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J73ChooseComponentsTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactMenuUsesNativeCheckedAndDisabledItems() throws {
        let preferences = J73FixtureLaunch.makePreferences()
        let store = J73FixtureLaunch.makeStore()
        let coordinator = ComponentSelectionMenu.Coordinator(preferences: preferences) { store.availableComponentIDs }
        let button = coordinator.makeButton()
        let menu = try XCTUnwrap(button.menu)
        XCTAssertEqual(menu.items.map(\.title), ["CPU", "GPU", "Display", "SSD", "Other"])
        XCTAssertEqual(menu.items.map(\.state), [.on, .on, .off, .off, .off])
        XCTAssertEqual(menu.items.map(\.isEnabled), [true, true, false, false, false])
        XCTAssertEqual(button.title, "CPU, GPU")
        XCTAssertEqual(button.accessibilityLabel(), "Components")
        XCTAssertEqual(button.accessibilityValue() as? String, "CPU, GPU")
        XCTAssertEqual(button.accessibilityHelp(), "Two fit. More crowd the menu bar.")
        XCTAssertTrue(type(of: button) == NSPopUpButton.self) // Live AX role is checked by the PID-owned capture probe.
        XCTAssertTrue(button.acceptsFirstResponder)
        XCTAssertFalse(menu.autoenablesItems)
        XCTAssertTrue(menu.showsStateColumn)
        XCTAssertFalse(try XCTUnwrap(button.cell as? NSPopUpButtonCell).usesItemFromMenu)
        XCTAssertFalse(try XCTUnwrap(button.cell as? NSPopUpButtonCell).altersStateOfSelectedItem)
        for item in menu.items {
            XCTAssertNil(item.view)
            XCTAssertNil(item.image)
            XCTAssertNotNil(item.target)
            XCTAssertNotNil(item.action)
        }
        XCTAssertNil(menu.appearance)
    }
    #endif

    func testNativeActionsPreserveOrderAndRejectThirdAvailableComponent() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        let coordinator = ComponentSelectionMenu.Coordinator(preferences: preferences) { ["CPU", "GPU", "Display"] }
        let button = coordinator.makeButton()
        let display = try XCTUnwrap(button.item(withTitle: "Display"))
        XCTAssertFalse(display.isEnabled)
        coordinator.toggle(display) // A stale/forged action must also reject the third selection.
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        coordinator.toggle(try XCTUnwrap(button.item(withTitle: "CPU")))
        XCTAssertTrue(display.isEnabled)
        coordinator.toggle(display)
        XCTAssertEqual(preferences.selectedComponents, ["GPU", "Display"])
        XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["GPU", "Display"])
        XCTAssertEqual(button.title, "GPU, Display")
        XCTAssertFalse(try XCTUnwrap(button.item(withTitle: "CPU")).isEnabled)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testUnavailableAndStaleActionsRevalidateCurrentIdentity() throws {
        let preferences = J73FixtureLaunch.makePreferences()
        let clock = FakeWattClock(now: PowerReading.samplePerComponent.timestamp)
        let store = PowerReadingStore(currentReading: .samplePerComponent, clock: clock)
        let coordinator = ComponentSelectionMenu.Coordinator(preferences: preferences) { store.availableComponentIDs }
        let button = coordinator.makeButton()
        let cpu = try XCTUnwrap(button.item(withTitle: "CPU"))
        clock.advance(by: PowerReadingStore.componentsStatusMaximumAge + 1)
        coordinator.toggle(cpu)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(button.itemArray.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(button.itemArray.filter { $0.state == .on }.map(\.title), ["CPU", "GPU"], "Saved intent survives loss of availability")
        store.disconnect()
        coordinator.toggle(cpu)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
    }

    func testCapabilityInvalidSamplesAndAliasesFailClosed() {
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            XCTAssertTrue(makeStore(capability: capability).availableComponentIDs.isEmpty)
        }
        for components in [[PowerComponent(name: "CPU", watts: .nan)],
                           [PowerComponent(id: " ", name: "CPU", watts: 1)],
                           [PowerComponent(id: "CPU", name: "CPU", watts: 1), PowerComponent(id: "cpu", name: "GPU", watts: 2)]] {
            XCTAssertTrue(makeStore(components: components).availableComponentIDs.isEmpty)
        }
        let renamed = makeStore(components: [PowerComponent(id: "sensor-1", name: "CPU", watts: 9.8)])
        let coordinator = ComponentSelectionMenu.Coordinator(preferences: J73FixtureLaunch.makePreferences()) { renamed.availableComponentIDs }
        XCTAssertTrue(coordinator.makeButton().itemArray.allSatisfy { !$0.isEnabled }, "Display names cannot grant component identity")
    }

    func testLowercaseIdentitiesAndEmptySelectionUseNativeSummary() throws {
        let preferences = J73FixtureLaunch.makePreferences()
        preferences.selectedComponents = ["cpu", "gpu"]
        let coordinator = ComponentSelectionMenu.Coordinator(preferences: preferences) { ["cpu", "gpu"] }
        let button = coordinator.makeButton()
        XCTAssertEqual(button.title, "CPU, GPU")
        coordinator.toggle(try XCTUnwrap(button.item(withTitle: "CPU")))
        coordinator.toggle(try XCTUnwrap(button.item(withTitle: "GPU")))
        XCTAssertEqual(preferences.selectedComponents, [])
        XCTAssertEqual(button.title, "None")
        coordinator.toggle(try XCTUnwrap(button.item(withTitle: "GPU")))
        XCTAssertEqual(preferences.selectedComponents, ["gpu"])
    }
    #endif

    func testSelectionPersistenceFailureAndInvalidWritesNeverPublish() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.selectedComponents = ["CPU", "GPU"]
        var published: [[String]] = []
        let observation = preferences.selectedComponentsPublisher.dropFirst().sink { published.append($0) }
        for invalid in [["CPU", "cpu"], ["CPU", "GPU", "Display"], ["\n"], [" CPU"], ["GPU "]] {
            preferences.selectedComponents = invalid
            XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
            XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["CPU", "GPU"])
        }
        storage.failWrites = true
        XCTAssertFalse(preferences.toggleComponent("CPU", availableIDs: ["CPU", "GPU"]))
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(published.isEmpty)
        storage.failWrites = false
        XCTAssertTrue(preferences.toggleComponent("CPU", availableIDs: ["CPU", "GPU"]))
        XCTAssertEqual(published, [["GPU"]])
        XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["GPU"])
        withExtendedLifetime(observation) {}
    }

    func testInvalidPersistedSelectionIsNotLoaded() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.save()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(storage.values["preferences.v1"])) as? [String: Any])
        json["selectedComponents"] = ["CPU", "GPU", "Display"]
        storage.values["preferences.v1"] = try JSONSerialization.data(withJSONObject: json)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.persistenceFailure, .persistence)
        XCTAssertTrue(PreferencesStore.validSelection(restored.selectedComponents))
        XCTAssertFalse(restored.onboarding.completed)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testPreferenceAndHelperLossDisableEvenPreviouslyEnabledAction() async throws {
        let preferences = J73FixtureLaunch.makePreferences()
        let router = AppRouter()
        let store = J73FixtureLaunch.makeStore()
        await J73FixtureLaunch.prepare(router: router)
        let bridge = ComponentSelectionMenu(preferences: preferences, powerStore: store, helper: router.settingsHelperSetup)
        let coordinator = bridge.makeCoordinator()
        let button = coordinator.makeButton()
        let cpu = try XCTUnwrap(button.item(withTitle: "CPU"))
        preferences.componentReadings = false
        coordinator.toggle(cpu)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(button.itemArray.allSatisfy { !$0.isEnabled })
        preferences.componentReadings = true
        let helper = try XCTUnwrap(router.settingsHelperSetup.service as? FakeHelperService)
        helper.status = .failed(.disconnected)
        await router.settingsHelperSetup.refreshStatus()
        coordinator.toggle(cpu)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertTrue(button.itemArray.allSatisfy { !$0.isEnabled })
    }

    func testFixtureIsolationAndFrozenState() async {
        let first = J73FixtureLaunch.makePreferences(), second = J73FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertEqual(first.displayMode, .components)
        XCTAssertEqual(first.precision.rawValue, "42.1 W")
        XCTAssertEqual(first.onboarding, .init(checkpoint: .livePanel, completed: true, helperOptIn: true))
        first.selectedComponents = ["GPU"]
        XCTAssertEqual(second.selectedComponents, ["CPU", "GPU"])
        let store = J73FixtureLaunch.makeStore(), other = J73FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        try? await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        XCTAssertEqual(store.availableComponentIDs, ["CPU", "GPU"])
        let router = AppRouter()
        await J73FixtureLaunch.prepare(router: router)
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertEqual(MenuBarStatusLabel(reading: store.statusReading, preferences: second).text, "CPU 9.8 · GPU 4.1 W")
    }

    func testSelectorOnlyAcceptsExactBase() throws {
        let arguments = ["Watt", "--watt-fixture", "J7.3/base"]
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(arguments))
        XCTAssertEqual(try selection.smokeLaunchArguments(), Array(arguments.dropFirst()))
        let story = try ScenarioRegistry.resolve("J7.3").story
        XCTAssertEqual(story.node, "31:7102")
        XCTAssertEqual(story.expectedScene, "settings")
        XCTAssertEqual(story.appearance, "light")
        XCTAssertEqual(story.variants, ["base"])
        for selector in ["J7.3", "J7.3/", "J7.3//base", "J7.3/base/extra", "J7.3/stale", "j7.3/base"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", selector]))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J73FixtureLaunch.matches(arguments: arguments))
        #else
        XCTAssertTrue(J73FixtureLaunch.matches(arguments: arguments))
        #endif
    }

    func testJ71SettingsActionRoutesToSharedSettingsWithoutChangingSelection() throws {
        let preferences = J73FixtureLaunch.makePreferences()
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
        let settings = try XCTUnwrap(menu.item(withTitle: "Settings…"))
        let action = try XCTUnwrap(settings.action)
        _ = try XCTUnwrap(settings.target as? NSObject).perform(action, with: settings)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        let source = try source("App/WattApp.swift")
        XCTAssertTrue(source.contains("SettingsRootView(menuBarExcerpt: settingsMenuBarExcerpt,"))
        XCTAssertTrue(source.contains("relaunchExcerpt: settingsRelaunchExcerpt, removalExcerpt: settingsRemovalExcerpt,"))
        XCTAssertTrue(source.contains("await J73FixtureLaunch.prepare(router: router)\n                    router.showSettings()"))
        XCTAssertTrue(source.contains("@Environment(\\.openSettings)"))
    }

    func testSettingsNativeLayoutCopyAndAppearance() throws {
        XCTAssertEqual(SettingsRootView.title, "Watt? Settings")
        XCTAssertEqual(SettingsRootView.componentSelectionSubtitle, "Two fit. More crowd the menu bar.")
        let text = try source("Features/Settings/Views/SettingsRootView.swift")
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "Picker(\"Show\"")).lowerBound,
                          try XCTUnwrap(text.range(of: "ComponentSelectionMenu(")).lowerBound)
        XCTAssertLessThan(try XCTUnwrap(text.range(of: "ComponentSelectionMenu(")).lowerBound,
                          try XCTUnwrap(text.range(of: "Picker(\"Precision\"")).lowerBound)
        XCTAssertTrue(text.contains("LabeledContent {"))
        XCTAssertTrue(text.contains("Text(\"Menu Bar\")"))
        XCTAssertTrue(text.contains(".formStyle(.grouped)"))
        XCTAssertFalse(text.contains("componentChoices"))
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let coordinator = ComponentSelectionMenu.Coordinator(preferences: J73FixtureLaunch.makePreferences()) { ["CPU", "GPU"] }
            let button = coordinator.makeButton()
            button.appearance = NSAppearance(named: appearance)
            XCTAssertGreaterThan(button.intrinsicContentSize.width, 0)
            XCTAssertGreaterThan(button.intrinsicContentSize.height, 0)
            XCTAssertEqual(button.title, "CPU, GPU")
        }
        let host = NSHostingView(rootView: SettingsRootView(menuBarExcerpt: true)
            .environmentObject(J73FixtureLaunch.makePreferences())
            .environmentObject(J73FixtureLaunch.makeStore()).environmentObject(AppRouter()))
        host.appearance = NSAppearance(named: J73FixtureLaunch.appearanceName)
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(host.fittingSize.height, 0)
        XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
    }

    private func makeStore(capability: Capability = .available,
                           components: [PowerComponent] = PowerReading.samplePerComponent.components) -> PowerReadingStore {
        let sample = PowerReading(mode: .perComponent, watts: nil, components: components,
            timestamp: PowerReading.samplePerComponent.timestamp, capabilities: .init(components: capability), source: .fixture)
        return PowerReadingStore(currentReading: sample, clock: FakeWattClock(now: sample.timestamp))
    }
    #endif

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
