import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J62ChargingHoldTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactChargingCopyAndPowerRowsWithoutComponents() {
        let model = StatusPanelModel(reading: .sampleChargingHold,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "Holding at 80%")
        XCTAssertEqual(model.headlineValue, "0.0 W")
        XCTAssertEqual(model.subtitle, "Because Optimised Battery Charging is on. Charging resumes before you usually unplug.")
        XCTAssertEqual(model.charger, "21.4 W")
        XCTAssertEqual(model.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(model.system, "21.4 W")
        XCTAssertEqual(model.battery, "0.0 W")
        XCTAssertEqual(model.accessibilitySummary, "Holding at 80%, 0.0 W, Because Optimised Battery Charging is on. Charging resumes before you usually unplug.")
        XCTAssertFalse(model.showsComponents)
        XCTAssertFalse(model.componentsOff, "Hiding this section must not imply the helper is off")
        XCTAssertNil(model.panelHeight)
        XCTAssertTrue(model.usesIntrinsicPowerTableHeight)
        XCTAssertFalse(StatusPanelModel(reading: .sampleChargingHold).showsComponents)
        XCTAssertNil(StatusPanelModel(reading: .sampleChargingHold).panelHeight)
    }

    func testHoldRequiresExplicitReasonAndValidatedFreshAdapterReadings() {
        let rejected: [PowerReading] = [
            hold(reason: nil), hold(state: .charging), hold(state: .full),
            hold(source: .unavailable), hold(freshness: .unavailable), hold(freshness: .stale),
            hold(watts: nil), hold(watts: 0.1), hold(watts: -0.1), hold(watts: .nan),
            hold(percentage: nil), hold(percentage: -1), hold(percentage: 101),
            hold(charger: nil), hold(charger: -1), hold(charger: .infinity),
            hold(system: nil), hold(system: -1), hold(system: .nan)
        ]
        let expected: [StatusPanelState] = [.standard, .standard, .standard, .noReading, .noReading, .noReading, .noReading, .standard, .standard, .noReading, .standard, .noReading, .noReading, .standard, .noReading, .noReading, .standard, .noReading, .noReading]
        XCTAssertEqual(rejected.count, expected.count)
        for (reading, expectedState) in zip(rejected, expected) {
            let model = StatusPanelModel(reading: reading)
            XCTAssertEqual(model.state, expectedState)
            XCTAssertFalse(model.title.hasPrefix("Holding at"))
            XCTAssertNotEqual(model.subtitle, Self.explanation)
        }
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            for (reading, expectedState) in [(hold(batteryCapability: capability), StatusPanelState.noReading),
                                             (hold(chargerCapability: capability), .standard),
                                             (hold(systemCapability: capability), .standard)] {
                XCTAssertEqual(StatusPanelModel(reading: reading).state, expectedState)
            }
        }
        XCTAssertEqual(StatusPanelModel(reading: hold(reason: nil)).title, "Charging Paused")
        XCTAssertEqual(StatusPanelModel(reading: hold(percentage: 75)).title, "Holding at 75%")
        XCTAssertEqual(StatusPanelModel(reading: .sampleChargingHold).state,
                       .optimisedChargingHold(percentage: 80))
    }
    #endif

    func testExistingChargingPanelSemanticsArePreserved() {
        let ordinary = StatusPanelModel(reading: .sampleCharging)
        let compact = StatusPanelModel(reading: .sampleCharging, includesComponents: false)
        XCTAssertEqual(ordinary.state, .standard)
        XCTAssertEqual(ordinary.title, "Charging")
        XCTAssertEqual(ordinary.headlineValue, "+42.1 W")
        XCTAssertEqual(ordinary.subtitle, "64% · full in about 38 min")
        XCTAssertTrue(ordinary.showsComponents)
        XCTAssertEqual(ordinary.panelHeight, 473)
        XCTAssertFalse(compact.showsComponents)
        XCTAssertNil(compact.panelHeight)
        XCTAssertTrue(compact.usesIntrinsicPowerTableHeight)
    }

    private static let explanation = "Because Optimised Battery Charging is on. Charging resumes before you usually unplug."

    #if DEBUG || SWIFT_PACKAGE
    private func hold(watts: Double? = 0, percentage: Int? = 80,
                      state: BatteryState = .chargingHold,
                      batteryCapability: Capability = .available,
                      chargerCapability: Capability = .available,
                      systemCapability: Capability = .available,
                      source: ReadingSource = .fixture, freshness: ReadingFreshness = .fresh,
                      charger: Double? = 21.4, system: Double? = 21.4,
                      reason: BatteryChargingHoldReason? = .optimisedBatteryCharging) -> PowerReading {
        PowerReading(mode: .charged, watts: watts, batteryPercentage: percentage,
            timestamp: PowerReading.sampleChargingHold.timestamp, batteryState: state,
            capabilities: .init(battery: batteryCapability, charger: chargerCapability,
                                systemDraw: systemCapability),
            freshness: freshness, source: source, chargerWatts: charger, systemWatts: system,
            chargingHoldReason: reason)
    }

    func testNativeDarkHostGeometryAndFooterButtonCallbacks() throws {
        let preferences = J62FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleChargingHold,
            chargerDescription: "96 W USB-C charger", includesComponents: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 279),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: J62FixtureLaunch.appearanceName)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: 322))
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

    func testNativeAccessibilityExposesThreePowerRowsWithoutComponents() throws {
        let host = NSHostingView(rootView: StatusPanelView(reading: .sampleChargingHold,
            chargerDescription: "96 W USB-C charger", onSettings: {}, onQuit: {}))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 279),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let labels = accessibilityLabels(in: host).filter { !$0.isEmpty }
        try XCTSkipIf(labels.isEmpty,
            "Native SwiftUI host exposes no AX labels in this test process; row AX validation remains blocked. No AX or visual pass is claimed.")
        for row in ["Charger input", "System draw", "Battery"] {
            XCTAssertEqual(labels.filter { $0 == row }.count, 1, row)
        }
        XCTAssertFalse(labels.contains("Components"))
    }

    func testSelectedNativeStatusItemKeepsExactLabelAndDarkAqua() throws {
        let preferences = J62FixtureLaunch.makePreferences()
        let store = J62FixtureLaunch.makeStore()
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "0.0 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertTrue(label.showsSymbol)
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: J62FixtureLaunch.appearanceName)
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
                      ".buttonStyle(.borderless)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "Gradient", ".background(", ".shadow(", ".tint(", "Font.custom"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }

    private func accessibilityLabels(in root: NSView) -> [String] {
        var seen = Set<ObjectIdentifier>()
        func collect(_ object: Any) -> [String] {
            guard let element = object as? any NSAccessibilityProtocol,
                  seen.insert(ObjectIdentifier(element as AnyObject)).inserted else { return [] }
            let own = element.accessibilityLabel().map { [$0] } ?? []
            return own + (element.accessibilityChildren() ?? []).flatMap(collect)
                + ((object as? NSView)?.subviews ?? []).flatMap(collect)
        }
        return collect(root)
    }

    private func nativeButtons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { nativeButtons(in: $0) }
    }
}

@MainActor
final class J62FixtureTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactBaseRegistryAndUnsupportedSelectorsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J6.2")
        XCTAssertEqual(fixture.story.node, "31:3754")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J6.2/base"]))
        XCTAssertEqual(try launch.smokeLaunchArguments(), ["--watt-fixture", "J6.2/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J62FixtureLaunch.requested)
        #else
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "J6.2/base"]))
        #endif
        for variant in ["dark", "light", "unavailable", "loading", "error", "unknown"] {
            let arguments = ["Watt", "--watt-fixture", "J6.2/" + variant]
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J6.2", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(arguments))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: arguments))
            XCTAssertFalse(J62FixtureLaunch.matches(arguments: arguments))
        }
        #if !SWIFT_PACKAGE
        let constructed = FixtureSelection(story: fixture.story, variant: "unsupported")
        XCTAssertThrowsError(try FixtureLaunchSelection.story(constructed).smokeLaunchArguments())
        #endif
        for arguments in [[], ["--watt-fixture"], ["--watt-fixture", "J6.1/base"],
                          ["--watt-fixture", "J6.2/base", "--watt-fixture", "C01/base"]] {
            XCTAssertFalse(J62FixtureLaunch.matches(arguments: arguments))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J62FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.2/base"]))
        #else
        XCTAssertTrue(J62FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.2/base"]))
        #endif
    }

    func testFixturePreferencesArePersistedInIndependentMemoryStores() {
        let storage = InMemoryStorage()
        let prepared = PreferencesStore(storage: storage)
        J62FixtureLaunch.prepare(preferences: prepared)
        let restored = PreferencesStore(storage: storage)
        XCTAssertTrue(restored.onboarding.completed)
        XCTAssertEqual(restored.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(restored.displayMode, .delta)
        XCTAssertEqual(restored.precision, .decimal)
        XCTAssertTrue(restored.showSymbol)
        XCTAssertFalse(restored.componentReadings)
        XCTAssertNil(restored.persistenceFailure)
        let first = J62FixtureLaunch.makePreferences()
        let second = J62FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        first.displayMode = .draw
        first.onboarding.completed = false
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        let charging = J61FixtureLaunch.makePreferences()
        XCTAssertFalse(charging === first)
        XCTAssertEqual(charging.displayMode, .delta)
        XCTAssertTrue(charging.onboarding.completed)
        XCTAssertEqual(J62FixtureLaunch.appearanceName, .darkAqua)
    }
    #endif

    func testInvalidStoreInitializationDoesNotFabricateAHold() {
        let invalid = PowerReading(mode: .charged, watts: .nan, batteryPercentage: 80,
            batteryState: .chargingHold, source: .fixture,
            chargingHoldReason: .optimisedBatteryCharging)
        let store = PowerReadingStore(currentReading: invalid)
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.currentReading).state, .noReading)
        XCTAssertEqual(StatusPanelModel(reading: store.currentReading).title, "No reading")
    }

    #if DEBUG || SWIFT_PACKAGE
    func testRejectedSampleSuppressesHoldUntilValidRecovery() {
        let store = J62FixtureLaunch.makeStore()
        let invalid = PowerReading(mode: .charged, watts: .nan, batteryPercentage: 80,
            timestamp: PowerReading.sampleChargingHold.timestamp,
            batteryState: .chargingHold, source: .fixture,
            chargingHoldReason: .optimisedBatteryCharging)
        XCTAssertFalse(store.accept(invalid, generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleChargingHold, "Retain last sample for diagnostics")
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).title, "No reading")
        XCTAssertNotEqual(MenuBarStatusLabel(reading: store.statusReading,
            preferences: J62FixtureLaunch.makePreferences()).text, "0.0 W")
        XCTAssertTrue(store.accept(.sampleChargingHold, generation: store.generation))
        XCTAssertNil(store.failure)
        XCTAssertEqual(store.statusReading, .sampleChargingHold)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state,
                       .optimisedChargingHold(percentage: 80))
    }

    func testFutureSampleSuppressesHoldUntilValidRecovery() {
        let store = J62FixtureLaunch.makeStore()
        let future = PowerReading(mode: .charged, watts: 0, batteryPercentage: 80,
            timestamp: PowerReading.sampleChargingHold.timestamp.addingTimeInterval(1),
            batteryState: .chargingHold, capabilities: PowerReading.sampleChargingHold.capabilities,
            source: .fixture, chargerWatts: 21.4, systemWatts: 21.4,
            chargingHoldReason: .optimisedBatteryCharging)
        XCTAssertFalse(store.accept(future, generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleChargingHold)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertTrue(store.accept(.sampleChargingHold, generation: store.generation))
        XCTAssertNil(store.failure)
        XCTAssertEqual(store.statusReading, .sampleChargingHold)
    }

    func testFrozenStoresRemainIndependentAndDisconnectFailsClosed() {
        let first = J62FixtureLaunch.makeStore()
        let second = J62FixtureLaunch.makeStore()
        let charging = J61FixtureLaunch.makeStore()
        let legacy = PowerReadingStore.preview
        XCTAssertFalse(first === second)
        XCTAssertFalse(first === charging)
        XCTAssertFalse(first === legacy)
        XCTAssertEqual(charging.currentReading, .sampleCharging)
        XCTAssertEqual(legacy.currentReading, .sampleCharging)
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading, .sampleChargingHold)
        XCTAssertEqual(first.currentReading, second.currentReading)
        XCTAssertEqual(first.freshness(maximumAge: 0), .fresh)
        let generation = first.generation
        first.disconnect()
        XCTAssertEqual(first.failure, .disconnected)
        XCTAssertFalse(first.accept(.sampleChargingHold, generation: generation))
        let model = StatusPanelModel(reading: first.currentReading,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "No reading")
        XCTAssertEqual([model.charger, model.system, model.battery], ["—", "—", "—"])
        XCTAssertFalse(model.showsComponents)
        XCTAssertEqual(second.currentReading, .sampleChargingHold)
        XCTAssertNil(second.failure)
        XCTAssertEqual(second.freshness(maximumAge: 0), .fresh)
    }
    #endif
}
