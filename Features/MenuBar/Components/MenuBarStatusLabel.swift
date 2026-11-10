import AppKit
import Foundation
import SwiftUI

struct MenuBarStatusLabel: View {
    let reading: PowerReading
    @ObservedObject var preferences: PreferencesStore

    var helperSwitchedOff = false
    private var effectiveMode: WattDisplayMode { helperSwitchedOff ? .delta : preferences.displayMode }

    var text: String? {
        switch effectiveMode {
        case .iconOnly: return nil
        case .components:
            guard preferences.componentReadings, reading.hasCurrentSample,
                  reading.capabilities.components == .available,
                  (try? reading.validate()) != nil else { return "—" }
            let values = preferences.selectedComponents.map { id in
                let component = reading.components.first { $0.id.lowercased() == id.lowercased() }
                return "\(component?.name ?? id) \(PowerFormatter.watts(component?.watts, signed: false, precision: preferences.precision))"
            }
            // C04.7 shares one unit only for an explicit per-component state.
            // Keep legacy charging/C03 and partially unavailable formatting intact.
            if reading.mode == .perComponent, !values.isEmpty,
               values.allSatisfy({ $0.hasSuffix(" W") }) {
                return values.map { String($0.dropLast(2)) }.joined(separator: " · ") + " W"
            }
            return values.isEmpty ? "—" : values.joined(separator: " · ")
        case .delta, .charger, .draw:
            if effectiveMode == .delta, reading.mode == .noReading { return NoReadingPresentation.value }
            if reading.batteryState == .discharging {
                guard reading.freshness == .fresh, (try? reading.validate()) != nil else { return "—" }
            }
            // C04.9/J8.1 retain the unit for the explicit no-reading state.
            let formatted = PowerFormatter.watts(reading.value(for: effectiveMode, chargerFallback: chargerFallback),
                                                 signed: effectiveMode == .delta, precision: preferences.precision)
            // C04.2 uses the typographic minus, without changing shared formatting.
            return isBatteryDischargingDelta ? formatted.replacingOccurrences(of: "-", with: "−") : formatted
        }
    }

    var accessibilityReading: String {
        guard let text else {
            guard hasCurrentIconReading, let watts = reading.value(for: .delta) else { return "No reading yet" }
            return PowerFormatter.watts(watts, signed: true, precision: preferences.precision)
                .replacingOccurrences(of: "-", with: "−")
                .replacingOccurrences(of: " W", with: " watts")
        }
        return (text == "—" || text == "− − W") ? "No reading yet" : text.replacingOccurrences(of: " W", with: " watts")
    }

    /// The status item is one VoiceOver element. Keep the state and reading in
    /// the label so the menu-extra announcement is not split across nested
    /// SwiftUI text nodes.
    var accessibilityAnnouncement: String {
        "Watt?, \(accessibilityState), \(spokenAccessibilityReading), menu extra."
    }

    static let accessibilityHint = "Click for details. VO-Shift-M for options."

    /// The visual reading may change every sample; state transitions are the
    /// stable announcement boundary used by the native status-item bridge.
    var accessibilityStateKey: String {
        [reading.mode.rawValue, reading.batteryState.rawValue,
         reading.freshness.rawValue, reading.capabilities.battery.rawValue,
         reading.capabilities.charger.rawValue].joined(separator: "|")
    }

    private var accessibilityState: String {
        switch reading.batteryState {
        case .charging: return "charging"
        case .discharging: return "on battery"
        case .chargingHold: return "charging paused"
        case .full: return "fully charged"
        case .noBattery: return "no battery"
        case .unknown: return "power"
        }
    }

    private var spokenAccessibilityReading: String {
        let value = accessibilityReading
        if value.hasPrefix("+") { return "plus " + value.dropFirst() }
        if value.hasPrefix("−") || value.hasPrefix("-") { return "minus " + value.dropFirst() }
        return value
    }

    private var hasCurrentIconReading: Bool {
        reading.hasCurrentSample && reading.capabilities.battery == .available
    }

