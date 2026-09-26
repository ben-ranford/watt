#if DEBUG || SWIFT_PACKAGE
import XCTest
import SwiftUI
import AppKit
#if SWIFT_PACKAGE
import WattFixtures
@testable import Watt
#else
@testable import Watt
#endif

final class F05FixtureTests: XCTestCase {
    func testAll69ExactIDsResolveWithUniqueNodes() throws {
        var ids = ["C01", "C02", "C03"] + (1...12).map { "C04.\($0)" } + ["C05"]
        for (journey, count) in [8,5,3,3,3,5,4,3,3,8,3,5].enumerated() {
            ids += (1...count).map { "J\(journey + 1).\($0)" }
        }
        XCTAssertEqual(Set(ids), Set(ScenarioRegistry.stories.map(\.id)))
        XCTAssertEqual(ScenarioRegistry.stories.count, 69)
        XCTAssertEqual(Set(ScenarioRegistry.stories.map(\.node)).count, 69)
        for id in ids {
            let fixture = try ScenarioRegistry.resolve(id).story
            let reference = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fixture.referenceJSON.utf8)) as? [String: Any])
            XCTAssertEqual(reference["node"] as? String, fixture.node)
            XCTAssertEqual(reference["story"] as? String, id)
            XCTAssertFalse(fixture.expectedScene.isEmpty)
            XCTAssertEqual(fixture.componentIDs, ["cpu", "gpu", "display", "other"])
        }
    }
    func testBacklogAndPinnedReferenceMatch() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let backlog = try String(contentsOf: root.appendingPathComponent("SCREEN-BACKLOG.md"), encoding: .utf8)
        for story in ScenarioRegistry.stories {
            let row = try XCTUnwrap(backlog.split(separator: "\n").first { $0.contains("**" + story.id + "**") })
            XCTAssertTrue(row.contains("[`" + story.node + "`]"))
            XCTAssertTrue(row.contains(story.state))
            XCTAssertTrue(row.contains(story.frame))
        }
    }
    func testUnknownIDsAndVariantsFail() {
        for id in ["", "C04", "J13.1", "C01/../../", "c01"] {
            XCTAssertThrowsError(try ScenarioRegistry.resolve(id))
        }
        XCTAssertThrowsError(try ScenarioRegistry.resolve("C01", variant: "unknown"))
    }
    func testTwoRunsAreDeterministicAndAllVariantsResolve() throws {
        XCTAssertEqual(try ScenarioRegistry.canonicalData(), try ScenarioRegistry.canonicalData())
        for story in ScenarioRegistry.stories {
            for variant in story.variants {
                let a = try ScenarioRegistry.resolve(story.id, variant: variant)
                let b = try ScenarioRegistry.resolve(story.id, variant: variant)
                XCTAssertEqual(a, b)
                XCTAssertEqual(a.story.fixedClock, b.story.fixedClock)
                XCTAssertEqual(a.stableID, story.id + "/" + variant)
            }
        }
    }
    func testEveryUnimplementedFixtureRefusesRendering() throws {
        for story in ScenarioRegistry.stories where story.status == "not implemented" {
            XCTAssertEqual(story.status, "not implemented")
            XCTAssertThrowsError(try story.requireRenderTarget()) { error in
                XCTAssertEqual(error as? FixtureError, .notImplemented(story.id))
            }
        }
    }
    func testOnlyImplementedStoriesHaveRenderTargets() throws {
        XCTAssertEqual(ScenarioRegistry.stories.filter { $0.status == "implemented" }.map(\.id), ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.7", "C04.8", "C04.9", "C04.10", "C04.11", "C04.12", "C05", "J1.1", "J1.2", "J1.3", "J1.4", "J1.5", "J1.6", "J1.7", "J1.8", "J2.1", "J2.2", "J2.3", "J2.4", "J2.5", "J3.1", "J3.2", "J3.3", "J4.1", "J4.2", "J4.3", "J5.1", "J5.2", "J5.3", "J6.1", "J6.2", "J6.3", "J6.4", "J6.5", "J7.1", "J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J8.3", "J9.1", "J9.2", "J9.3", "J10.2", "J10.3", "J10.4", "J10.5", "J10.6", "J10.7", "J10.8", "J12.1", "J12.2", "J12.3", "J12.4", "J12.5", "J11.1", "J11.2", "J11.3"])
        XCTAssertNoThrow(try ScenarioRegistry.resolve("C01").story.requireRenderTarget())
    }

    func testC01ExactPresentation() {
        let model = StatusPanelModel(reading: .sampleCharging, chargerDescription: "96 W USB-C charger")
        XCTAssertEqual(model.title, "Charging")
        XCTAssertEqual(model.battery, "+42.1 W")
        XCTAssertEqual(model.charger, "65.0 W")
        XCTAssertEqual(model.system, "22.9 W")
        XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(model.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(model.components.map(\.name), ["CPU", "GPU", "Display", "Other"])
        XCTAssertEqual(model.components.map { PowerFormatter.watts($0.watts, signed: false) }, ["9.8 W", "4.1 W", "5.2 W", "3.8 W"])
        XCTAssertEqual(model.accessibilitySummary, "Charging, +42.1 W, 64% · full in about 38 min")
        XCTAssertNil(StatusPanelModel(reading: .sampleCharging).chargerSubtitle)
    }

    func testC01UnavailableAndDisabledCapabilitiesNeverLeakValues() {
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            let reading = PowerReading(mode: .charging, watts: 42.1, batteryPercentage: 64,
                components: [.init(name: "CPU", watts: 9.8)], batteryState: .charging,
                capabilities: .init(battery: capability, charger: capability, systemDraw: capability, components: capability),
                source: .fixture, chargerWatts: 65, systemWatts: 22.9)
            let model = StatusPanelModel(reading: reading, chargerDescription: "96 W USB-C charger")
            XCTAssertEqual(model.battery, "—")
            XCTAssertEqual(model.charger, "—")
            XCTAssertEqual(model.system, "—")
            XCTAssertEqual(model.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
            XCTAssertNil(model.chargerSubtitle)
            XCTAssertTrue(model.components.isEmpty)
        }
        let unavailable = StatusPanelModel(reading: .unavailable)
        XCTAssertEqual(unavailable.title, "No reading")
        XCTAssertEqual(unavailable.battery, "—")
        XCTAssertTrue(unavailable.components.isEmpty)
    }

    func testC01UnavailableSourceAndFreshnessOverrideAvailableCapabilities() {
        for (source, freshness) in [(ReadingSource.unavailable, ReadingFreshness.fresh), (.fixture, .unavailable)] {
            let reading = PowerReading(mode: .charging, watts: 42.1, batteryPercentage: 64,
                components: [.init(name: "CPU", watts: 9.8)], batteryState: .charging,
                capabilities: .init(battery: .available, charger: .available, systemDraw: .available, components: .available),
                freshness: freshness, source: source, chargerWatts: 65, systemWatts: 22.9)
            let model = StatusPanelModel(reading: reading)
            XCTAssertEqual(model.title, "No reading")
            XCTAssertEqual([model.battery, model.charger, model.system], ["—", "—", "—"])
            XCTAssertTrue(model.components.isEmpty)
        }
    }

    @MainActor
    func testC01RuntimeStorageIsIsolatedAndClockPinned() {
        let firstStorage = InMemoryStorage()
        let secondStorage = InMemoryStorage()
        firstStorage.values["C01"] = Data([1])
        XCTAssertTrue(secondStorage.values.isEmpty)
        let first = PreferencesStore(storage: firstStorage)
        let second = PreferencesStore(storage: secondStorage)
        XCTAssertFalse(first === second)
        let power = PowerReadingStore.preview
        XCTAssertEqual(power.currentReading, .sampleCharging)
        XCTAssertEqual(power.freshness(maximumAge: 0), .fresh)
    }

    func testC01FormatterSignsAndZeros() {
        XCTAssertEqual(PowerFormatter.watts(-18.4), "-18.4 W")
        XCTAssertEqual(PowerFormatter.watts(42.1), "+42.1 W")
        XCTAssertEqual(PowerFormatter.watts(65, signed: false), "65.0 W")
        XCTAssertEqual(PowerFormatter.watts(-0.001), "0.0 W")
        XCTAssertEqual(PowerFormatter.watts(.nan), "—")
    }

    @MainActor
    func testC01ActionsUseSuppliedCallbacks() {
        let router = AppRouter()
        var settings = 0
        var quit = 0
        router.present = { if $0 == .settings { settings += 1 } }
        let panel = StatusPanelView(reading: .unavailable, onSettings: { router.showSettings() }, onQuit: { quit += 1 })
        panel.onSettings()
        panel.onQuit()
        XCTAssertEqual(settings, 1)
        XCTAssertEqual(quit, 1)
    }

    @MainActor
    func testC01AccessibilitySourceSemantics() throws {
        let battery = StatusPanelModel(reading: .sampleCharging)
        XCTAssertEqual(battery.summaryLabel, "Battery status")
        XCTAssertEqual(battery.headlineValue, "+42.1 W")
        XCTAssertEqual(battery.accessibilitySummary, "Charging, +42.1 W, 64% · full in about 38 min")
        XCTAssertEqual(StatusPanelModel(reading: J43FixtureLaunch.reading).summaryLabel, "System draw status")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"), encoding: .utf8)
        for semantic in [".accessibilityLabel(model.summaryLabel)", ".accessibilityValue(model.voiceOverSummary)",
                         ".accessibilityLabel(label)", "value == \"—\" ? \"Unavailable\" : value",
                         "Button(\"Settings…\", action: onSettings)", "action: onQuit)"] {
            XCTAssertTrue(source.contains(semantic), semantic)
        }
    }

    func testStorageIsNewForEveryLaunch() throws {
        let selection = try ScenarioRegistry.resolve("C01")
        var first = selection.makeStorage()
        first.values["preferences"] = Data([1])
        XCTAssertTrue(selection.makeStorage().values.isEmpty)
    }
    #if DEBUG
    func testAppCompositionRejectsUnimplementedStoriesAndGalleriesBeforeLaunch() throws {
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"]))
        for capture in ["--watt-capture-status-panel", "--watt-capture-gallery-light", "--watt-capture-gallery-dark"] {
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", capture]))
        }
        for story in ScenarioRegistry.stories {
            for variant in story.variants {
                let id = story.id + "/" + variant
                #if !SWIFT_PACKAGE
                if story.status == "implemented" && (!["C05", "J1.4", "J1.8", "J2.1", "J2.2", "J2.3", "J2.4", "J2.5", "J3.1", "J3.2", "J3.3", "J4.1", "J4.2", "J4.3", "J5.1", "J5.2", "J5.3", "J6.1", "J6.2", "J6.3", "J6.5", "J7.1", "J7.2", "J7.3", "J7.4", "J8.1", "J8.2", "J10.4", "J10.5", "J12.3", "J12.4"].contains(story.id) || variant == "base") {
                    XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", id]))
                    continue
                }
                #endif
                let message = try XCTUnwrap(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", id]), "Expected rejection for " + id)
                XCTAssertTrue(message.contains(id))
            }
        }
        for gallery in GalleryFixture.allCases {
            let message = try XCTUnwrap(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", gallery.rawValue]))
            XCTAssertTrue(message.contains(gallery.rawValue))
            XCTAssertTrue(message.contains("GalleryHost"))
        }
        for args in [["--watt-fixture"], ["--watt-fixture=C01"], ["--watt-fixture", "C01", "--watt-fixture", "C02"], ["--watt-fixture", "C01/unknown"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
        }
        #if !SWIFT_PACKAGE
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", "C01"]))
        #endif
    }

    func testJ18LaunchAcceptsOnlyBase() throws {
        let fixture = try ScenarioRegistry.resolve("J1.8")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J1.8/base"])
        for variant in ["unavailable", "loading", "error", "unknown"] {
            let id = "J1.8/" + variant
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J1.8", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", id]))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", id]))
            #if !SWIFT_PACKAGE
            // Even selections constructed without the parser must fail closed.
            let selection = FixtureSelection(story: fixture.story, variant: variant)
            XCTAssertThrowsError(try FixtureLaunchSelection.story(selection).smokeLaunchArguments()) { error in
                XCTAssertEqual(error as? FixtureError, .notImplemented(id))
            }
            #endif
        }
    }

    func testLaunchParserFailsClosed() throws {
        XCTAssertNil(try FixtureLaunchSelection.parse(["Watt"]))
        for args in [["--watt-fixture"], ["--watt-fixture", "C01", "--watt-fixture", "C02"], ["--watt-fixture", "C01/"], ["--watt-fixture", "unknown"]] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(args))
        }
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "C01"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C01/base"])
    }
    func testGalleryIsDistinctFromStories() throws {
        for gallery in GalleryFixture.allCases {
            XCTAssertThrowsError(try ScenarioRegistry.resolve(gallery.rawValue))
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", gallery.rawValue]))
            XCTAssertEqual(try selection.smokeLaunchArguments(), gallery.launchArguments)
        }
    }
    #endif
}


