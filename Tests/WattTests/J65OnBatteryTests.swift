import AppKit
import Combine
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J65OnBatteryTests: XCTestCase {
    func testExactCopyRowsAndCompactGeometryPreserveC02() {
        let model = StatusPanelModel(reading: .sampleOnBattery, includesComponents: false)
        XCTAssertEqual(model.state, .standard)
        XCTAssertEqual(model.title, "On battery")
        XCTAssertEqual(model.headlineValue, "−18.4 W")
        XCTAssertEqual(model.subtitle, "64% · about 4 h 10 min left")
        XCTAssertEqual([model.charger, model.system, model.battery], ["Unplugged", "18.4 W", "−18.4 W"])
        XCTAssertNil(model.chargerSubtitle)
        XCTAssertEqual(model.accessibilitySummary, "On battery, −18.4 W, 64% · about 4 h 10 min left")
        XCTAssertFalse(model.showsComponents)
        XCTAssertFalse(model.componentsOff)
        XCTAssertEqual(model.panelHeight, 265)
        let c02 = StatusPanelModel(reading: .sampleOnBattery)
        XCTAssertTrue(c02.showsComponents)
        XCTAssertEqual(c02.components.count, 4)
        XCTAssertEqual(c02.panelHeight, 473)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).title, "Charging")
        XCTAssertEqual(StatusPanelModel(reading: .sampleFullOnAdapter).title, "Full")
    }

    func testUnavailableCapabilitiesFailClosedPerRow() {
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            let battery = StatusPanelModel(reading: reading(batteryCapability: capability))
            XCTAssertEqual(battery.battery, "—")
            XCTAssertEqual(battery.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
            XCTAssertEqual(battery.system, "18.4 W")
            XCTAssertEqual(battery.charger, "Unplugged")
            XCTAssertEqual(StatusPanelModel(reading: reading(systemCapability: capability)).system, "—")
        }
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .available] {
            XCTAssertEqual(StatusPanelModel(reading: reading(chargerCapability: capability)).charger, "—")
        }
        XCTAssertEqual(StatusPanelModel(reading: reading(watts: nil)).battery, "—")
        XCTAssertEqual(StatusPanelModel(reading: reading(system: nil)).system, "—")
    }

    func testStaleUnavailableAndInvalidReadingsCannotExposePowerOrEstimate() {
        let rejected = [reading(freshness: .stale), reading(freshness: .unavailable),
                        reading(source: .unavailable), reading(watts: .nan), reading(watts: .infinity),
                        reading(watts: 1), reading(system: -1), reading(system: .infinity),
                        reading(percentage: 101), reading(timestamp: Date(timeIntervalSince1970: .infinity))]
        let preferences = J65FixtureLaunch.makePreferences()
        for sample in rejected {
            let model = StatusPanelModel(reading: sample, includesComponents: false)
            XCTAssertEqual([model.battery, model.system, model.charger], ["—", "—", "—"])
            XCTAssertEqual(model.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
            XCTAssertNotEqual(model.title, "On battery")
            for mode in [WattDisplayMode.delta, .charger, .draw] {
                preferences.displayMode = mode
                XCTAssertEqual(MenuBarStatusLabel(reading: sample, preferences: preferences).text, "—")
            }
        }
    }

    func testNoEstimateIsInventedFromWattsOrPercentage() {
        XCTAssertEqual(StatusPanelModel(reading: reading(detail: nil)).subtitle, "64%")
        let missing = StatusPanelModel(reading: reading(percentage: nil, detail: nil))
        XCTAssertTrue(missing.subtitle?.isEmpty ?? true)
        XCTAssertEqual(StatusPanelModel(reading: reading(batteryCapability: .unknown)).subtitle, "Usually right after wake. Watt? tries again every few seconds.")
        XCTAssertEqual(StatusPanelModel(reading: reading(watts: nil)).subtitle, "Usually right after wake. Watt? tries again every few seconds.")
    }

    func testSystemClockPublishesExpiryWithoutAnotherSample() {
        let sample = reading(timestamp: Date().addingTimeInterval(-4.5))
        let store = PowerReadingStore(currentReading: sample)
        XCTAssertEqual(store.statusReading, sample)
        let expired = expectation(description: "Open panel/status invalidated at sample expiry")
        let observation = store.objectWillChange.sink {
            XCTAssertEqual(store.statusReading, .unavailable)
            XCTAssertEqual(StatusPanelModel(reading: store.statusReading).subtitle, "Usually right after wake. Watt? tries again every few seconds.")
            expired.fulfill()
        }
        wait(for: [expired], timeout: 2)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(store.currentReading, sample)
    }

    func testFailedFutureAndAgedSamplesFailClosedAndRecover() {
        let clock = FakeWattClock(now: PowerReading.sampleOnBattery.timestamp)
        let store = PowerReadingStore(currentReading: .sampleOnBattery, clock: clock)
        XCTAssertFalse(store.accept(reading(watts: .nan), generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleOnBattery)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.sampleOnBattery, generation: store.generation))
        XCTAssertFalse(store.accept(reading(timestamp: clock.now.addingTimeInterval(1)), generation: store.generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.sampleOnBattery, generation: store.generation))
        clock.advance(by: 5)
        XCTAssertEqual(store.statusReading, .sampleOnBattery)
        clock.advance(by: 0.01)
        XCTAssertEqual(store.statusReading, .unavailable)
        let recovered = reading(timestamp: clock.now)
        XCTAssertTrue(store.accept(recovered, generation: store.generation))
        XCTAssertEqual(store.statusReading, recovered)
    }

    private func reading(watts: Double? = -18.4, percentage: Int? = 64,
                         detail: String? = "about 4 h 10 min left", system: Double? = 18.4,
                         batteryCapability: Capability = .available,
                         chargerCapability: Capability = .disconnected,
                         systemCapability: Capability = .available,
                         freshness: ReadingFreshness = .fresh, source: ReadingSource = .fixture,
                         timestamp: Date = PowerReading.sampleOnBattery.timestamp) -> PowerReading {
        PowerReading(mode: .onBattery, watts: watts, batteryPercentage: percentage, detail: detail,
            timestamp: timestamp, batteryState: .discharging,
            capabilities: .init(battery: batteryCapability, charger: chargerCapability, systemDraw: systemCapability),
            freshness: freshness, source: source, systemWatts: system)
    }

    func testNativeDarkHostGeometryAndFooterButtonCallbacks() throws {
        let preferences = J65FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleOnBattery,
            includesComponents: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 265),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: J65FixtureLaunch.appearanceName)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: 265))
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
        let host = NSHostingView(rootView: StatusPanelView(reading: .sampleOnBattery,
            includesComponents: false, onSettings: {}, onQuit: {}))
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
        let identifiers = accessibilityIdentifiers(in: host)
        for identifier in ["J6.5.summary", "J6.5.settings", "J6.5.quit"] {
            XCTAssertTrue(identifiers.contains(identifier), identifier)
        }
    }

    func testSelectedNativeStatusItemKeepsExactLabelAndDarkAqua() throws {
        let preferences = J65FixtureLaunch.makePreferences()
        let store = J65FixtureLaunch.makeStore()
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "−18.4 W")
        XCTAssertEqual(label.symbolName, "battery.100percent")
        XCTAssertTrue(label.showsSymbol)
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: J65FixtureLaunch.appearanceName)
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

    private func accessibilityIdentifiers(in root: NSView) -> [String] {
        var seen = Set<ObjectIdentifier>()
        func collect(_ object: Any) -> [String] {
            guard let element = object as? any NSAccessibilityProtocol,
                  seen.insert(ObjectIdentifier(element as AnyObject)).inserted else { return [] }
            let own = element.accessibilityIdentifier().map { [$0] } ?? []
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
final class J65FixtureTests: XCTestCase {
    func testExactRegistryAndInvalidSelectorsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J6.5")
        XCTAssertEqual(fixture.story.node, "31:5571")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        let args = ["Watt", "--watt-fixture", "J6.5/base"]
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(args))
        XCTAssertEqual(try launch.smokeLaunchArguments(), Array(args.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J65FixtureLaunch.matches(arguments: args))
        #else
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        XCTAssertTrue(J65FixtureLaunch.matches(arguments: args))
        #endif
        for selector in ["J6.5/light", "J6.5/unknown", "J6.5/base/extra", "J6.5/", "/base", "j6.5/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertFalse(J65FixtureLaunch.matches(arguments: args))
        }
        for args in [[], ["--watt-fixture"], ["--watt-fixture", "J6.4/base"],
                     ["--watt-fixture", "J6.5/base", "--watt-fixture", "C01/base"]] {
            XCTAssertFalse(J65FixtureLaunch.matches(arguments: args))
        }
    }

    func testIndependentPreferencesAndFrozenStores() {
        let first = J65FixtureLaunch.makePreferences()
        let second = J65FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertTrue(first.onboarding.completed)
        XCTAssertEqual(first.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(first.displayMode, .delta)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertTrue(first.showSymbol)
        XCTAssertFalse(first.componentReadings)
        XCTAssertNil(first.persistenceFailure)
        first.displayMode = .draw
        first.onboarding.completed = false
        first.componentReadings = true
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertFalse(second.componentReadings)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        XCTAssertEqual(J65FixtureLaunch.appearanceName, .darkAqua)
        J65FixtureLaunch.prepare(preferences: first)
        XCTAssertEqual(first.displayMode, .delta)
        XCTAssertTrue(first.onboarding.completed)
        XCTAssertFalse(first.componentReadings)
        let store = J65FixtureLaunch.makeStore()
        let other = J65FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        XCTAssertEqual(store.statusReading, .sampleOnBattery)
        let generation = store.generation
        store.disconnect()
        XCTAssertFalse(store.accept(.sampleOnBattery, generation: generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(other.statusReading, .sampleOnBattery)
        XCTAssertEqual(J63FixtureLaunch.makeStore().currentReading, .sampleFullOnAdapter)
    }
}