    private var isAvailableBatteryDelta: Bool {
        effectiveMode == .delta && reading.hasCurrentSample && reading.capabilities.battery == .available
            && (reading.batteryState != .discharging ||
                (reading.freshness == .fresh && reading.watts != nil && (try? reading.validate()) != nil))
    }

    private var isBatteryDischargingDelta: Bool {
        isAvailableBatteryDelta && reading.batteryState == .discharging
    }

    /// The live system adapter reports an unplugged Mac as `.onBattery`, while
    /// the explicit Charger display still needs the measured system draw when
    /// charger input is unavailable. Keep fixture/legacy battery-delta callers
    /// unchanged; only a fresh system sample opts into this presentation.
    private var usesDisconnectedChargerFallback: Bool {
        effectiveMode == .charger
            && reading.capabilities.charger == .disconnected
            && (reading.mode == .chargerInput
                || (reading.source == .system && reading.batteryState == .discharging))
    }

    private var chargerFallback: ChargerFallbackPolicy {
        usesDisconnectedChargerFallback ? .systemDrawWhenDisconnected : .batteryDelta
    }

    var symbolName: String {
        // Icon Only is a production preference, with the same physical-state semantics
        // for system/helper readings and fixtures. Unknown or stale data stays generic.
        if effectiveMode == .iconOnly {
            guard hasCurrentIconReading else { return "bolt.fill" }
            if [.charging, .chargingHold, .full].contains(reading.batteryState),
               reading.capabilities.charger == .available {
                return "battery.100percent.bolt"
            }
            return reading.batteryState == .discharging ? "battery.100percent" : "bolt.fill"
        }
        // Charging and full states use the bolt glyph. Discharging uses the battery glyph.
        if isAvailableBatteryDelta && (reading.batteryState == .charging
            || ([BatteryState.full, .chargingHold].contains(reading.batteryState)
                && reading.capabilities.charger == .available)) {
            return "battery.100percent.bolt"
        }
        if usesDisconnectedChargerFallback && reading.source != .unavailable && reading.freshness == .fresh {
            return "battery.100percent"
        }
        if isBatteryDischargingDelta { return "battery.100percent" }
        return "bolt.fill"
    }

    var showsSymbol: Bool { preferences.showSymbol || effectiveMode == .iconOnly }

    var body: some View {
        Group {
            if effectiveMode == .iconOnly {
                // A single template SF Symbol lets MenuBarExtra own all native metrics.
                Image(systemName: symbolName)
                    .renderingMode(.template)
            } else {
                HStack(spacing: WattSpacing.xs) {
                    if showsSymbol {
                        Image(systemName: symbolName)
                    }
                    if let text { Text(text) }
                }
                .font(WattTypography.bodyEmphasized)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityAnnouncement)
        .accessibilityHint(Self.accessibilityHint)
    }
}

/// AppKit owns the status-item element. SwiftUI supplies the content, while
/// this bridge keeps the host element's AX copy identical to the label view.
@MainActor
enum MenuBarStatusAccessibility {
    static func apply(to button: NSStatusBarButton, label: MenuBarStatusLabel) {
        button.setAccessibilityLabel(label.accessibilityAnnouncement)
        button.setAccessibilityHelp(MenuBarStatusLabel.accessibilityHint)
        // The announcement is intentionally a single label; an additional AX
        // value would cause VoiceOver to repeat the wattage.
        button.setAccessibilityValue(nil)
    }
}

struct MenuBarAccessibilityAnnouncementGate: Equatable {
    static let maximumInterval: TimeInterval = 30
    private var lastStateKey: String?
    private var lastAnnouncementAt: Date?

    mutating func shouldAnnounce(stateKey: String, now: Date) -> Bool {
        guard let lastStateKey, let lastAnnouncementAt else {
            self.lastStateKey = stateKey
            self.lastAnnouncementAt = now
            return true
        }
        guard lastStateKey != stateKey || now.timeIntervalSince(lastAnnouncementAt) >= Self.maximumInterval else {
            return false
        }
        self.lastStateKey = stateKey
        self.lastAnnouncementAt = now
        return true
    }
}