#if DEBUG
extension F05FixtureTests {
    func testC02ExactPresentationAndStableFixture() throws {
        let reading = PowerReading.sampleOnBattery
        try reading.validate()
        XCTAssertEqual(reading, .sampleOnBattery)
        XCTAssertEqual(reading.timestamp, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(reading.mode, .onBattery)
        XCTAssertEqual(reading.batteryState, .discharging)
        XCTAssertEqual(reading.source, .fixture)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertEqual(reading.watts, -18.4)
        XCTAssertEqual(reading.systemWatts, 18.4)
        let model = StatusPanelModel(reading: reading)
        XCTAssertEqual(model.title, "On battery")
        XCTAssertEqual(model.subtitle, "64% · about 4 h 10 min left")
        XCTAssertEqual([model.charger, model.system, model.battery], ["Unplugged", "18.4 W", "−18.4 W"])
        XCTAssertNil(model.chargerSubtitle)
        XCTAssertEqual(model.components.map(\.id), ["cpu", "gpu", "display", "other"])
        XCTAssertEqual(model.components.map(\.name), ["CPU", "GPU", "Display", "Other"])
        XCTAssertEqual(model.components.map { PowerFormatter.watts($0.watts, signed: false) },
                       ["6.2 W", "1.9 W", "4.8 W", "5.5 W"])
        XCTAssertEqual(model.accessibilitySummary, "On battery, −18.4 W, 64% · about 4 h 10 min left")
    }

    func testC02UnavailableDoesNotBecomeUnpluggedOrZero() {
        for source in [ReadingSource.fixture, .unavailable] {
            for freshness in [ReadingFreshness.fresh, .unavailable] {
                for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
                    let reading = PowerReading(mode: .onBattery, watts: -18.4, batteryPercentage: 64,
                        components: [.init(name: "CPU", watts: 6.2)], batteryState: .discharging,
                        capabilities: .init(battery: capability, charger: capability,
                                            systemDraw: capability, components: capability),
                        freshness: freshness, source: source, systemWatts: 18.4)
                    let model = StatusPanelModel(reading: reading)
                    XCTAssertEqual(model.battery, "—")
                    XCTAssertEqual(model.system, "—")
                    XCTAssertEqual(model.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
                    XCTAssertTrue(model.components.isEmpty)
                    XCTAssertEqual(model.charger, source == .fixture && freshness == .fresh && capability == .disconnected ? "Unplugged" : "—")
                }
            }
        }
    }

    @MainActor
    func testC02CallbacksAndPinnedStore() {
        let router = AppRouter()
        var settings = 0
        var quit = 0
        router.present = { if $0 == .settings { settings += 1 } }
        let panel = StatusPanelView(reading: .sampleOnBattery,
                                   onSettings: { router.showSettings() }, onQuit: { quit += 1 })
        panel.onSettings()
        panel.onQuit()
        XCTAssertEqual(settings, 1)
        XCTAssertEqual(quit, 1)
        let store = PowerReadingStore(currentReading: .sampleOnBattery, clock: FakeWattClock())
        XCTAssertEqual(store.currentReading, .sampleOnBattery)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
    }

    func testC02LaunchGateAndMalformedSelectors() throws {
        for id in ["C02", "C02/base"] {
            let args = ["Watt", "--watt-fixture", id]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C02/base"])
            #if SWIFT_PACKAGE
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #else
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
        }
        for args in [["--watt-fixture=C02"], ["--watt-fixture", "C02/unknown"],
                     ["--watt-fixture", "C02", "--watt-fixture", "C01"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
        }
    }
}
#endif

@MainActor
final class C03ContextMenuTests: XCTestCase {
    private func preferences() -> PreferencesStore {
        _ = NSApplication.shared
        let value = PreferencesStore(storage: InMemoryStorage())
        value.onboarding.completed = true
        return value
    }

    func testC03OrderSeparatorsAndShortcuts() throws {
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences(), componentsAvailable: { true })
        XCTAssertEqual(menu.items.map { $0.isSeparatorItem ? "|" : $0.title },
                       ["Show in Menu Bar", "|", "Open Watt?", "Settings…", "|",
                        "About Watt?", "Check for Updates…", "|", "Quit Watt?"])
        XCTAssertEqual(menu.items.map(\.keyEquivalent), ["", "", "", ",", "", "", "", "", "q"])
        XCTAssertEqual(menu.items[0].keyEquivalentModifierMask, [])
        for i in [3, 8] { XCTAssertEqual(menu.items[i].keyEquivalentModifierMask, .command) }
        let submenu = try XCTUnwrap(menu.items.first?.submenu)
        XCTAssertEqual(submenu.items.map { $0.isSeparatorItem ? "|" : $0.title },
                       ["Delta", "Charger", "Draw", "Components", "|", "Icon"])
        XCTAssertEqual(submenu.items.map(\.state), [.on, .off, .off, .off, .off, .off])
        XCTAssertTrue(submenu.items.allSatisfy { $0.keyEquivalent.isEmpty })
        XCTAssertFalse(menu.items.contains { $0.title == "Finish Setup…" })
    }

    func testC03SelectionsAndFreshCheckmarks() throws {
        let prefs = preferences()
        for (index, mode) in [(0, WattDisplayMode.delta), (1, .charger), (2, .draw), (3, .components), (5, .iconOnly)] {
            let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs, componentsAvailable: { true })
            let sub = try XCTUnwrap(menu.items.first?.submenu)
            sub.performActionForItem(at: index)
            XCTAssertEqual(prefs.displayMode, mode)
            let refreshed = try XCTUnwrap(StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs, componentsAvailable: { true }).items.first?.submenu)
            XCTAssertEqual(refreshed.items.filter { $0.state == .on }.map(\.title), [sub.items[index].title])
        }
    }

    func testC03LabelFollowsMenuSelectionOnTheSameObservedStore() throws {
        let prefs = preferences()
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: prefs)
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: prefs, componentsAvailable: { true })
        let submenu = try XCTUnwrap(menu.items.first?.submenu)
        for (index, expected) in [(0, Optional("+42.1 W")), (1, "65.0 W"),
                                  (2, "22.9 W"), (3, "CPU 9.8 W · GPU 4.1 W"), (5, nil)] {
            submenu.performActionForItem(at: index)
            XCTAssertEqual(label.text, expected)
        }
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
        prefs.showSymbol = false
        XCTAssertNil(label.text)
        prefs.displayMode = .delta
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
    }

    func testC03LabelUnavailableReadingsAndComponentSelection() {
        let prefs = preferences()
        let missing = MenuBarStatusLabel(reading: .unavailable, preferences: prefs)
        for mode in WattDisplayMode.allCases where mode != .iconOnly {
            prefs.displayMode = mode
            XCTAssertEqual(missing.text, mode == .delta ? "− − W" : "—")
            XCTAssertEqual(missing.accessibilityReading, "No reading yet")
        }
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: prefs)
        prefs.displayMode = .components
        prefs.selectedComponents = ["GPU", "CPU"]
        XCTAssertEqual(label.text, "GPU 4.1 W · CPU 9.8 W")
        prefs.selectedComponents = ["missing"]
        XCTAssertEqual(label.text, "missing —")
        prefs.selectedComponents = []
        XCTAssertEqual(label.text, "—")
        prefs.displayMode = .charger
        XCTAssertEqual(MenuBarStatusLabel(reading: .sampleOnBattery, preferences: prefs).text, "-18.4 W")
    }

    func testC03NativeAppearanceContractDoesNotUseCustomRows() throws {
        let menu = StatusItemContextMenu.makeMenu(router: AppRouter(), preferences: preferences(), componentsAvailable: { true })
        let submenu = try XCTUnwrap(menu.items.first?.submenu)
        let nativeMenu = NSMenu()
        let nativeItem = NSMenuItem()
        for (surface, expectedWidth) in [(menu, StatusItemContextMenu.referenceMenuWidth),
                                          (submenu, StatusItemContextMenu.referenceReadingsMenuWidth)] {
            // AppKit owns geometry and typography. The public minimumWidth
            // property carries the exact Figma component bounds without
            // replacing native rows or painting custom chrome.
            XCTAssertEqual(surface.minimumWidth, expectedWidth)
            XCTAssertEqual(surface.font, nativeMenu.font)
            XCTAssertTrue(surface.showsStateColumn)
            XCTAssertTrue(surface.items.allSatisfy { $0.view == nil && $0.indentationLevel == 0 })
            for item in surface.items where !item.isSeparatorItem {
                XCTAssertNil(item.attributedTitle) // native title retains type-select and AX semantics
                XCTAssertNil(item.image) // no fabricated spacer column
                if #available(macOS 27.0, *) {
                    XCTAssertEqual(item.preferredImageVisibility, nativeItem.preferredImageVisibility)
                }
            }
            XCTAssertTrue(surface.items.filter(\.isSeparatorItem).allSatisfy { $0.image == nil })
            XCTAssertNil(surface.appearance) // respect system/light/dark and accessibility appearance
            XCTAssertNil(surface.highlightedItem) // tracking, not construction, owns hover
        }
    }

    func testC03ReferenceFixtureEnablesUpdateActionWithInjectedService() throws {
        let menu = StatusItemContextMenu.makeMenu(
            router: AppRouter(updateService: FakeUpdateService()),
            preferences: preferences(),
            componentsAvailable: { true })

        let updates = try XCTUnwrap(menu.items.first { $0.title == "Check for Updates…" })
        XCTAssertTrue(updates.isEnabled)
    }

    func testC03NativeShortcutDispatchPreservesTargetsAndModifiers() throws {
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        var quits = 0
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences(), componentsAvailable: { true },
                                                onQuit: { quits += 1 })
        for (characters, code, modifiers, expected) in [
            (",", UInt16(43), NSEvent.ModifierFlags(), false),
            (",", UInt16(43), .command, true),
            ("q", UInt16(12), NSEvent.ModifierFlags(), false),
            ("q", UInt16(12), .command, true)
        ] {
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers,
                timestamp: 0, windowNumber: 0, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
            XCTAssertEqual(menu.performKeyEquivalent(with: event), expected)
        }
        XCTAssertEqual(destinations, [.settings])
        XCTAssertEqual(quits, 1)
        let parent = try XCTUnwrap(menu.items.first)
        let submenu = try XCTUnwrap(parent.submenu)
        XCTAssertTrue(parent.menu === menu)
        XCTAssertTrue(submenu.supermenu === menu)
        for item in submenu.items where !item.isSeparatorItem {
            XCTAssertTrue(item.menu === submenu)
            XCTAssertFalse(item.title.isEmpty) // retain native type-select / accessibility title source
            XCTAssertNotNil(item.action)
            XCTAssertNotNil(item.target)
            XCTAssertNil(item.view)
        }
    }

    func testC03ActionsAndSetupPreservedOutsideBase() {
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        var about = 0, quit = 0
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences(), componentsAvailable: { true },
                                                onAbout: { about += 1 }, onQuit: { quit += 1 })
        for index in [2, 3, 5, 6, 8] { menu.performActionForItem(at: index) }
        XCTAssertEqual(destinations, [.statusPanel, .settings])
        XCTAssertEqual(about, 1)
        XCTAssertEqual(quit, 1)
        let incomplete = StatusItemContextMenu.makeMenu(router: router, preferences: PreferencesStore(storage: InMemoryStorage()), componentsAvailable: { true })
        XCTAssertTrue(incomplete.items.contains { $0.title == "Finish Setup…" })
    }

    func testC03StableSelectorAndFailClosedVariants() throws {
        for selector in ["C03", "C03/base"] {
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", selector]))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C03/base"])
            #if !SWIFT_PACKAGE
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", selector]))
            #endif
        }
        for args in [["--watt-fixture=C03"], ["--watt-fixture", "C03/unknown"],
                     ["--watt-fixture", "C03", "--watt-fixture", "C01"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
        }
    }
}
#endif

