import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J63FullOnAdapterTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFullCopyAndPowerRowsWithoutComponents() {
        let model = StatusPanelModel(reading: .sampleFullOnAdapter,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "Full")
        XCTAssertEqual(model.headlineValue, "19.8 W")
        XCTAssertEqual(model.subtitle, "100% · running straight off the charger")
        XCTAssertEqual(model.charger, "19.8 W")
        XCTAssertEqual(model.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(model.system, "19.8 W")
        XCTAssertEqual(model.battery, "0.0 W")
        XCTAssertEqual(model.accessibilitySummary, "Full, 19.8 W, 100% · running straight off the charger")
        XCTAssertFalse(model.showsComponents)
        XCTAssertFalse(model.componentsOff, "Hiding this section must not imply the helper is off")
        XCTAssertNil(model.panelHeight)
        XCTAssertTrue(model.usesIntrinsicPowerTableHeight)
        XCTAssertFalse(StatusPanelModel(reading: .sampleFullOnAdapter).showsComponents)
        XCTAssertNil(StatusPanelModel(reading: .sampleFullOnAdapter).panelHeight)
    }

    func testFullRequiresExplicitStateAndValidatedFreshAvailableTelemetry() {
        let rejected: [PowerReading] = [
            full(state: .charging), full(state: .chargingHold), full(state: .discharging),
            full(state: .unknown), full(state: .noBattery),
            full(source: .unavailable), full(freshness: .unavailable), full(freshness: .stale),
            full(watts: nil), full(watts: 0.01), full(watts: -0.01), full(watts: .nan),
            full(percentage: nil), full(percentage: 99), full(percentage: -1), full(percentage: 101),
            full(charger: nil), full(charger: -1), full(charger: .infinity),
            full(system: nil), full(system: -1), full(system: .nan),
            full(timestamp: Date(timeIntervalSince1970: .infinity)),
            full(components: [PowerComponent(id: "cpu", name: "CPU", watts: -1)]),
            full(components: [PowerComponent(id: "cpu", name: "CPU", watts: 1),
                              PowerComponent(id: "cpu", name: "CPU", watts: 2)])
        ]
        let expected: [StatusPanelState] = [.standard, .standard, .standard, .standard, .noReading, .noReading, .noReading, .noReading, .noReading, .standard, .standard, .noReading, .standard, .standard, .noReading, .noReading, .standard, .noReading, .noReading, .standard, .noReading, .noReading, .noReading, .noReading, .noReading]
        XCTAssertEqual(rejected.count, expected.count)
        for (reading, expectedState) in zip(rejected, expected) {
            let model = StatusPanelModel(reading: reading)
            XCTAssertEqual(model.state, expectedState)
            XCTAssertFalse(model.hasFullOnAdapter)
            XCTAssertNotEqual(model.title, "Full")
            XCTAssertNotEqual(model.subtitle, Self.explanation)
        }
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            for (reading, expectedState) in [(full(batteryCapability: capability), StatusPanelState.noReading),
                                             (full(chargerCapability: capability), .standard),
                                             (full(systemCapability: capability), .standard)] {
                XCTAssertEqual(StatusPanelModel(reading: reading).state, expectedState)
            }
        }
        for source in [ReadingSource.fixture, .system, .helper] {
            XCTAssertEqual(StatusPanelModel(reading: full(source: source)).state, .fullOnAdapter)
        }
        XCTAssertEqual(StatusPanelModel(reading: full(watts: -0.0)).state, .fullOnAdapter)
        XCTAssertEqual(StatusPanelModel(reading: .sampleFullOnAdapter).state, .fullOnAdapter)
    }

    func testLegacyFullAndChargingHoldSemanticsArePreserved() {
        let legacy = StatusPanelModel(reading: .sampleChargedOnAdapter)
        XCTAssertEqual(legacy.state, .standard)
        XCTAssertEqual(legacy.title, "Fully Charged")
        XCTAssertEqual(legacy.subtitle, "100%")
        XCTAssertEqual(legacy.headlineValue, "0.0 W")
        XCTAssertTrue(legacy.showsComponents)
        XCTAssertNil(legacy.panelHeight)
        let hold = StatusPanelModel(reading: .sampleChargingHold)
        XCTAssertEqual(hold.state, .optimisedChargingHold(percentage: 80))
        XCTAssertEqual(hold.title, "Holding at 80%")
        XCTAssertNil(hold.panelHeight)
        XCTAssertFalse(hold.showsComponents)
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

    private static let explanation = "100% · running straight off the charger"

    #if DEBUG || SWIFT_PACKAGE
    private func full(watts: Double? = 0, percentage: Int? = 100,
                      state: BatteryState = .full,
                      batteryCapability: Capability = .available,
                      chargerCapability: Capability = .available,
                      systemCapability: Capability = .available,
                      source: ReadingSource = .fixture, freshness: ReadingFreshness = .fresh,
                      charger: Double? = 19.8, system: Double? = 19.8,
                      timestamp: Date = PowerReading.sampleFullOnAdapter.timestamp,
                      components: [PowerComponent] = []) -> PowerReading {
        PowerReading(mode: .charged, watts: watts, batteryPercentage: percentage,
            components: components, timestamp: timestamp, batteryState: state,
            capabilities: .init(battery: batteryCapability, charger: chargerCapability,
                                systemDraw: systemCapability),
            freshness: freshness, source: source, chargerWatts: charger, systemWatts: system)
    }

    func testNativeDarkHostGeometryAndFooterButtonCallbacks() throws {
        let preferences = J63FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleFullOnAdapter,
            chargerDescription: "96 W USB-C charger", includesComponents: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 265),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: J63FixtureLaunch.appearanceName)
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

    func testNativeAccessibilityExposesThreePowerRowsWithoutComponents() throws {
        let host = NSHostingView(rootView: StatusPanelView(reading: .sampleFullOnAdapter,
            chargerDescription: "96 W USB-C charger", onSettings: {}, onQuit: {}))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 265),
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
        let preferences = J63FixtureLaunch.makePreferences()
        let store = J63FixtureLaunch.makeStore()
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "0.0 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertTrue(label.showsSymbol)
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: J63FixtureLaunch.appearanceName)
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
final class J63FixtureTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactBaseRegistryAndUnsupportedSelectorsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J6.3")
        XCTAssertEqual(fixture.story.id, "J6.3")
        XCTAssertEqual(fixture.story.node, "J6.3")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J6.3/base"]))
        XCTAssertEqual(try launch.smokeLaunchArguments(), ["--watt-fixture", "J6.3/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J63FixtureLaunch.requested)
        #else
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "J6.3/base"]))
        #endif
        for variant in ["dark", "light", "unavailable", "loading", "error", "unknown",
                        "notification-on-authorized", "notification-on-denied",
                        "notification-off-authorized", "notification-off-denied"] {
            let arguments = ["Watt", "--watt-fixture", "J6.3/" + variant]
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J6.3", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(arguments))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: arguments))
            XCTAssertFalse(J63FixtureLaunch.matches(arguments: arguments))
        }
        #if !SWIFT_PACKAGE
        let constructed = FixtureSelection(story: fixture.story, variant: "unsupported")
        XCTAssertThrowsError(try FixtureLaunchSelection.story(constructed).smokeLaunchArguments())
        #endif
        for arguments in [[], ["--watt-fixture"], ["--watt-fixture", "J6.1/base"],
                          ["--watt-fixture", "J6.2/base"], ["--watt-fixture", "J6.3/base/extra"],
                          ["--watt-fixture", "J6.3/"], ["--watt-fixture", "/base"],
                          ["--watt-fixture", "J6.3/base", "--watt-fixture", "C01/base"]] {
            XCTAssertFalse(J63FixtureLaunch.matches(arguments: arguments))
        }
        for selector in ["J6.3/base/extra", "J6.3/", "/base", "j6.3/base"] {
            let arguments = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(arguments))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: arguments))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J63FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.3/base"]))
        #else
        XCTAssertTrue(J63FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J6.3/base"]))
        #endif
    }

    func testFixturePreferencesArePersistedInIndependentMemoryStores() {
        let storage = InMemoryStorage()
        let prepared = PreferencesStore(storage: storage)
        J63FixtureLaunch.prepare(preferences: prepared)
        let restored = PreferencesStore(storage: storage)
        XCTAssertTrue(restored.onboarding.completed)
        XCTAssertEqual(restored.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(restored.displayMode, .delta)
        XCTAssertEqual(restored.precision, .decimal)
        XCTAssertTrue(restored.showSymbol)
        XCTAssertFalse(restored.componentReadings)
        XCTAssertNil(restored.persistenceFailure)
        let first = J63FixtureLaunch.makePreferences()
        let second = J63FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        first.displayMode = .draw
        first.onboarding.completed = false
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        let holding = J62FixtureLaunch.makePreferences()
        XCTAssertEqual(holding.displayMode, .delta)
        XCTAssertTrue(holding.onboarding.completed)
        let charging = J61FixtureLaunch.makePreferences()
        XCTAssertFalse(charging === first)
        XCTAssertEqual(charging.displayMode, .delta)
        XCTAssertTrue(charging.onboarding.completed)
        XCTAssertEqual(J63FixtureLaunch.appearanceName, .darkAqua)
    }
    #endif

    func testInvalidStoreInitializationDoesNotFabricateFull() {
        let invalid = PowerReading(mode: .charged, watts: .nan, batteryPercentage: 100,
            batteryState: .full, source: .fixture)
        let store = PowerReadingStore(currentReading: invalid)
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.currentReading).state, .noReading)
        XCTAssertEqual(StatusPanelModel(reading: store.currentReading).title, "No reading")
    }

    #if DEBUG || SWIFT_PACKAGE
    func testRejectedSampleSuppressesFullUntilValidRecovery() {
        let store = J63FixtureLaunch.makeStore()
        let invalid = PowerReading(mode: .charged, watts: .nan, batteryPercentage: 100,
            timestamp: PowerReading.sampleFullOnAdapter.timestamp,
            batteryState: .full, source: .fixture)
        XCTAssertFalse(store.accept(invalid, generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleFullOnAdapter, "Retain last sample for diagnostics")
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).title, "No reading")
        XCTAssertNotEqual(MenuBarStatusLabel(reading: store.statusReading,
            preferences: J63FixtureLaunch.makePreferences()).text, "0.0 W")
        XCTAssertTrue(store.accept(.sampleFullOnAdapter, generation: store.generation))
        XCTAssertNil(store.failure)
        XCTAssertEqual(store.statusReading, .sampleFullOnAdapter)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state,
                       .fullOnAdapter)
    }

    func testFutureSampleSuppressesFullUntilValidRecovery() {
        let store = J63FixtureLaunch.makeStore()
        let future = PowerReading(mode: .charged, watts: 0, batteryPercentage: 100,
            timestamp: PowerReading.sampleFullOnAdapter.timestamp.addingTimeInterval(1),
            batteryState: .full, capabilities: PowerReading.sampleFullOnAdapter.capabilities,
            source: .fixture, chargerWatts: 19.8, systemWatts: 19.8)
        XCTAssertFalse(store.accept(future, generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleFullOnAdapter)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertTrue(store.accept(.sampleFullOnAdapter, generation: store.generation))
        XCTAssertNil(store.failure)
        XCTAssertEqual(store.statusReading, .sampleFullOnAdapter)
    }

    func testFullStatusExpiresAndRecoversUsingTheStoreClock() {
        let clock = FakeWattClock(now: PowerReading.sampleFullOnAdapter.timestamp)
        let store = PowerReadingStore(currentReading: .sampleFullOnAdapter, clock: clock)
        clock.advance(by: PowerReadingStore.fullStatusMaximumAge)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .fullOnAdapter)
        clock.advance(by: 0.01)
        XCTAssertEqual(store.currentReading, .sampleFullOnAdapter, "Retain aged sample for diagnostics")
        XCTAssertNil(store.failure)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertNotEqual(MenuBarStatusLabel(reading: store.statusReading,
            preferences: J63FixtureLaunch.makePreferences()).text, "0.0 W")
        let recovered = PowerReading(mode: .charged, watts: 0, batteryPercentage: 100,
            timestamp: clock.now, batteryState: .full,
            capabilities: PowerReading.sampleFullOnAdapter.capabilities,
            source: .system, chargerWatts: 19.8, systemWatts: 19.8)
        XCTAssertTrue(store.accept(recovered, generation: store.generation))
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .fullOnAdapter)
    }

    func testFrozenStoresRemainIndependentAndDisconnectFailsClosed() {
        let first = J63FixtureLaunch.makeStore()
        let second = J63FixtureLaunch.makeStore()
        let holding = J62FixtureLaunch.makeStore()
        XCTAssertFalse(first === holding)
        XCTAssertEqual(holding.currentReading, .sampleChargingHold)
        let charging = J61FixtureLaunch.makeStore()
        let legacy = PowerReadingStore.preview
        XCTAssertFalse(first === second)
        XCTAssertFalse(first === charging)
        XCTAssertFalse(first === legacy)
        XCTAssertEqual(charging.currentReading, .sampleCharging)
        XCTAssertEqual(legacy.currentReading, .sampleCharging)
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading, .sampleFullOnAdapter)
        XCTAssertEqual(first.currentReading, second.currentReading)
        XCTAssertEqual(first.freshness(maximumAge: 0), .fresh)
        let generation = first.generation
        first.disconnect()
        XCTAssertEqual(first.failure, .disconnected)
        XCTAssertFalse(first.accept(.sampleFullOnAdapter, generation: generation))
        let model = StatusPanelModel(reading: first.currentReading,
            chargerDescription: "96 W USB-C charger", includesComponents: false)
        XCTAssertEqual(model.title, "No reading")
        XCTAssertEqual([model.charger, model.system, model.battery], ["—", "—", "—"])
        XCTAssertFalse(model.showsComponents)
        XCTAssertEqual(second.currentReading, .sampleFullOnAdapter)
        XCTAssertNil(second.failure)
        XCTAssertEqual(second.freshness(maximumAge: 0), .fresh)
    }
    #endif
}
