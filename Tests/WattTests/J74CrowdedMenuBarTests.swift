import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J74CrowdedMenuBarTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactSelectorAndRegistry() throws {
        let fixture = try ScenarioRegistry.resolve("J7.4")
        XCTAssertEqual(fixture.story.node, "31:7764")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        let arguments = ["Watt", "--watt-fixture", "J7.4/base"]
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(arguments))
        XCTAssertEqual(try selection.smokeLaunchArguments(), Array(arguments.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J74FixtureLaunch.matches(arguments: arguments))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: arguments))
        #else
        XCTAssertTrue(J74FixtureLaunch.matches(arguments: arguments))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: arguments))
        #endif
        for selector in ["J7.4", "J7.4/light", "J7.4/dark", "J7.4/unknown", "J7.4/", "J7.4//base", "J7.4/base/extra", "j7.4/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J74FixtureLaunch.matches(arguments: invalid))
        }
        for invalid in [["Watt", "--watt-fixture"], ["Watt", "--watt-fixture=J7.4/base"],
                        arguments + ["--watt-fixture", "J7.4/base"]] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J74FixtureLaunch.matches(arguments: invalid))
        }
        for args in [[], ["Watt"], ["Watt", "--watt-fixture", "J7.1/base"],
                     ["Watt", "--watt-fixture", "J7.2/base"], ["Watt", "--watt-fixture", "J7.3/base"]] {
            XCTAssertFalse(J74FixtureLaunch.matches(arguments: args))
        }
    }

    func testIconOnlyHidesTextButKeepsSymbolAndAccessibleReading() throws {
        let preferences = J74FixtureLaunch.makePreferences()
        let label = MenuBarStatusLabel(reading: J74FixtureLaunch.makeStore().statusReading, preferences: preferences)
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
        preferences.showSymbol = false
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol, "Icon Only remains a discoverable native control")
        preferences.precision = .whole
        XCTAssertEqual(label.accessibilityReading, "+42 watts")
        let image = try XCTUnwrap(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: "Watt? power reading"))
        XCTAssertTrue(image.isTemplate, "The native SF Symbol supports system tint and contrast")
    }
    #endif

    func testProductionSystemAndHelperSamplesUseSameIconSemantics() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .iconOnly
        for source in [ReadingSource.system, .helper, .fixture] {
            let label = MenuBarStatusLabel(reading: reading(source: source), preferences: preferences)
            XCTAssertNil(label.text)
            XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
            XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testInvalidStaleUnavailableAndUnsupportedReadingsDoNotClaimPower() {
        let preferences = J74FixtureLaunch.makePreferences()
        let invalid = [PowerReading.unavailable, reading(source: .unavailable), reading(freshness: .stale),
                       reading(freshness: .unavailable), reading(watts: .nan), reading(watts: .infinity),
                       reading(watts: -1), reading(battery: .unsupported), reading(battery: .unknown),
                       reading(battery: .permissionRequired), reading(battery: .disconnected)]
        for sample in invalid {
            let label = MenuBarStatusLabel(reading: sample, preferences: preferences)
            XCTAssertNil(label.text)
            XCTAssertTrue(label.showsSymbol)
            XCTAssertEqual(label.symbolName, "bolt.fill")
            XCTAssertEqual(label.accessibilityReading, "No reading yet")
        }
        let missing = MenuBarStatusLabel(reading: reading(watts: nil), preferences: preferences)
        XCTAssertNil(missing.text)
        XCTAssertEqual(missing.accessibilityReading, "No reading yet")
        let disconnected = MenuBarStatusLabel(reading: reading(charger: .disconnected), preferences: preferences)
        XCTAssertEqual(disconnected.symbolName, "bolt.fill")
    }

    func testIconTracksPhysicalBatteryStateWithoutChangingPreference() {
        let preferences = J74FixtureLaunch.makePreferences()
        for (sample, symbol, value) in [(PowerReading.sampleOnBattery, "battery.100percent", "−18.4 watts"),
                                        (.sampleChargingHold, "battery.100percent.bolt", "0.0 watts"),
                                        (.sampleFullOnAdapter, "battery.100percent.bolt", "0.0 watts")] {
            let label = MenuBarStatusLabel(reading: sample, preferences: preferences)
            XCTAssertNil(label.text)
            XCTAssertEqual(label.symbolName, symbol)
            XCTAssertEqual(label.accessibilityReading, value)
            XCTAssertEqual(preferences.displayMode, .iconOnly)
        }
    }
    #endif

    func testJ71IconActionPersistsPreferenceAndKeepsNativeMenuRouting() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .livePanel, completed: true, helperOptIn: true)
        let router = AppRouter()
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
        let modes = try XCTUnwrap(menu.items.first?.submenu)
        XCTAssertEqual(modes.items.map(\.title), ["Delta", "Charger", "Draw", "Components", "", "Icon"])
        modes.performActionForItem(at: 5)
        XCTAssertEqual(preferences.displayMode, .iconOnly)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .iconOnly)
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences)
        XCTAssertNil(label.text)
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        let rebuilt = StatusItemContextMenu.makeMenu(router: router, preferences: preferences, componentsAvailable: { true })
        XCTAssertEqual(rebuilt.items.first?.submenu?.items.filter { $0.state == .on }.map(\.title), ["Icon"])
        for item in modes.items { XCTAssertNil(item.view) }
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let open = try XCTUnwrap(rebuilt.items.firstIndex { $0.title == "Open Watt?" })
        rebuilt.performActionForItem(at: open)
        XCTAssertEqual(routes, [.statusPanel])
        XCTAssertEqual(preferences.displayMode, .iconOnly)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testReturningFromIconPreservesJ72ComponentLabelAndJ71Delta() {
        let preferences = J72FixtureLaunch.makePreferences()
        let label = MenuBarStatusLabel(reading: .samplePerComponent, preferences: preferences)
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol)
        preferences.displayMode = .components
        XCTAssertEqual(label.text, "CPU 9.8 · GPU 4.1 W")
        XCTAssertEqual(label.accessibilityReading, "CPU 9.8 · GPU 4.1 watts")
        XCTAssertFalse(label.showsSymbol)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        let delta = MenuBarStatusLabel(reading: .sampleCharging, preferences: J71FixtureLaunch.makePreferences())
        XCTAssertEqual(delta.text, "+42.1 W")
        XCTAssertEqual(delta.symbolName, "battery.100percent.bolt")
    }

    func testHelperLossPreservesExistingEffectiveDeltaFallback() {
        let preferences = J74FixtureLaunch.makePreferences()
        let label = MenuBarStatusLabel(reading: .sampleOnBattery, preferences: preferences, helperSwitchedOff: true)
        XCTAssertEqual(label.text, "−18.4 W")
        XCTAssertEqual(preferences.displayMode, .iconOnly)
    }

    func testFixturePreferencesAndStoresAreFreshAndFrozen() async {
        let first = J74FixtureLaunch.makePreferences()
        let other = J74FixtureLaunch.makePreferences()
        XCTAssertFalse(first === other)
        XCTAssertEqual(first.displayMode, .iconOnly)
        XCTAssertTrue(first.showSymbol)
        XCTAssertTrue(first.componentReadings)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertEqual(first.onboarding, .init(checkpoint: .livePanel, completed: true, helperOptIn: true))
        first.displayMode = .components
        first.showSymbol = false
        first.onboarding.completed = false
        XCTAssertEqual(other.displayMode, .iconOnly)
        XCTAssertTrue(other.showSymbol)
        XCTAssertTrue(other.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        let store = J74FixtureLaunch.makeStore()
        let second = J74FixtureLaunch.makeStore()
        XCTAssertFalse(store === second)
        XCTAssertNotEqual(store.generation, second.generation)
        XCTAssertEqual(store.statusReading, .sampleCharging)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        store.disconnect()
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(second.statusReading, .sampleCharging)
    }

    func testFixtureHelperCapabilityIsPreparedWithoutLiveService() async {
        let router = AppRouter()
        await J74FixtureLaunch.prepare(router: router)
        XCTAssertTrue(router.settingsHelperSetup.service is FakeHelperService)
        XCTAssertFalse(router.settingsHelperSetup.helperSwitchedOff)
        guard case .connected? = (router.settingsHelperSetup.service as? FakeHelperService)?.status else {
            return XCTFail("Fixture helper must report connected")
        }
    }

    func testLightAndHighContrastHostsUseIntrinsicNativeSymbolMetrics() {
        XCTAssertEqual(J74FixtureLaunch.appearanceName, .aqua)
        let preferences = J74FixtureLaunch.makePreferences()
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let host = NSHostingView(rootView: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
            host.appearance = NSAppearance(named: appearance)
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]),
                           NSAppearance(named: appearance)?.bestMatch(from: [.aqua, .darkAqua]))
            XCTAssertGreaterThan(host.fittingSize.width, 0)
            XCTAssertGreaterThan(host.fittingSize.height, 0)
        }
    }
    #endif

    func testIconOnlySourceUsesTemplateAccessibilityAndExistingBridgeWithoutChrome() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Components/MenuBarStatusLabel.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.components(separatedBy: "var body: some View {").last)
        let icon = try XCTUnwrap(body.components(separatedBy: "} else {").first)
        for token in ["Image(systemName: symbolName)", ".renderingMode(.template)"] { XCTAssertTrue(icon.contains(token)) }
        for token in ["Text(", ".font(", "HStack", ".frame(", ".padding(", ".tint("] { XCTAssertFalse(icon.contains(token)) }
        for token in [".accessibilityElement(children: .ignore)", ".accessibilityLabel(accessibilityAnnouncement)", ".accessibilityHint(Self.accessibilityHint)"] {
            XCTAssertTrue(body.contains(token))
        }
        for token in ["RoundedRectangle", "Gradient", ".shadow(", ".background(", ".offset(", ".position(", "Font.custom", "J74", "J7.4", "usesIconOnlyFixture"] {
            XCTAssertFalse(source.contains(token))
        }
        let fixture = try String(contentsOf: root.appendingPathComponent("App/J74FixtureLaunch.swift"), encoding: .utf8)
        XCTAssertTrue(fixture.hasPrefix("#if DEBUG\n"))
        for token in ["UserDefaults", "NSWindow(", "NSImage(", ".cacheDisplay(", ".displayIgnoringOpacity(", ".addSubview(", "CGRequestScreenCaptureAccess", "AXIsProcessTrustedWithOptions"] {
            XCTAssertFalse(fixture.contains(token))
        }
        let app = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        for token in ["MenuBarExtra(isInserted:", "ScenePresentationBridge(", "view.observeJ74StatusFixture(", "button.performClick(nil)"] { XCTAssertTrue(app.contains(token)) }
    }

    private func reading(source: ReadingSource = .system, freshness: ReadingFreshness = .fresh,
                         watts: Double? = 42.1, battery: Capability = .available,
                         charger: Capability = .available) -> PowerReading {
        PowerReading(mode: .charging, watts: watts, timestamp: .init(timeIntervalSince1970: 1_700_000_000),
                     batteryState: .charging, capabilities: .init(battery: battery, charger: charger),
                     freshness: freshness, source: source)
    }
}