#if DEBUG
@MainActor
final class C041StatusItemTests: XCTestCase {
    func testCaptureBitmapUsesExactReferenceScale() throws {
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, NSSize(width: 560, height: 44))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        XCTAssertEqual(context.cgContext.ctm.a, 1)
        XCTAssertEqual(abs(context.cgContext.ctm.d), 1)
    }

    func testReferenceGeometryIncludesEntireStatusItem() {
        XCTAssertEqual(C041FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C041FixtureLaunch.itemRect, NSRect(x: 205, y: 5, width: 96, height: 24))
        XCTAssertTrue(NSRect(origin: .zero, size: C041FixtureLaunch.captureSize)
            .contains(C041FixtureLaunch.itemRect))
        XCTAssertEqual(C041FixtureLaunch.itemRect.maxX, 301)
    }

    func testDisplayPreferencesRemainLiveAndIsolated() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let otherPreferences = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences)
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        XCTAssertTrue(otherPreferences.showSymbol)
        preferences.displayMode = .charger
        XCTAssertEqual(label.text, "65.0 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .iconOnly
        XCTAssertTrue(label.showsSymbol)
        XCTAssertNil(label.text)
        preferences.displayMode = .delta
        XCTAssertFalse(label.showsSymbol)
        XCTAssertEqual(label.text, "+42.1 W")
        preferences.showSymbol = true
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
    }

    func testChargingRenderContractUsesExistingStoreAndLabel() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .delta
        preferences.showSymbol = true
        let store = PowerReadingStore.preview
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        try store.currentReading.validate()
        XCTAssertEqual(store.currentReading, .sampleCharging)
        XCTAssertEqual(store.freshness(maximumAge: 1), .fresh)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertNotNil(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
        preferences.displayMode = .draw
        XCTAssertEqual(label.text, "22.9 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        preferences.displayMode = .delta
        let unavailable = MenuBarStatusLabel(reading: .unavailable, preferences: preferences)
        XCTAssertEqual(unavailable.text, "− − W")
        XCTAssertEqual(unavailable.symbolName, "bolt.fill")
    }

    func testExactSelectorAndSiblingIsolation() throws {
        for selector in ["C04.1", "C04.1/base"] {
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", selector]))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.1/base"])
            #if !SWIFT_PACKAGE
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", selector]))
            #endif
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.1").story.node, "24:390")
        for args in [["--watt-fixture=C04.1"], ["--watt-fixture", "C04.1/unknown"],
                     ["--watt-fixture", "C04.1", "--watt-fixture", "C03"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
        }
    }
}
#endif

