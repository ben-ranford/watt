import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J18LivePanelTests: XCTestCase {
    func testFixtureIsImplementedAndLaunchable() throws {
        let fixture = try ScenarioRegistry.resolve("J1.8")
        XCTAssertEqual(fixture.story.node, "28:2802")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J1.8/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J1.8", variant: "unavailable"))
    }

    func testExactChargingCopyAndRows() {
        let model = StatusPanelModel(reading: .sampleCharging, chargerDescription: "96 W USB-C charger")
        XCTAssertEqual(model.title, "Charging")
        XCTAssertEqual(model.battery, "+42.1 W")
        XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(model.charger, "65.0 W")
        XCTAssertEqual(model.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(model.system, "22.9 W")
        XCTAssertEqual(model.components.map(\.name), ["CPU", "GPU", "Display", "Other"])
        XCTAssertEqual(model.components.map { PowerFormatter.watts($0.watts, signed: false) }, ["9.8 W", "4.1 W", "5.2 W", "3.8 W"])
    }

    func testPanelActionsKeepTheirCallbacksAndNativeSize() {
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        var quitCount = 0
        let panel = StatusPanelView(reading: .sampleCharging, onSettings: { router.showSettings() }, onQuit: { quitCount += 1 })
        panel.onSettings()
        panel.onQuit()
        XCTAssertEqual(destinations, [.settings])
        XCTAssertEqual(quitCount, 1)
        let host = NSHostingView(rootView: panel)
        XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: 473))
    }

    func testGotItRoutesToLivePanelWithoutResettingPreferences() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        preferences.displayMode = .charger
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        XCTAssertEqual(destinations, [.statusPanel])
        XCTAssertEqual(preferences.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(preferences.displayMode, .charger)
    }

    func testNativeSelectionTracksPresentationAndDismissal() {
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        guard let button = item.button else { return XCTFail("Missing native status button") }
        let router = AppRouter()
        let selection = C0410PanelSelection(button: button, router: router,
            preferences: PreferencesStore(storage: InMemoryStorage()), store: .preview)
        XCTAssertTrue(button.target === selection)
        XCTAssertNotNil(button.action)
        selection.applySelection(isPresented: true)
        XCTAssertTrue(router.statusPanelPresented)
        selection.applySelection(isPresented: false)
        XCTAssertFalse(router.statusPanelPresented)
    }
}

@MainActor
final class J22ComponentsOffTests: XCTestCase {
    func testExactFixtureAndUnsupportedVariantsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J2.2")
        XCTAssertEqual(fixture.story.node, "29:2456")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J2.2/base"])
        for variant in ["dark", "unavailable", "helper-on", "alternate"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J2.2/" + variant])?.smokeLaunchArguments())
        }
    }

    func testOffHidesPreviouslyAvailableComponentsButPreservesPowerRows() {
        let model = StatusPanelModel(reading: .sampleCharging, componentReadingsEnabled: false)
        XCTAssertTrue(model.componentsOff)
        XCTAssertTrue(model.components.isEmpty)
        XCTAssertEqual(model.title, "Charging")
        XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(model.charger, "65.0 W")
        XCTAssertNil(model.chargerSubtitle)
        XCTAssertEqual(model.system, "22.9 W")
        XCTAssertEqual(model.battery, "+42.1 W")
        XCTAssertEqual(model.panelHeight, 347)
    }

    func testUnavailableIsNotOffAndEnablingCannotFabricateReadings() {
        let reading = PowerReading(mode: .charging, watts: 42.1,
            components: PowerReading.sampleCharging.components,
            capabilities: .init(components: .permissionRequired), source: .fixture)
        let unavailable = StatusPanelModel(reading: reading, componentReadingsEnabled: true)
        XCTAssertFalse(unavailable.componentsOff)
        XCTAssertTrue(unavailable.components.isEmpty)
        XCTAssertEqual(unavailable.state, .noReading)
        XCTAssertNil(unavailable.panelHeight)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).components.count, 4)
    }

    func testSetupAndFooterCallbacksDoNotEnableHelperOrResetDisplayChoice() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.componentReadings = false
        preferences.displayMode = .charger
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleCharging, componentReadingsEnabled: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        panel.onSettings() // Turn On… and Settings… share the same navigation callback.
        panel.onQuit()
        XCTAssertEqual(destinations, [.settings])
        XCTAssertEqual(quits, 1)
        XCTAssertFalse(PreferencesStore(storage: storage).componentReadings)
        XCTAssertEqual(preferences.displayMode, .charger)
        XCTAssertEqual(NSHostingView(rootView: panel).fittingSize, NSSize(width: 320, height: 347))
    }

    func testNativeOffControlsAndProductionPreferenceWiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"), encoding: .utf8)
        for token in ["Text(\"Off\")", "Turn on the helper to see where the power goes.",
                      "Button(\"Turn On…\", action: onSettings)", ".buttonStyle(.bordered)",
                      ".buttonStyle(.borderless)", "LabeledContent", "WattTypography.subheadline"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "LinearGradient", ".shadow(", ".tint("] {
            XCTAssertFalse(source.contains(token), token)
        }
        let composition = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/MenuBarRootView.swift"), encoding: .utf8)
        XCTAssertTrue(composition.contains("componentReadingsEnabled: preferences.componentReadings"))
    }
}
