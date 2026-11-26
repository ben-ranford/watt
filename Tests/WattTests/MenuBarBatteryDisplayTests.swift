import AppKit
import IOKit.ps
import SwiftUI
import XCTest
@testable import Watt

/// Battery percentage and the battery icon are off until someone turns them on.
/// These cases lock the intended menu-bar behaviour: formatting, the "100%" slot,
/// the glyph for each charge and charging state, and the bolt on a Mac with no battery.
@MainActor
final class MenuBarBatteryDisplayTests: XCTestCase {
    func testDefaultsAreOffAndUseTheBolt() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        XCTAssertEqual(preferences.batteryPercentageStyle, .off)
        XCTAssertEqual(preferences.menuBarIcon, .bolt)
        XCTAssertEqual(MenuBarBatteryPercentageStyle.allCases.map(\.title), ["Off", "With the reading", "On its own"])
        XCTAssertEqual(MenuBarIconChoice.allCases.map(\.title), ["Bolt", "Battery"])

        let label = MenuBarStatusLabel(reading: draw(percentage: 87), preferences: preferences)
        XCTAssertNil(label.percentageSlot)
        XCTAssertNil(label.percentagePlainTitle)
        XCTAssertEqual(label.text, "12.3 W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        XCTAssertEqual(label.accessibilityAnnouncement, "Watt?, on battery, 12.3 watts, menu extra.")
        XCTAssertEqual(label.accessibilityStateKey, "systemDraw|discharging|fresh|available|disconnected")
    }

    func testPreferencesSavedBeforeTheseOptionsStayOff() throws {
        let storage = InMemoryStorage()
        let legacy = """
        {"displayMode":"Draw","showSymbol":true,"updateInterval":"Every 2 seconds","smoothReadings":true,"componentReadings":true,"chargerNotification":true,"fullyChargedNotification":false,"openAtLogin":false,"checkForUpdatesAutomatically":true,"selectedComponents":["CPU","GPU"],"onboarding":{"checkpoint":"welcome","completed":false,"helperOptIn":false}}
        """
        storage.values["preferences.v1"] = Data(legacy.utf8)
        let restored = PreferencesStore(storage: storage)
        XCTAssertNil(restored.persistenceFailure)
        XCTAssertEqual(restored.displayMode, .draw)
        XCTAssertEqual(restored.batteryPercentageStyle, .off)
        XCTAssertEqual(restored.menuBarIcon, .bolt)
    }

    func testBatteryMenuChoicesRoundTrip() {
        let storage = InMemoryStorage()
        let first = PreferencesStore(storage: storage)
        first.batteryPercentageStyle = .alone
        first.menuBarIcon = .battery
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.batteryPercentageStyle, .alone)
        XCTAssertEqual(restored.menuBarIcon, .battery)
        XCTAssertNil(restored.persistenceFailure)