#if DEBUG
@MainActor
final class C042StatusItemTests: XCTestCase {
    func testOnBatteryContractAndPinnedClock() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let store = C042FixtureLaunch.makeStore()
        try store.currentReading.validate()
        XCTAssertEqual(store.currentReading, .sampleOnBattery)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "−18.4 W")
        XCTAssertEqual(label.accessibilityReading, "−18.4 watts")
        XCTAssertEqual(label.symbolName, "battery.100percent")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertNotNil(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
    }

    func testPreferencesStayLiveAndOtherModesUnchanged() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let other = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: .sampleOnBattery, preferences: preferences)
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        XCTAssertTrue(other.showSymbol)
        preferences.displayMode = .charger
        XCTAssertEqual(label.text, "-18.4 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .draw
        XCTAssertEqual(label.text, "18.4 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertEqual(label.accessibilityReading, "−18.4 watts")
        XCTAssertTrue(label.showsSymbol)
        preferences.displayMode = .delta
        XCTAssertEqual(label.text, "−18.4 W")
        XCTAssertFalse(label.showsSymbol)
        let unavailable = MenuBarStatusLabel(reading: .unavailable, preferences: preferences)
        XCTAssertEqual(unavailable.symbolName, "bolt.fill")
        XCTAssertEqual(unavailable.accessibilityReading, "No reading yet")
        let unavailableBattery = PowerReading(mode: .onBattery, watts: -18.4,
            batteryState: .discharging, capabilities: .init(battery: .unsupported), source: .fixture)
        XCTAssertEqual(MenuBarStatusLabel(reading: unavailableBattery, preferences: preferences).symbolName, "bolt.fill")
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.2", "C04.2/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.2/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C042FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C042FixtureLaunch.captureRequested(arguments: args + ["--watt-c042-capture-directory", "/tmp"]))
            #endif
            XCTAssertFalse(C042FixtureLaunch.captureRequested(arguments: args + ["--watt-c041-capture-directory", "/tmp"]))
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.2").story.node, "24:639")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.3"] {
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: ["--watt-fixture", sibling]))
            XCTAssertFalse(C042FixtureLaunch.captureRequested(arguments: ["--watt-fixture", sibling, "--watt-c042-capture-directory", "/tmp"]))
        }
        for args in [["--watt-fixture=C04.2"], ["--watt-fixture", "C04.2/unknown"],
                     ["--watt-fixture", "C04.2", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
        }
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C042FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C042FixtureLaunch.itemRect, NSRect(x: 204, y: 5, width: 97, height: 24))
        XCTAssertEqual(C042FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, Int(C042FixtureLaunch.captureSize.width))
        XCTAssertEqual(bitmap.pixelsHigh, Int(C042FixtureLaunch.captureSize.height))
        XCTAssertEqual(bitmap.size, C042FixtureLaunch.captureSize)
    }
}
#endif

