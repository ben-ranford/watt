import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
@testable import WattFixtures
#endif
@testable import Watt

@MainActor
final class J43PanelSystemDrawTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactDesktopPresentationAndStatusLabel() throws {
        let reading = J43FixtureLaunch.reading
        try reading.validate()
        let model = StatusPanelModel(reading: reading)
        XCTAssertTrue(model.isDesktop)
        XCTAssertEqual(model.title, "Drawing")
        XCTAssertEqual(model.headlineValue, "38.2 W")
        XCTAssertEqual(model.subtitle, "Mac Studio · no battery, so it’s all draw")
        XCTAssertEqual(model.summaryLabel, "System draw status")
        XCTAssertEqual(model.accessibilitySummary, "Drawing, 38.2 W, Mac Studio · no battery, so it’s all draw")
        XCTAssertEqual(model.components.map(\.name), ["CPU", "GPU", "SSD", "Other"])
        XCTAssertEqual(model.components.map(\.watts), [14.6, 11.2, 1.9, 10.5])
        XCTAssertEqual(model.components.map(\.id), ["cpu", "gpu", "ssd", "other"])
        XCTAssertEqual(model.battery, "—")
        XCTAssertEqual(model.charger, "—")
        XCTAssertNil(reading.value(for: .delta))
        XCTAssertNil(reading.value(for: .charger))
        let preferences = PreferencesStore(storage: InMemoryStorage())
        J43FixtureLaunch.prepare(preferences: preferences)
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(label.text, "38.2 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
    }

    func testOffLossStaleAndUnavailableNeverInventComponents() {
        let reading = J43FixtureLaunch.reading
        XCTAssertTrue(StatusPanelModel(reading: reading, componentReadingsEnabled: false).components.isEmpty)
        XCTAssertTrue(StatusPanelModel(reading: reading, helperSwitchedOff: true).components.isEmpty)
        for freshness in [ReadingFreshness.fresh, .stale, .unavailable] {
            let sample = PowerReading(mode: .systemDraw, watts: nil, components: reading.components,
                batteryState: .noBattery, capabilities: .init(battery: .unsupported,
                    charger: .unsupported, systemDraw: .available, components: .permissionRequired),
                freshness: freshness, source: .helper, systemWatts: 38.2)
            let model = StatusPanelModel(reading: sample)
            XCTAssertTrue(model.isDesktop)
            XCTAssertTrue(model.components.isEmpty)
            XCTAssertEqual(model.headlineValue, freshness == .fresh ? "38.2 W" : "− − W")
            XCTAssertEqual(model.subtitle, freshness == .fresh ? "No battery, so it’s all draw" : "Usually right after wake. Watt? tries again every few seconds.")
            if freshness == .stale { XCTAssertTrue(model.accessibilitySummary.contains("Stale reading")) }
        }
        let stale = PowerReading(mode: .systemDraw, watts: nil, components: reading.components,
            batteryState: .noBattery, capabilities: reading.capabilities,
            freshness: .stale, source: .helper, systemWatts: 38.2)
        XCTAssertTrue(StatusPanelModel(reading: stale).components.isEmpty)
        XCTAssertFalse(StatusPanelModel(reading: .unavailable).isDesktop)
        XCTAssertFalse(StatusPanelModel(reading: .sampleCharging).isDesktop)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).panelHeight, 473)
    }

    func testNativePanelGeometryAndFooterActionsPreservePreferences() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        J43FixtureLaunch.prepare(preferences: preferences)
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: J43FixtureLaunch.reading,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        XCTAssertEqual(NSHostingView(rootView: panel).fittingSize, NSSize(width: 320, height: 335))
        router.showStatusPanel()
        panel.onSettings()
        panel.onQuit()
        XCTAssertEqual(routes, [.statusPanel, .settings])
        XCTAssertEqual(quits, 1)
        XCTAssertEqual(preferences.onboarding, original)
        XCTAssertEqual(preferences.displayMode, .draw)
    }

    func testDesktopOnboardingRetainsHelperOfferThenEntersSharedPanel() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: J42FixtureLaunch.reading)
        ChooseMenuReadingView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .helperOffer)
        XCTAssertEqual(preferences.displayMode, .draw)
        XCTAssertFalse(preferences.onboarding.completed)
        // Completion remains the existing setup/coach-mark flow, never fabricated helper approval.
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        XCTAssertEqual(routes, [.statusPanel])
        XCTAssertEqual(preferences.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(preferences.displayMode, .draw)
    }

    func testFixtureSelectorsIsolationAndFrozenClock() throws {
        let fixture = try ScenarioRegistry.resolve("J4.3")
        XCTAssertEqual(fixture.story.node, "J4.3")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J4.3/base"])
        #if SWIFT_PACKAGE
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "J4.3/base"]))
        #else
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "J4.3/base"]))
        #endif
        for variant in ["unknown", "dark", "unavailable"] {
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J4.3", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.story(
                FixtureSelection(story: fixture.story, variant: variant)).smokeLaunchArguments())
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J43FixtureLaunch.requested)
        #endif
        XCTAssertEqual(J43FixtureLaunch.makeStore().currentReading, J43FixtureLaunch.reading)
        let unrelated = PreferencesStore(storage: InMemoryStorage())
        J43FixtureLaunch.prepare(preferences: PreferencesStore(storage: InMemoryStorage()))
        XCTAssertEqual(unrelated.displayMode, .delta)
        XCTAssertFalse(unrelated.onboarding.completed)
    }
    #endif

    func testNativeChromeAndCapabilityBasedRows() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"))
        for token in ["if !model.isDesktop", "Text(model.headlineValue)", ".accessibilityLabel(model.summaryLabel)",
                      "Form {", ".formStyle(.grouped)", "LabeledContent", ".buttonStyle(.borderless)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "LinearGradient", ".shadow(", ".tint(", "Font.custom"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }
}