        restored.batteryPercentageStyle = .off
        restored.menuBarIcon = .bolt
        let cleared = PreferencesStore(storage: storage)
        XCTAssertEqual(cleared.batteryPercentageStyle, .off)
        XCTAssertEqual(cleared.menuBarIcon, .bolt)
    }

    func testPercentageAppendsToTheReading() {
        let label = label(style: .withReading, percentage: 87)
        XCTAssertEqual(label.text, "12.3 W")
        XCTAssertEqual(label.percentagePlainTitle, "12.3 W · 87%")
        XCTAssertEqual(label.percentageSlot?.visible, "87%")
        XCTAssertEqual(label.percentageSlot?.standalone, false)
        XCTAssertEqual(label.percentageSlot?.reserveText, " · 100%")
        XCTAssertTrue(label.showsWattText)
    }

    func testPercentageCanReplaceTheReading() {
        let label = label(style: .alone, percentage: 87)
        XCTAssertEqual(label.text, "12.3 W")
        XCTAssertEqual(label.percentagePlainTitle, "87%")
        XCTAssertEqual(label.percentageSlot?.standalone, true)
        XCTAssertEqual(label.percentageSlot?.reserveText, "100%")
        XCTAssertFalse(label.showsWattText)

        let iconOnly = label(style: .withReading, percentage: 64, mode: .iconOnly)
        XCTAssertNil(iconOnly.text)
        XCTAssertEqual(iconOnly.percentagePlainTitle, "64%")
        XCTAssertEqual(iconOnly.percentageSlot?.standalone, true)
    }

    func testMissingPercentageKeepsTheSlot() {
        let label = label(style: .withReading, percentage: nil)
        XCTAssertEqual(label.percentagePlainTitle, "12.3 W · —")
        XCTAssertEqual(label.percentageSlot?.spoken, "charge unavailable")
        XCTAssertEqual(label.percentageSlot?.reserveText, " · 100%")
    }

    func testPercentageSlotIsWideEnoughFor100Percent() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let narrow = ("9%" as NSString).size(withAttributes: attributes).width
        let wide = ("100%" as NSString).size(withAttributes: attributes).width
        XCTAssertLessThan(narrow, wide, "Tabular digits still change width when the digit count changes")

        func reserved(percent: Int, standalone: Bool) -> CGFloat {
            let visible = "\(percent)%"
            let slot = MenuBarPercentageSlot(visible: visible, standalone: standalone)
            let shown = (slot.visibleText as NSString).size(withAttributes: attributes).width
            return shown + slot.slack(font: font)
        }
        for standalone in [true, false] {
            let widths = [9, 87, 100].map { reserved(percent: $0, standalone: standalone) }
            XCTAssertEqual(widths[0], widths[2], accuracy: 0.5, "\(standalone)")
            XCTAssertEqual(widths[1], widths[2], accuracy: 0.5, "\(standalone)")
        }

        // Same rule the status item uses: measured title plus the percent slack.
        func itemLength(percent: Int) -> CGFloat {
            let title = "12.3 W · \(percent)%"
            let intrinsic = (title as NSString).size(withAttributes: attributes).width
            let slot = MenuBarPercentageSlot(visible: "\(percent)%", standalone: false)
            return max(42, intrinsic + 12 + slot.slack(font: font))
        }
        XCTAssertEqual(itemLength(percent: 9), itemLength(percent: 87), accuracy: 1)
        XCTAssertEqual(itemLength(percent: 87), itemLength(percent: 100), accuracy: 1)
        let shortTitle = ("12.3 W · 9%" as NSString).size(withAttributes: attributes).width
        let fullTitle = ("12.3 W · 100%" as NSString).size(withAttributes: attributes).width
        XCTAssertLessThan(shortTitle, fullTitle)
        XCTAssertEqual(itemLength(percent: 9), max(42, fullTitle + 12), accuracy: 1)
    }

    func testMenuBarLabelSlotDoesNotChangeWidthAcrossPercentages() {
        let widths = [9, 87, 100].map { fittedWidth(percentage: $0, style: .withReading) }
        XCTAssertGreaterThan(widths[0], 20)
        XCTAssertEqual(widths[0], widths[1], accuracy: 1)
        XCTAssertEqual(widths[1], widths[2], accuracy: 1)

        let alone = [9, 87, 100].map { fittedWidth(percentage: $0, style: .alone) }
        XCTAssertEqual(alone[0], alone[1], accuracy: 1)
        XCTAssertEqual(alone[1], alone[2], accuracy: 1)
    }

    func testVariableSymbolTracksChargeAndChargingState() {
        let symbols: Set<String> = ["battery.100percent", "battery.100percent.bolt", "battery.100", "battery.100.bolt"]
        func presentation(_ percentage: Int, state: BatteryState, charger: Capability = .disconnected, lowPower: Bool = false) -> MenuBarBatteryPresentation {
            MenuBarBatteryPresentation.resolve(
                percentage: percentage, state: state, charger: charger, lowPowerMode: lowPower,
                symbolExists: { symbols.contains($0) })
        }

        for percentage in [0, 9, 20, 21, 25, 50, 87, 100] {
            let symbol = presentation(percentage, state: .discharging)
            XCTAssertEqual(symbol.symbolName, "battery.100percent", "\(percentage)")
            XCTAssertEqual(symbol.variableValue ?? -1, Double(percentage) / 100, accuracy: 0.0001, "\(percentage)")
        }
        XCTAssertEqual(presentation(9, state: .discharging).tint, .lowBattery)
        XCTAssertEqual(presentation(20, state: .discharging).tint, .lowBattery)
        XCTAssertEqual(presentation(21, state: .discharging).tint, .template)

        for state in [BatteryState.charging, .chargingHold, .full] {
            let symbol = presentation(42, state: state, charger: .available)
            XCTAssertEqual(symbol.symbolName, "battery.100percent.bolt", "\(state)")
            XCTAssertEqual(symbol.variableValue ?? -1, 0.42, accuracy: 0.0001, "\(state)")
            XCTAssertEqual(symbol.tint, .template, "\(state)")
        }
        let chargingLow = presentation(10, state: .charging, charger: .available)
        XCTAssertEqual(chargingLow.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(chargingLow.tint, .template, "Plugged in stays untinted below 20%")

        let drainingOnCharger = presentation(40, state: .discharging, charger: .available)
        XCTAssertEqual(drainingOnCharger.symbolName, "battery.100percent", "A charger that cannot keep up is not charging")
        XCTAssertEqual(presentation(15, state: .unknown, charger: .available).symbolName, "battery.100percent.bolt")
        XCTAssertEqual(presentation(15, state: .unknown, charger: .disconnected).symbolName, "battery.100percent")

        let lowPower = presentation(10, state: .discharging, lowPower: true)
        XCTAssertEqual(lowPower.tint, .lowPower)
        XCTAssertEqual(lowPower.symbolName, "battery.100percent")
        XCTAssertEqual(presentation(80, state: .charging, charger: .available, lowPower: true).tint, .lowPower)

        let missing = MenuBarBatteryPresentation.resolve(
            percentage: nil, state: .discharging, charger: .disconnected, lowPowerMode: false,
            symbolExists: { symbols.contains($0) })
        XCTAssertEqual(missing.symbolName, "bolt.fill")
        XCTAssertNil(missing.variableValue)
        XCTAssertEqual(missing.tint, .template)
    }

    func testQuarterSymbolsWhenTheVariableSymbolIsMissing() {
        let quarters = ["battery.0percent", "battery.25percent", "battery.50percent", "battery.75percent"]
        func presentation(_ percentage: Int, state: BatteryState = .discharging) -> MenuBarBatteryPresentation {
            MenuBarBatteryPresentation.resolve(
                percentage: percentage, state: state, charger: .disconnected, lowPowerMode: false,
                symbolExists: { quarters.contains($0) })
        }
        let expected: [(Int, String)] = [
            (0, "battery.0percent"), (12, "battery.0percent"),
            (13, "battery.25percent"), (25, "battery.25percent"), (37, "battery.25percent"),
            (38, "battery.50percent"), (50, "battery.50percent"), (62, "battery.50percent"),
            (63, "battery.75percent"), (75, "battery.75percent"), (87, "battery.75percent")
        ]
        for (percentage, name) in expected {
            let symbol = presentation(percentage)
            XCTAssertEqual(symbol.symbolName, name, "\(percentage)")
            XCTAssertNil(symbol.variableValue, "\(percentage)")
            XCTAssertEqual(MenuBarBatteryPresentation.quarter(for: percentage),
                           Int(name.dropFirst("battery.".count).dropLast("percent".count)))
        }
        let full = presentation(88)
        XCTAssertEqual(full.symbolName, "battery.100percent")
        XCTAssertNil(full.variableValue)
        XCTAssertEqual(MenuBarBatteryPresentation.quarter(for: 100), 100)

        let legacy = MenuBarBatteryPresentation.resolve(
            percentage: 40, state: .discharging, charger: .disconnected, lowPowerMode: false,
            symbolExists: { ["battery.0", "battery.25", "battery.50", "battery.75", "battery.100"].contains($0) })
        XCTAssertEqual(legacy.symbolName, "battery.50")
        XCTAssertNil(legacy.variableValue)

        let charging = presentation(40, state: .charging)
        XCTAssertEqual(charging.symbolName, "battery.50percent")
        XCTAssertNil(charging.variableValue)
        let charged = MenuBarBatteryPresentation.resolve(
            percentage: 100, state: .full, charger: .available, lowPowerMode: false,
            symbolExists: { $0 == "battery.100" || $0 == "battery.100.bolt" })
        XCTAssertEqual(charged.symbolName, "battery.100.bolt")
        XCTAssertEqual(charged.variableValue ?? -1, 1, accuracy: 0.0001)
    }

    func testBoltChoiceKeepsTheExistingGlyph() {
        var preferences = self.preferences(style: .off, icon: .bolt, mode: .delta)
        let discharging = onBattery(percentage: 64)
        let bolt = MenuBarStatusLabel(reading: discharging, preferences: preferences)
        XCTAssertEqual(bolt.symbolName, "battery.100percent")
        XCTAssertNil(bolt.batteryPresentation(lowPowerMode: false, symbolExists: { _ in true }))

        preferences.menuBarIcon = .battery
        let battery = MenuBarStatusLabel(reading: discharging, preferences: preferences)
        let symbol = battery.batteryPresentation(lowPowerMode: false, symbolExists: { $0 == "battery.100percent" })
        XCTAssertEqual(symbol?.symbolName, "battery.100percent")
        XCTAssertEqual(symbol?.variableValue ?? -1, 0.64, accuracy: 0.0001)
        XCTAssertEqual(battery.symbolName.isEmpty, false)
        XCTAssertNotNil(NSImage(systemSymbolName: battery.symbolName, accessibilityDescription: nil))
    }

    func testMacWithoutABatteryKeepsTheBoltAndHidesTheOptions() {
        for reading in [desktop(), unsupportedBattery()] {
            XCTAssertFalse(MenuBarBatteryAvailability.isPresent(reading))
            let preferences = preferences(style: .withReading, icon: .battery)
            let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
            XCTAssertNil(label.percentageSlot)
            XCTAssertNil(label.percentagePlainTitle)
            XCTAssertNil(label.batteryPresentation(lowPowerMode: true, symbolExists: { _ in true }))
            XCTAssertEqual(label.symbolName, "bolt.fill")
            XCTAssertFalse(label.accessibilityAnnouncement.contains("percent"))
        }
        XCTAssertTrue(MenuBarBatteryAvailability.isPresent(draw(percentage: 50)))
        XCTAssertTrue(MenuBarBatteryAvailability.isPresent(draw(percentage: nil, state: .unknown, battery: .unknown)))
    }

    func testVoiceOverReadsThePercentageAndChargingState() {
        let appended = label(style: .withReading, percentage: 87)
        XCTAssertEqual(appended.accessibilityAnnouncement,
                       "Watt?, on battery, 12.3 watts, 87 percent, menu extra.")
        let alone = label(style: .alone, percentage: 87)
        XCTAssertEqual(alone.accessibilityAnnouncement, "Watt?, on battery, 87 percent, menu extra.")

        var chargingPreferences = preferences(style: .withReading, icon: .bolt, mode: .draw)
        let charging = MenuBarStatusLabel(reading: chargingDraw(percentage: 64), preferences: chargingPreferences)
        XCTAssertEqual(charging.accessibilityAnnouncement,
                       "Watt?, charging, 12.3 watts, 64 percent, menu extra.")
        XCTAssertEqual(charging.accessibilityStateKey.contains("withReading"), true)

        chargingPreferences.menuBarIcon = .battery
        chargingPreferences.batteryPercentageStyle = .alone
        let lowPower = MenuBarStatusLabel(reading: draw(percentage: 15), preferences: chargingPreferences)
        XCTAssertEqual(lowPower.accessibilityAnnouncement(lowPowerMode: true),
                       "Watt?, on battery, 15 percent, Low Power Mode, menu extra.")
        XCTAssertEqual(lowPower.accessibilityAnnouncement(lowPowerMode: false),
                       "Watt?, on battery, 15 percent, menu extra.")
        XCTAssertFalse(lowPower.accessibilityAnnouncement(lowPowerMode: false).contains("Low Power Mode"))
    }

    func testParsedPowerSourceDrivesTheMenuBarSymbol() throws {
        let charging = try SystemPowerSourceParser.parse(.init(
            descriptions: [battery(charging: true, percentage: 87)],
            providingSource: kIOPSACPowerValue,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": 12_300, "SystemPowerIn": 30_000, "SystemLoad": 17_700
            ]]))
        XCTAssertEqual(charging.batteryState, .charging)
        XCTAssertEqual(charging.batteryPercentage, 87)
        XCTAssertEqual(charging.capabilities.battery, .available)
        let chargingSymbol = MenuBarBatteryPresentation.resolve(
            percentage: charging.batteryPercentage, state: charging.batteryState,
            charger: charging.capabilities.charger, lowPowerMode: false,
            symbolExists: { $0 == "battery.100percent.bolt" || $0 == "battery.100percent" })
        XCTAssertEqual(chargingSymbol.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(chargingSymbol.variableValue ?? -1, 0.87, accuracy: 0.0001)

        let draining = try SystemPowerSourceParser.parse(.init(
            descriptions: [battery(charging: false, percentage: 15)],
            providingSource: kIOPSBatteryPowerValue,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            batteryProperties: ["PowerTelemetryData": ["SystemLoad": 18_400, "BatteryPower": 18_400]]))
        XCTAssertEqual(draining.batteryState, .discharging)
        XCTAssertEqual(draining.batteryPercentage, 15)
        XCTAssertEqual(draining.capabilities.charger, .disconnected)
        let drainingSymbol = MenuBarBatteryPresentation.resolve(
            percentage: draining.batteryPercentage, state: draining.batteryState,
            charger: draining.capabilities.charger, lowPowerMode: false,
            symbolExists: { $0 == "battery.100percent" })
        XCTAssertEqual(drainingSymbol.symbolName, "battery.100percent")
        XCTAssertEqual(drainingSymbol.variableValue ?? -1, 0.15, accuracy: 0.0001)
        XCTAssertEqual(drainingSymbol.tint, .lowBattery)
    }

    func testChosenSymbolsExistOnThisSystem() {
        let cases: [(Int, BatteryState, Capability)] = [
            (0, .discharging, .disconnected),
            (25, .discharging, .disconnected),
            (87, .discharging, .disconnected),
            (100, .full, .available),
            (42, .charging, .available)
        ]
        for (percentage, state, charger) in cases {
            let symbol = MenuBarBatteryPresentation.resolve(
                percentage: percentage, state: state, charger: charger, lowPowerMode: false,
                symbolExists: { MenuBarBatteryPresentation.systemSymbolExists($0) })
            XCTAssertNotNil(symbol.makeImage(), "\(percentage) \(state)")
            XCTAssertNotNil(NSImage(systemSymbolName: symbol.symbolName, accessibilityDescription: nil), symbol.symbolName)
        }
    }

    func testLowBatteryImageIsNotATemplate() {
        guard MenuBarBatteryPresentation.systemSymbolExists("battery.100percent") else { return }
        let low = MenuBarBatteryPresentation(symbolName: "battery.100percent", variableValue: 0.15, tint: .lowBattery)
        XCTAssertEqual(low.makeImage()?.isTemplate, false)
        let normal = MenuBarBatteryPresentation(symbolName: "battery.100percent", variableValue: 0.8, tint: .template)
        XCTAssertEqual(normal.makeImage()?.isTemplate, true)
        let yellow = MenuBarBatteryPresentation(symbolName: "battery.100percent", variableValue: 0.4, tint: .lowPower)
        XCTAssertEqual(yellow.makeImage()?.isTemplate, false)
    }

    func testSettingsOffersTheControlsOnlyWhenABatteryIsPresent() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"),
            encoding: .utf8)
        for text in [
            "Picker(\"Show battery percentage\"",
            "Picker(\"Menu bar icon\"",
            "Text(style.title).tag(style)",
            "Text(choice.title).tag(choice)",
            "MenuBarBatteryAvailability.isPresent(powerStore.currentReading)",
            ".accessibilityIdentifier(\"settings.batteryPercentage\")",
            ".accessibilityIdentifier(\"settings.menuBarIcon\")",
            "Adds the charge next to the reading, or shows only the charge.",
            "Battery follows the charge."
        ] {
            XCTAssertTrue(source.contains(text), text)
        }
        let menu = try XCTUnwrap(source.range(of: "Picker(\"Precision\""))
        XCTAssertLessThan(menu.lowerBound, try XCTUnwrap(source.range(of: "Picker(\"Show battery percentage\"")).lowerBound)
    }

    func testRendersMenuBarBatteryModes() throws {
        let export = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("site-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        let charging = chargingDraw(percentage: 64)
        let low = draw(percentage: 15, state: .discharging)
        var saved: [String: Data] = [:]
        saved["menu-bar-battery-with-reading"] = try render(label(style: .withReading, percentage: 87))
        saved["menu-bar-battery-percent-only"] = try render(label(style: .alone, percentage: 87, icon: .battery))
        saved["menu-bar-battery-charging"] = try render(
            MenuBarStatusLabel(reading: charging, preferences: preferences(style: .withReading, icon: .battery, mode: .draw)))
        saved["menu-bar-battery-low"] = try render(
            MenuBarStatusLabel(reading: low, preferences: preferences(style: .alone, icon: .battery, mode: .draw)))
        saved["menu-bar-battery-low-power"] = try render(
            MenuBarBatteryIcon(presentation: MenuBarBatteryPresentation(
                symbolName: "battery.100percent", variableValue: 0.4, tint: .lowPower)))
        for (name, data) in saved {
            XCTAssertGreaterThan(data.count, 32, name)
            try data.write(to: export.appendingPathComponent(name + ".png"))
        }
    }

    private func preferences(style: MenuBarBatteryPercentageStyle, icon: MenuBarIconChoice = .bolt,
                             mode: WattDisplayMode = .draw) -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = mode
        preferences.precision = .decimal
        preferences.showSymbol = true
        preferences.batteryPercentageStyle = style
        preferences.menuBarIcon = icon
        return preferences
    }

    private func label(style: MenuBarBatteryPercentageStyle, percentage: Int?, icon: MenuBarIconChoice = .bolt,
                       mode: WattDisplayMode = .draw) -> MenuBarStatusLabel {
        MenuBarStatusLabel(reading: draw(percentage: percentage), preferences: preferences(style: style, icon: icon, mode: mode))
    }

    private func draw(percentage: Int?, state: BatteryState = .discharging,
                      battery: Capability = .available, charger: Capability = .disconnected,
                      systemWatts: Double? = 12.3) -> PowerReading {
        PowerReading(mode: .systemDraw, watts: nil, batteryPercentage: percentage,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: state,
                     capabilities: .init(battery: battery, charger: charger,
                                         systemDraw: systemWatts == nil ? .unsupported : .available),
                     source: .fixture, systemWatts: systemWatts)
    }

    private func chargingDraw(percentage: Int) -> PowerReading {
        PowerReading(mode: .systemDraw, watts: nil, batteryPercentage: percentage,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .charging,
                     capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                     source: .fixture, chargerWatts: 30, systemWatts: 12.3)
    }

    private func onBattery(percentage: Int) -> PowerReading {
        PowerReading(mode: .onBattery, watts: -18.4, batteryPercentage: percentage,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .discharging,
                     capabilities: .init(battery: .available, charger: .disconnected, systemDraw: .available),
                     source: .fixture, systemWatts: 18.4)
    }

    private func desktop() -> PowerReading {
        PowerReading(mode: .systemDraw, watts: nil, batteryPercentage: nil,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .noBattery,
                     capabilities: .init(battery: .unsupported, charger: .unsupported, systemDraw: .available),
                     source: .fixture, systemWatts: 38.2)
    }

    private func unsupportedBattery() -> PowerReading {
        PowerReading(mode: .systemDraw, watts: nil,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .unknown,
                     capabilities: .init(battery: .unsupported, charger: .unsupported, systemDraw: .available),
                     source: .fixture, systemWatts: 38.2)
    }

    private func battery(charging: Bool, percentage: Int) -> [String: Any] {
        let maximum = 100
        return [
            kIOPSTypeKey: kIOPSInternalBatteryType,
            kIOPSIsPresentKey: true,
            kIOPSIsChargingKey: charging,
            kIOPSIsChargedKey: false,
            kIOPSPowerSourceStateKey: charging ? kIOPSACPowerValue : kIOPSBatteryPowerValue,
            kIOPSCurrentCapacityKey: percentage,
            kIOPSMaxCapacityKey: maximum
        ]
    }

    private func fittedWidth(percentage: Int, style: MenuBarBatteryPercentageStyle) -> CGFloat {
        let host = NSHostingView(rootView: label(style: style, percentage: percentage)
            .fixedSize())
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.width
    }

    private func render<V: View>(_ view: V) throws -> Data {
        let host = NSHostingView(rootView: view
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .fixedSize()
            .background(Color(nsColor: .windowBackgroundColor)))
        let fitted = host.fittingSize
        let size = CGSize(width: max(fitted.width, 24), height: max(fitted.height, 24))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "Watt", code: 1)
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        window.orderOut(nil)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Watt", code: 2)
        }
        return data
    }
}