#if DEBUG
@MainActor
final class C043StatusItemTests: XCTestCase {
    func testChargedOnAdapterContractAndPinnedClock() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let store = C043FixtureLaunch.makeStore()
        try store.currentReading.validate()
        XCTAssertEqual(store.currentReading.batteryState, .full)
        XCTAssertEqual(store.currentReading.batteryPercentage, 100)
        XCTAssertEqual(store.currentReading.capabilities.charger, .available)
        XCTAssertEqual(store.currentReading.source, .fixture)
        XCTAssertNil(store.currentReading.chargerWatts)
        XCTAssertNil(store.currentReading.systemWatts)
        XCTAssertEqual(store.currentReading, .sampleChargedOnAdapter)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "0.0 W")
        XCTAssertEqual(label.accessibilityReading, "0.0 watts")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertNotNil(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
    }

    func testPreferencesStayLiveAndOtherModesUnchanged() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let other = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: .sampleChargedOnAdapter, preferences: preferences)
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        XCTAssertTrue(other.showSymbol)
        preferences.displayMode = .charger
        XCTAssertEqual(label.text, "—")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .draw
        XCTAssertEqual(label.text, "—")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertEqual(label.accessibilityReading, "0.0 watts")
        XCTAssertTrue(label.showsSymbol)
        preferences.displayMode = .delta
        XCTAssertEqual(label.text, "0.0 W")
        XCTAssertFalse(label.showsSymbol)
        let unavailable = MenuBarStatusLabel(reading: .unavailable, preferences: preferences)
        XCTAssertEqual(unavailable.symbolName, "bolt.fill")
        XCTAssertEqual(unavailable.accessibilityReading, "No reading yet")
        let unavailableBattery = PowerReading(mode: .charged, watts: 0.0,
            batteryState: .full, capabilities: .init(battery: .unsupported, charger: .available), source: .fixture)
        XCTAssertEqual(MenuBarStatusLabel(reading: unavailableBattery, preferences: preferences).symbolName, "bolt.fill")
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.3", "C04.3/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.3/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C043FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C043FixtureLaunch.captureRequested(arguments: args + ["--watt-c043-capture-directory", "/tmp"]))
            #endif
            XCTAssertFalse(C043FixtureLaunch.captureRequested(arguments: args + ["--watt-c041-capture-directory", "/tmp"]))
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.3").story.node, "24:758")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2"] {
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: ["--watt-fixture", sibling]))
            XCTAssertFalse(C043FixtureLaunch.captureRequested(arguments: ["--watt-fixture", sibling, "--watt-c043-capture-directory", "/tmp"]))
        }
        for args in [["--watt-fixture=C04.3"], ["--watt-fixture", "C04.3/unknown"],
                     ["--watt-fixture", "C04.3", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C043FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C043FixtureLaunch.captureRequested(arguments: ["--watt-c043-capture-directory", "/tmp"]))
        XCTAssertFalse(C043FixtureLaunch.captureRequested(arguments: ["--watt-fixture", "C04.3", "--watt-c042-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C043FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C043FixtureLaunch.itemRect, NSRect(x: 220, y: 5, width: 81, height: 24))
        XCTAssertEqual(C043FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, Int(C043FixtureLaunch.captureSize.width))
        XCTAssertEqual(bitmap.pixelsHigh, Int(C043FixtureLaunch.captureSize.height))
        XCTAssertEqual(bitmap.size, C043FixtureLaunch.captureSize)
    }
}
#endif

#if DEBUG
@MainActor
final class C044StatusItemTests: XCTestCase {
    func testChargerInputContractAndPinnedClock() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        let store = C044FixtureLaunch.makeStore()
        try store.currentReading.validate()
        XCTAssertEqual(store.currentReading, .sampleChargerInput)
        XCTAssertEqual(store.currentReading.source, .fixture)
        XCTAssertEqual(store.currentReading.capabilities.charger, .available)
        XCTAssertEqual(store.currentReading.chargerWatts, 65.0)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "65.0 W")
        XCTAssertEqual(label.accessibilityReading, "65.0 watts")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertNotNil(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        preferences.displayMode = .delta
        XCTAssertEqual(label.text, "+42.1 W")
        preferences.displayMode = .draw
        XCTAssertEqual(label.text, "—")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol)
        XCTAssertTrue(PreferencesStore(storage: InMemoryStorage()).showSymbol)
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.4", "C04.4/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.4/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C044FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C044FixtureLaunch.captureRequested(arguments: args + ["--watt-c044-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory"] {
                XCTAssertFalse(C044FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.4").story.node, "24:877")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.5"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c044-capture-directory", "/tmp"]
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.4"], ["--watt-fixture", "C04.4/unknown"],
                     ["--watt-fixture", "C04.4", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C044FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C044FixtureLaunch.captureRequested(arguments: ["--watt-c044-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C044FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C044FixtureLaunch.itemRect, NSRect(x: 221, y: 5, width: 80, height: 24))
        XCTAssertEqual(C044FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C044FixtureLaunch.captureSize)
    }
}
@MainActor
final class C045StatusItemTests: XCTestCase {
    func testExplicitFallbackDoesNotChangeLegacyContractOrReuseCharger() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        for freshness in [ReadingFreshness.fresh, .stale, .unavailable] {
            for source in [ReadingSource.fixture, .unavailable] {
                for drawCapability in [Capability.available, .disconnected, .unknown, .unsupported, .permissionRequired] {
                    for draw in [Double?.none, 18.4, 0] {
                        let reading = PowerReading(mode: .chargerInput, watts: -12,
                            batteryState: .discharging,
                            capabilities: .init(battery: .available, charger: .disconnected, systemDraw: drawCapability),
                            freshness: freshness, source: source, chargerWatts: 65, systemWatts: draw)
                        let usable = source != .unavailable && freshness == .fresh
                        XCTAssertEqual(reading.value(for: .charger), usable ? -12 : nil)
                        let expected = source != .unavailable && freshness == .fresh && drawCapability == .available ? draw : nil
                        XCTAssertEqual(reading.value(for: .charger, chargerFallback: .systemDrawWhenDisconnected), expected)
                        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
                        XCTAssertEqual(label.text, PowerFormatter.watts(expected, signed: false))
                        XCTAssertNotEqual(label.text, "65.0 W")
                    }
                }
            }
        }
        for capability in [Capability.available, .unknown, .unsupported, .permissionRequired] {
            let reading = PowerReading(mode: .charging, watts: 42.1,
                capabilities: .init(battery: .available, charger: capability, systemDraw: .available),
                source: .fixture, chargerWatts: 65, systemWatts: 18.4)
            XCTAssertEqual(reading.value(for: .charger, chargerFallback: .systemDrawWhenDisconnected),
                           reading.value(for: .charger))
        }
        let connected = MenuBarStatusLabel(reading: .sampleChargerInput, preferences: preferences)
        let unplugged = MenuBarStatusLabel(reading: C045FixtureLaunch.makeStore().currentReading, preferences: preferences)
        XCTAssertEqual(connected.text, "65.0 W")
        XCTAssertEqual(unplugged.text, "18.4 W")
        XCTAssertEqual(preferences.displayMode, .charger)
    }

    func testChargerInputContractAndPinnedClock() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        let store = C045FixtureLaunch.makeStore()
        try store.currentReading.validate()
        XCTAssertEqual(store.currentReading, .sampleUnpluggedCharger)
        XCTAssertEqual(store.currentReading.source, .fixture)
        XCTAssertEqual(store.currentReading.capabilities.charger, .disconnected)
        XCTAssertNil(store.currentReading.chargerWatts)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "18.4 W")
        XCTAssertEqual(label.accessibilityReading, "18.4 watts")
        XCTAssertEqual(label.symbolName, "battery.100percent")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertNotNil(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        preferences.displayMode = .delta
        XCTAssertEqual(label.text, "−18.4 W")
        preferences.displayMode = .draw
        XCTAssertEqual(label.text, "18.4 W")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol)
        XCTAssertTrue(PreferencesStore(storage: InMemoryStorage()).showSymbol)
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.5", "C04.5/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.5/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C045FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C045FixtureLaunch.captureRequested(arguments: args + ["--watt-c045-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory", "--watt-c044-capture-directory"] {
                XCTAssertFalse(C045FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.5").story.node, "24:996")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c045-capture-directory", "/tmp"]
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.5"], ["--watt-fixture", "C04.5/unknown"],
                     ["--watt-fixture", "C04.5", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C045FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C045FixtureLaunch.captureRequested(arguments: ["--watt-c045-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C045FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C045FixtureLaunch.itemRect, NSRect(x: 213, y: 5, width: 88, height: 24))
        XCTAssertEqual(C045FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C045FixtureLaunch.captureSize)
    }
}
@MainActor
final class C046StatusItemTests: XCTestCase {
    func testDeterministicDesktopDrawAndNativeLabel() throws {
        let store = C046FixtureLaunch.makeStore()
        let reading = store.currentReading
        try reading.validate()
        XCTAssertEqual(reading, C046FixtureLaunch.makeStore().currentReading)
        XCTAssertEqual(reading.mode, .systemDraw)
        XCTAssertEqual(reading.batteryState, .noBattery)
        XCTAssertEqual(reading.capabilities.battery, .unsupported)
        XCTAssertEqual(reading.capabilities.systemDraw, .available)
        XCTAssertNil(reading.watts)
        XCTAssertNil(reading.batteryPercentage)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertEqual(reading.systemWatts, 38.2)
        XCTAssertEqual(reading.source, .fixture)
        XCTAssertEqual(reading.freshness, .fresh)
        XCTAssertNil(reading.value(for: .delta))
        XCTAssertEqual(reading.value(for: .draw), 38.2)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .draw
        preferences.showSymbol = true
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(label.symbolName, "bolt.fill")
        XCTAssertEqual(label.text, "38.2 W")
        XCTAssertEqual(label.accessibilityReading, "38.2 watts")
        XCTAssertTrue(label.showsSymbol)
        preferences.showSymbol = false
        XCTAssertFalse(label.showsSymbol)
        XCTAssertEqual(label.text, "38.2 W")
        XCTAssertTrue(PreferencesStore(storage: InMemoryStorage()).showSymbol)
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.6", "C04.6/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.6/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C046FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C046FixtureLaunch.captureRequested(arguments: args + ["--watt-c046-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C046FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory", "--watt-c044-capture-directory", "--watt-c045-capture-directory"] {
                XCTAssertFalse(C046FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.6").story.node, "24:1115")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c046-capture-directory", "/tmp"]
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C046FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.6"], ["--watt-fixture", "C04.6/unknown"],
                     ["--watt-fixture", "C04.6", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C046FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C046FixtureLaunch.captureRequested(arguments: ["--watt-c046-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C046FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C046FixtureLaunch.itemRect, NSRect(x: 221, y: 5, width: 80, height: 24))
        XCTAssertEqual(C046FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C046FixtureLaunch.captureSize)
    }
}

@MainActor
final class C047StatusItemTests: XCTestCase {
    func testDeterministicComponentsAndPreservedLegacyFormatting() {
        let store = C047FixtureLaunch.makeStore()
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
        let reading = store.currentReading
        XCTAssertEqual(reading, C047FixtureLaunch.makeStore().currentReading)
        XCTAssertEqual(reading.mode, .perComponent)
        XCTAssertEqual(reading.source, .fixture)
        XCTAssertEqual(reading.freshness, .fresh)
        XCTAssertEqual(reading.capabilities.components, .available)
        XCTAssertEqual(reading.components.map(\.id), ["CPU", "GPU"])
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        preferences.showSymbol = false
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(label.text, "CPU 9.8 · GPU 4.1 W")
        XCTAssertEqual(label.accessibilityReading, "CPU 9.8 · GPU 4.1 watts")
        XCTAssertFalse(label.showsSymbol)
        XCTAssertEqual(MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences).text,
                       "CPU 9.8 W · GPU 4.1 W")
        preferences.selectedComponents = ["GPU", "CPU"]
        XCTAssertEqual(label.text, "GPU 4.1 · CPU 9.8 W")
        preferences.selectedComponents = ["CPU", "GPU", "Display"]
        XCTAssertEqual(preferences.selectedComponents, ["GPU", "CPU"])
        preferences.selectedComponents = ["CPU"]
        XCTAssertEqual(label.text, "CPU 9.8 W")
        preferences.selectedComponents = ["missing"]
        XCTAssertEqual(label.text, "missing —")
        preferences.selectedComponents = []
        XCTAssertEqual(label.text, "—")
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(MenuBarStatusLabel(reading: .unavailable, preferences: preferences).text, "—")
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.7", "C04.7/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.7/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C047FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C047FixtureLaunch.captureRequested(arguments: args + ["--watt-c047-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C047FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C047FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory", "--watt-c044-capture-directory", "--watt-c045-capture-directory", "--watt-c046-capture-directory"] {
                XCTAssertFalse(C047FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.7").story.node, "24:1234")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.8"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c047-capture-directory", "/tmp"]
            XCTAssertFalse(C047FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C047FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.7"], ["--watt-fixture", "C04.7/unknown"],
                     ["--watt-fixture", "C04.7", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C047FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C047FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C047FixtureLaunch.captureRequested(arguments: ["--watt-c047-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C047FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C047FixtureLaunch.itemRect, NSRect(x: 153, y: 5, width: 148, height: 24))
        XCTAssertEqual(C047FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C047FixtureLaunch.captureSize)
    }
}
@MainActor
final class C048StatusItemTests: XCTestCase {
    func testDeterministicIconOnlyUsesSharedProductionSymbol() {
        let store = C048FixtureLaunch.makeStore()
        XCTAssertEqual(store.currentReading, .sampleCharging)
        XCTAssertEqual(store.currentReading, C048FixtureLaunch.makeStore().currentReading)
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .iconOnly
        preferences.showSymbol = false
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertNil(label.text)
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
        XCTAssertEqual(MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences).symbolName, "battery.100percent.bolt")
        for reading in [PowerReading.unavailable, .sampleOnBattery] {
            let fallback = MenuBarStatusLabel(reading: reading, preferences: preferences)
            XCTAssertNil(fallback.text)
            XCTAssertEqual(fallback.symbolName, reading == .unavailable ? "bolt.fill" : "battery.100percent")
        }
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
    }

    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.8", "C04.8/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.8/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C048FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C048FixtureLaunch.captureRequested(arguments: args + ["--watt-c048-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C048FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C048FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory", "--watt-c044-capture-directory", "--watt-c045-capture-directory", "--watt-c046-capture-directory", "--watt-c047-capture-directory"] {
                XCTAssertFalse(C048FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.8").story.node, "24:1353")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.7"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c048-capture-directory", "/tmp"]
            XCTAssertFalse(C048FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C048FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.8"], ["--watt-fixture", "C04.8/unknown"],
                     ["--watt-fixture", "C04.8", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C048FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C048FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C048FixtureLaunch.captureRequested(arguments: ["--watt-c048-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C048FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C048FixtureLaunch.itemRect, NSRect(x: 260, y: 5, width: 41, height: 24))
        XCTAssertEqual(C048FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C048FixtureLaunch.captureSize)
    }
}
#endif

#if DEBUG
@MainActor
final class C049StatusItemTests: XCTestCase {
    func testUnavailableReadingAndIsolatedPreferences() {
        let first = C049FixtureLaunch.makeStore()
        let second = C049FixtureLaunch.makeStore()
        XCTAssertEqual(first.currentReading, .unavailable)
        XCTAssertEqual(second.currentReading, .unavailable)
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading.source, .unavailable)
        XCTAssertEqual(first.currentReading.freshness, .unavailable)
        XCTAssertNil(first.currentReading.watts)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: first.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "− − W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(label.accessibilityReading, "No reading yet")
        preferences.displayMode = .iconOnly
        XCTAssertNil(label.text)
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
        XCTAssertEqual(second.currentReading, .unavailable)
    }
    func testExactSelectorsAndCaptureIsolation() throws {
        for selector in ["C04.9", "C04.9/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "C04.9/base"])
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C049FixtureLaunch.matches(arguments: args))
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(C049FixtureLaunch.captureRequested(arguments: args + ["--watt-c049-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C049FixtureLaunch.matches(arguments: args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            #endif
            XCTAssertFalse(C042FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C043FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C044FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C045FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C046FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C049FixtureLaunch.captureRequested(arguments: args))
            for flag in ["--watt-c041-capture-directory", "--watt-c042-capture-directory", "--watt-c043-capture-directory", "--watt-c044-capture-directory", "--watt-c045-capture-directory", "--watt-c046-capture-directory", "--watt-c047-capture-directory", "--watt-c048-capture-directory"] {
                XCTAssertFalse(C049FixtureLaunch.captureRequested(arguments: args + [flag, "/tmp"]))
            }
        }
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.9").story.node, "24:1472")
        for sibling in ["C01", "C02", "C03", "C04.1", "C04.2", "C04.3", "C04.4", "C04.5", "C04.6", "C04.7", "C04.8"] {
            let args = ["Watt", "--watt-fixture", sibling, "--watt-c049-capture-directory", "/tmp"]
            XCTAssertFalse(C049FixtureLaunch.matches(arguments: args))
            XCTAssertFalse(C049FixtureLaunch.captureRequested(arguments: args))
        }
        for args in [["--watt-fixture=C04.9"], ["--watt-fixture", "C04.9/unknown"],
                     ["--watt-fixture", "C04.9", "--watt-fixture", "C04.1"]] {
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt"] + args))
            XCTAssertFalse(C049FixtureLaunch.matches(arguments: args))
        }
        XCTAssertFalse(C049FixtureLaunch.matches(arguments: []))
        XCTAssertFalse(C049FixtureLaunch.captureRequested(arguments: ["--watt-c049-capture-directory", "/tmp"]))
    }

    func testExactReferenceGeometryAndReusedOneXBitmap() throws {
        XCTAssertEqual(C049FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(C049FixtureLaunch.itemRect, NSRect(x: 230, y: 5, width: 71, height: 24))
        XCTAssertEqual(C049FixtureLaunch.itemRect.maxX, 301)
        let bitmap = try XCTUnwrap(C041FixtureLaunch.captureBitmap1x())
        XCTAssertEqual(bitmap.pixelsWide, 560)
        XCTAssertEqual(bitmap.pixelsHigh, 44)
        XCTAssertEqual(bitmap.size, C049FixtureLaunch.captureSize)
    }
}
#endif

#if DEBUG
@MainActor
final class C0410StatusItemTests: XCTestCase {
    func testChargingSemanticsAndGeometry() throws {
        let store = C0410FixtureLaunch.makeStore()
        XCTAssertEqual(store.currentReading, PowerReadingStore.preview.currentReading)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(C0410FixtureLaunch.itemRect, NSRect(x: 205, y: 5, width: 96, height: 24))
        XCTAssertEqual(C0410FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.10").story.node, "24:1591")
    }

    func testSelectorIsolation() throws {
        for selector in ["C04.10", "C04.10/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            XCTAssertNoThrow(try ScenarioRegistry.resolve("C04.10").story.requireRenderTarget())
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C0410FixtureLaunch.matches(arguments: args))
            XCTAssertTrue(C0410FixtureLaunch.captureRequested(arguments: args + ["--watt-c0410-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C0410FixtureLaunch.matches(arguments: args))
            #endif
            XCTAssertFalse(C0410FixtureLaunch.captureRequested(arguments: args))
            for n in 1...9 {
                XCTAssertFalse(C0410FixtureLaunch.captureRequested(arguments: args + ["--watt-c04\(n)-capture-directory", "/tmp"]))
            }
        }
        for story in ScenarioRegistry.stories where story.id != "C04.10" {
            XCTAssertFalse(C0410FixtureLaunch.captureRequested(arguments:
                ["Watt", "--watt-fixture", story.id, "--watt-c0410-capture-directory", "/tmp"]))
        }
        for args in [[], ["--watt-c0410-capture-directory", "/tmp"],
                     ["--watt-fixture", "C04.10/unknown"],
                     ["--watt-fixture", "C04.10", "--watt-fixture", "C04.1"]] {
            XCTAssertFalse(C0410FixtureLaunch.matches(arguments: args))
        }
    }

    func testNativeSelectionFollowsPanelLifecycle() throws {
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        let router = AppRouter()
        let controller = C0410PanelSelection(button: button, router: router,
            preferences: PreferencesStore(storage: InMemoryStorage()),
            store: C0410FixtureLaunch.makeStore())
        // Unit-test lifecycle synchronization without XCTest's transient window timing.
        // capture.json separately checks performClick -> real popover -> native highlight.
        for presented in [false, true, false, true, false] {
            controller.applySelection(isPresented: presented)
            XCTAssertEqual(router.statusPanelPresented, presented)
            XCTAssertEqual(button.isHighlighted, presented)
        }
    }
}
#endif

#if DEBUG
@MainActor
final class C0411StatusItemTests: XCTestCase {
    func testChargingSemanticsAndGeometry() throws {
        let store = C0411FixtureLaunch.makeStore()
        XCTAssertEqual(store.currentReading, PowerReadingStore.preview.currentReading)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(C0411FixtureLaunch.itemRect, NSRect(x: 205, y: 5, width: 96, height: 24))
        XCTAssertEqual(C0411FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.11").story.node, "24:1711")
    }

    func testSelectorIsolation() throws {
        for selector in ["C04.11", "C04.11/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            XCTAssertNoThrow(try ScenarioRegistry.resolve("C04.11").story.requireRenderTarget())
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C0411FixtureLaunch.matches(arguments: args))
            XCTAssertTrue(C0411FixtureLaunch.captureRequested(arguments: args + ["--watt-c0411-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C0411FixtureLaunch.matches(arguments: args))
            #endif
            XCTAssertFalse(C0411FixtureLaunch.captureRequested(arguments: args))
            for n in 1...10 {
                XCTAssertFalse(C0411FixtureLaunch.captureRequested(arguments: args + ["--watt-c04\(n)-capture-directory", "/tmp"]))
            }
        }
        for story in ScenarioRegistry.stories where story.id != "C04.11" {
            XCTAssertFalse(C0411FixtureLaunch.captureRequested(arguments:
                ["Watt", "--watt-fixture", story.id, "--watt-c0411-capture-directory", "/tmp"]))
        }
        for args in [[], ["--watt-c0411-capture-directory", "/tmp"],
                     ["--watt-fixture", "C04.11/unknown"],
                     ["--watt-fixture", "C04.11", "--watt-fixture", "C04.1"]] {
            XCTAssertFalse(C0411FixtureLaunch.matches(arguments: args))
        }
    }

    func testPublicLightAppearanceAndUnselectedNativeButton() throws {
        let item = NSStatusBar.system.statusItem(withLength: C0411FixtureLaunch.itemRect.width)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: C0411FixtureLaunch.appearanceName)
        XCTAssertEqual(button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
        XCTAssertFalse(button.isHighlighted)
        XCTAssertNil(button.contentTintColor)
        let first = C0411FixtureLaunch.makeStore()
        let second = C0411FixtureLaunch.makeStore()
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading, second.currentReading)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
        XCTAssertEqual(C0411FixtureLaunch.captureSize, C041FixtureLaunch.captureSize)
    }
}

@MainActor
final class C0412StatusItemTests: XCTestCase {
    func testOnBatterySemanticsAndGeometry() throws {
        let store = C0412FixtureLaunch.makeStore()
        XCTAssertEqual(store.currentReading, C042FixtureLaunch.makeStore().currentReading)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "−18.4 W")
        XCTAssertEqual(label.symbolName, "battery.100percent")
        XCTAssertEqual(C0412FixtureLaunch.itemRect, NSRect(x: 204, y: 5, width: 97, height: 24))
        XCTAssertEqual(C0412FixtureLaunch.captureSize, NSSize(width: 560, height: 44))
        XCTAssertEqual(try ScenarioRegistry.resolve("C04.12").story.node, "24:1960")
    }

    func testSelectorIsolation() throws {
        for selector in ["C04.12", "C04.12/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            XCTAssertNoThrow(try ScenarioRegistry.resolve("C04.12").story.requireRenderTarget())
            #if !SWIFT_PACKAGE
            XCTAssertTrue(C0412FixtureLaunch.matches(arguments: args))
            XCTAssertTrue(C0412FixtureLaunch.captureRequested(arguments: args + ["--watt-c0412-capture-directory", "/tmp"]))
            #else
            XCTAssertFalse(C0412FixtureLaunch.matches(arguments: args))
            #endif
            XCTAssertFalse(C0412FixtureLaunch.captureRequested(arguments: args))
            for n in 1...11 {
                XCTAssertFalse(C0412FixtureLaunch.captureRequested(arguments: args + ["--watt-c04\(n)-capture-directory", "/tmp"]))
            }
        }
        for story in ScenarioRegistry.stories where story.id != "C04.12" {
            XCTAssertFalse(C0412FixtureLaunch.captureRequested(arguments:
                ["Watt", "--watt-fixture", story.id, "--watt-c0412-capture-directory", "/tmp"]))
        }
        for args in [[], ["--watt-c0412-capture-directory", "/tmp"],
                     ["--watt-fixture", "C04.12/unknown"],
                     ["--watt-fixture", "C04.12", "--watt-fixture", "C04.1"]] {
            XCTAssertFalse(C0412FixtureLaunch.matches(arguments: args))
        }
    }

    func testPublicLightAppearanceAndUnselectedNativeButton() throws {
        let item = NSStatusBar.system.statusItem(withLength: C0412FixtureLaunch.itemRect.width)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: C0412FixtureLaunch.appearanceName)
        XCTAssertEqual(button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .aqua)
        XCTAssertFalse(button.isHighlighted)
        XCTAssertNil(button.contentTintColor)
        let first = C0412FixtureLaunch.makeStore()
        let second = C0412FixtureLaunch.makeStore()
        XCTAssertNotEqual(first.generation, second.generation)
        XCTAssertEqual(first.currentReading, second.currentReading)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        XCTAssertEqual(PreferencesStore(storage: InMemoryStorage()).displayMode, .delta)
        XCTAssertEqual(C0412FixtureLaunch.captureSize, C041FixtureLaunch.captureSize)
    }
}
#endif

#if DEBUG
@MainActor
final class C05SettingsTests: XCTestCase {
    func testBaseFixtureDefaultsAndIsolation() throws {
        let first = C05FixtureLaunch.makePreferences()
        let second = C05FixtureLaunch.makePreferences()
        XCTAssertEqual(first.displayMode, .delta)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertEqual(first.selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(first.updateInterval, "Every 2 seconds")
        XCTAssertTrue(first.showSymbol && first.smoothReadings && first.componentReadings)
        XCTAssertTrue(first.chargerNotification && first.openAtLogin && first.checkForUpdatesAutomatically)
        XCTAssertFalse(first.fullyChargedNotification)
        first.showSymbol = false
        XCTAssertTrue(second.showSymbol)
        XCTAssertEqual(try ScenarioRegistry.resolve("C05").story.node, "25:787")
    }

    func testSettingsRoundTripAndMenuBarPrecision() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.precision = .whole
        preferences.showSymbol = false
        preferences.smoothReadings = false
        preferences.updateInterval = "Every 5 seconds"
        preferences.selectedComponents = ["CPU"]
        preferences.fullyChargedNotification = true
        preferences.chargerNotification = false
        preferences.openAtLogin = false
        preferences.checkForUpdatesAutomatically = false
        let loaded = PreferencesStore(storage: storage)
        XCTAssertEqual(loaded.precision, .whole)
        XCTAssertEqual(loaded.selectedComponents, ["CPU"])
        XCTAssertEqual(loaded.updateInterval, "Every 5 seconds")
        XCTAssertFalse(loaded.showSymbol || loaded.smoothReadings || loaded.chargerNotification
                       || loaded.openAtLogin || loaded.checkForUpdatesAutomatically)
        XCTAssertTrue(loaded.fullyChargedNotification)
        XCTAssertEqual(MenuBarStatusLabel(reading: .sampleCharging, preferences: loaded).text, "+42 W")
    }

    func testOldPreferencesWithoutPrecisionRemainReadable() throws {
        let storage = InMemoryStorage()
        let original = PreferencesStore(storage: storage)
        original.showSymbol = false
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(storage.values["preferences.v1"])) as? [String: Any])
        json.removeValue(forKey: "precision")
        storage.values["preferences.v1"] = try JSONSerialization.data(withJSONObject: json)
        let loaded = PreferencesStore(storage: storage)
        XCTAssertNil(loaded.persistenceFailure)
        XCTAssertEqual(loaded.precision, .decimal)
        XCTAssertFalse(loaded.showSymbol)
    }

    func testMissingRemovalCompositionFailsClosed() async {
        let outcome = await AppRouter().removeFromSettings(.helper)
        guard case .failed(.unknownStatus) = outcome else { return XCTFail("Must not report fictional removal") }
    }

    func testSettingsWindowIsNativeLightAndHasFullContent() {
        let window = C05FixtureLaunch.makeWindow()
        XCTAssertEqual(window.title, "Watt? Settings")
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.contentView?.frame.size, NSSize(width: 580, height: 1000))
    }

    func testFallbackMenuBarSettingsUsesDirectNativeSettingsSurface() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "router.present = { [weak self] destination in"))
        let end = try XCTUnwrap(source.range(of: "case .onboarding:", range: start.upperBound..<source.endIndex))
        let fallbackSettingsRoute = String(source[start.upperBound..<end.lowerBound])
        XCTAssertTrue(fallbackSettingsRoute.contains("self.closePanel()"))
        XCTAssertTrue(fallbackSettingsRoute.contains("SettingsRootView.title"))
        XCTAssertTrue(fallbackSettingsRoute.contains("WattSpacing.settingsWidth"))
        XCTAssertFalse(fallbackSettingsRoute.contains("NSApp.sendAction"))
    }

    func testSettingsUsesNativeControlsWithoutPaintedChrome() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
        for token in ["Form {", "Section", "Picker(", "Toggle(", "LabeledContent", ".buttonStyle(.bordered)", "role: .destructive", "WattSpacing.settingsWidth"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in [".preferredColorScheme(", "WattFormRow", "RoundedRectangle", "Gradient", "Capsule", "Spacer(", ".background", ".offset", ".padding"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }
}
#endif

#if DEBUG
@MainActor
final class J52FixtureTests: XCTestCase {
    func testExactBaseFixtureRegistrationAndLaunch() throws {
        let fixture = try ScenarioRegistry.resolve("J5.2")
        XCTAssertEqual(fixture.story.node, "30:4028")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertTrue(fixture.story.navigation.contains("Continue… → J1.2"))
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J5.2/base"]))
        XCTAssertEqual(try launch.smokeLaunchArguments(), ["--watt-fixture", "J5.2/base"])
        for variant in ["unavailable", "loading", "error", "unknown"] {
            let id = "J5.2/" + variant
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J5.2", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", id]))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", id]))
            #if !SWIFT_PACKAGE
            let selection = FixtureSelection(story: fixture.story, variant: variant)
            XCTAssertThrowsError(try FixtureLaunchSelection.story(selection).smokeLaunchArguments())
            #endif
        }
    }

    func testFixturePersistsIncompleteDefaultsAndExactReadingsInIsolatedStorage() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        J52FixtureLaunch.prepare(preferences: preferences)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.onboarding.checkpoint, .runningDefaults)
        XCTAssertFalse(restored.onboarding.completed)
        XCTAssertEqual(restored.displayMode, .delta)
        XCTAssertEqual(restored.precision, .decimal)
        XCTAssertFalse(restored.componentReadings)
        XCTAssertNil(restored.persistenceFailure)
        let other = PreferencesStore(storage: InMemoryStorage())
        J52FixtureLaunch.prepare(preferences: other)
        preferences.displayMode = .draw
        preferences.onboarding.checkpoint = .picker
        XCTAssertEqual(other.displayMode, .delta)
        XCTAssertEqual(other.onboarding.checkpoint, .runningDefaults)
        let store = PowerReadingStore.preview
        XCTAssertEqual(store.currentReading, .sampleCharging)
        let model = StatusPanelModel(reading: store.currentReading)
        XCTAssertEqual(model.charger, "65.0 W")
        XCTAssertEqual(model.system, "22.9 W")
        XCTAssertEqual(model.battery, "+42.1 W")
        XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(MenuBarStatusLabel(reading: store.currentReading, preferences: restored).text, "+42.1 W")
    }
}
#endif

#if DEBUG
@MainActor
final class J53FixtureTests: XCTestCase {
    func testExactBaseFixtureRegistrationAndLaunch() throws {
        let fixture = try ScenarioRegistry.resolve("J5.3")
        XCTAssertEqual(fixture.story.node, "30:4788")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.expectedScene, "contextMenu")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertTrue(fixture.story.navigation.contains("Finish Setup → J1.2"))
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        let launch = try XCTUnwrap(FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J5.3/base"]))
        XCTAssertEqual(try launch.smokeLaunchArguments(), ["--watt-fixture", "J5.3/base"])
        for variant in ["unavailable", "loading", "error", "unknown", "dark"] {
            let id = "J5.3/" + variant
            XCTAssertThrowsError(try ScenarioRegistry.resolve("J5.3", variant: variant))
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", id]))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["Watt", "--watt-fixture", id]))
            #if !SWIFT_PACKAGE
            let selection = FixtureSelection(story: fixture.story, variant: variant)
            XCTAssertThrowsError(try FixtureLaunchSelection.story(selection).smokeLaunchArguments())
            #endif
        }
    }

    func testFixturePersistsIncompleteDefaultsInIsolatedStorage() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        J53FixtureLaunch.prepare(preferences: preferences)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.onboarding.checkpoint, .runningDefaults)
        XCTAssertFalse(restored.onboarding.completed)
        XCTAssertEqual(restored.displayMode, .delta)
        XCTAssertEqual(restored.precision, .decimal)
        XCTAssertFalse(restored.componentReadings)
        XCTAssertNil(restored.persistenceFailure)
        let other = PreferencesStore(storage: InMemoryStorage())
        J53FixtureLaunch.prepare(preferences: other)
        preferences.displayMode = .draw
        preferences.onboarding.checkpoint = .picker
        XCTAssertEqual(other.displayMode, .delta)
        XCTAssertEqual(other.onboarding.checkpoint, .runningDefaults)
        let store = PowerReadingStore.preview
        XCTAssertEqual(store.currentReading, .sampleCharging)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        XCTAssertEqual(MenuBarStatusLabel(reading: store.currentReading, preferences: restored).text, "+42.1 W")
    }
}
#endif
