import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J61DarkChargingTests: XCTestCase {
    func testExactChargingCopyAndPowerRowsWithoutComponents() {
        let model = StatusPanelModel(reading: .sampleCharging,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "Charging")
        XCTAssertEqual(model.headlineValue, "+42.1 W")
        XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(model.charger, "65.0 W")
        XCTAssertEqual(model.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(model.system, "22.9 W")
        XCTAssertEqual(model.battery, "+42.1 W")
        XCTAssertEqual(model.accessibilitySummary, "Charging, +42.1 W, 64% · full in about 38 min")
        XCTAssertFalse(model.showsComponents)
        XCTAssertFalse(model.componentsOff, "Hiding this section must not imply the helper is off")
        XCTAssertNil(model.panelHeight)
        XCTAssertTrue(model.usesIntrinsicPowerTableHeight)
        XCTAssertTrue(StatusPanelModel(reading: .sampleCharging).showsComponents)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).panelHeight, 473)
    }

    func testUnavailableCapabilitiesAndReadingsNeverFabricatePower() {
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            let reading = PowerReading(mode: .charging, watts: 42.1, batteryPercentage: 64,
                detail: "full in about 38 min", components: PowerReading.sampleCharging.components,
                batteryState: .charging,
                capabilities: .init(battery: capability, charger: capability,
                                    systemDraw: capability, components: capability),
                source: .fixture, chargerWatts: 65, systemWatts: 22.9)
            let model = StatusPanelModel(reading: reading,
                chargerDescription: "96 W USB-C charger", includesComponents: false)
            XCTAssertEqual([model.battery, model.charger, model.system], ["—", "—", "—"])
            XCTAssertEqual(model.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
            XCTAssertNil(model.chargerSubtitle)
            XCTAssertFalse(model.showsComponents)
        }
        for (source, freshness) in [(ReadingSource.unavailable, ReadingFreshness.fresh), (.fixture, .unavailable)] {
            let reading = PowerReading(mode: .charging, watts: 42.1, batteryPercentage: 64,
                batteryState: .charging, capabilities: PowerReading.sampleCharging.capabilities,
                freshness: freshness, source: source, chargerWatts: 65, systemWatts: 22.9)
            let model = StatusPanelModel(reading: reading,
                chargerDescription: "96 W USB-C charger", includesComponents: false)
            XCTAssertEqual(model.title, "No reading")
            XCTAssertEqual([model.battery, model.charger, model.system], ["—", "—", "—"])
            XCTAssertNil(model.chargerSubtitle)
            XCTAssertFalse(model.showsComponents)
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testNativeDarkHostGeometryAndFooterButtonCallbacks() throws {
        let preferences = J61FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleCharging,
            chargerDescription: "96 W USB-C charger", includesComponents: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 265),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: 308))
        XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        // SwiftUI hosts text separately and leaves the backing NSButton's title/AX ID empty.
        // The native footer places Settings on the left and Quit on the right.
        let buttons = nativeButtons(in: host).sorted {
            $0.convert($0.bounds, to: host).minX < $1.convert($1.bounds, to: host).minX
        }
        XCTAssertEqual(buttons.count, 2)
        let settings = try XCTUnwrap(buttons.first)
        let quit = try XCTUnwrap(buttons.last)
        XCTAssertFalse(settings === quit)
        XCTAssertFalse(settings.isBordered)
        XCTAssertFalse(quit.isBordered)
        settings.performClick(nil)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(quits, 0)
        quit.performClick(nil)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(quits, 1)
        XCTAssertEqual(preferences.onboarding, original)
        XCTAssertEqual(preferences.displayMode, .delta)
    }

    func testSelectedNativeStatusItemKeepsExactLabelAndDarkAqua() throws {
        let preferences = J61FixtureLaunch.makePreferences()
        let store = J61FixtureLaunch.makeStore()
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "+42.1 W")
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: J61FixtureLaunch.appearanceName)
        let router = AppRouter()
        let selection = C0410PanelSelection(button: button, router: router,
            preferences: preferences, store: store)
        selection.applySelection(isPresented: true)
        XCTAssertTrue(router.statusPanelPresented)
        XCTAssertTrue(button.isHighlighted)
        XCTAssertEqual(button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertNil(button.contentTintColor)
        selection.applySelection(isPresented: false)
        XCTAssertFalse(router.statusPanelPresented)
        XCTAssertFalse(button.isHighlighted)
    }
    #endif

    func testSharedPanelUsesNativeFormRowsAndBorderlessFooter() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"), encoding: .utf8)
        for token in ["Form {", ".formStyle(.grouped)", "LabeledContent", "if model.showsComponents",
                      "row(\"Charger input\"", "row(\"System draw\"", "row(\"Battery\"",
                      "Button(\"Settings…\", action: onSettings)", "Button(\"Quit Watt?\", action: onQuit)",
                      ".scrollDisabled(model.usesIntrinsicPowerTableHeight)",
                      ".fixedSize(horizontal: false, vertical: model.usesIntrinsicPowerTableHeight)",
                      ".buttonStyle(.borderless)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "Gradient", ".background(", ".shadow(", ".tint(", "Font.custom"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }

    private func nativeButtons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { nativeButtons(in: $0) }
    }
}

@MainActor
final class J61FixtureTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactBaseRegistryAndUnsupportedSelectorsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J6.1")
        XCTAssertEqual(fixture.story.node, "J6.1")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J6.1/base"]))
        XCTAssertEqual(try launch.smokeLaunchArguments(), ["--watt-fixture", "J6.1/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J61FixtureLaunch.requested)
        #else
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "J6.1/base"]))
        #endif
        for variant in ["dark", "light", "unavailable", "loading", "error", "unknown"] {
            let arguments = ["Watt", "--watt-fixture", "J6.1/" + variant]
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J6.1", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(arguments))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: arguments))
            XCTAssertFalse(J61FixtureLaunch.matches(arguments: arguments))
        }
        for arguments in [[], ["--watt-fixture"], ["--watt-fixture", "J6.2/base"],
                          ["--watt-fixture", "J6.1/base", "--watt-fixture", "C01/base"]] {
            XCTAssertFalse(J61FixtureLaunch.matches(arguments: arguments))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J61FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.1/base"]))
        #else
        XCTAssertTrue(J61FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.1/base"]))
        #endif
    }

    func testFixturePreferencesArePersistedInIndependentMemoryStores() {
        let storage = InMemoryStorage()
        let prepared = PreferencesStore(storage: storage)
        J61FixtureLaunch.prepare(preferences: prepared)
        let restored = PreferencesStore(storage: storage)
        XCTAssertTrue(restored.onboarding.completed)
        XCTAssertEqual(restored.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(restored.displayMode, .delta)
        XCTAssertEqual(restored.precision, .decimal)
        XCTAssertTrue(restored.showSymbol)
        XCTAssertFalse(restored.componentReadings)
        XCTAssertNil(restored.persistenceFailure)
        let first = J61FixtureLaunch.makePreferences()
        let second = J61FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        first.displayMode = .draw
        first.onboarding.completed = false
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        XCTAssertEqual(J61FixtureLaunch.appearanceName, .darkAqua)
    }

    func testFrozenStoresRemainIndependentAndDisconnectFailsClosed() {
        let first = J61FixtureLaunch.makeStore()
        let second = J61FixtureLaunch.makeStore()
        XCTAssertFalse(first === second)
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading, .sampleCharging)
        XCTAssertEqual(first.currentReading, second.currentReading)
        XCTAssertEqual(first.freshness(maximumAge: 0), .fresh)
        let generation = first.generation
        first.disconnect()
        XCTAssertEqual(first.failure, .disconnected)
        XCTAssertFalse(first.accept(.sampleCharging, generation: generation))
        let model = StatusPanelModel(reading: first.currentReading,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "No reading")
        XCTAssertEqual([model.charger, model.system, model.battery], ["—", "—", "—"])
        XCTAssertFalse(model.showsComponents)
        XCTAssertEqual(second.currentReading, .sampleCharging)
        XCTAssertNil(second.failure)
        XCTAssertEqual(second.freshness(maximumAge: 0), .fresh)
    }
    #endif
}
