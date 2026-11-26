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
        accessibilityAnnouncement(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    func accessibilityAnnouncement(lowPowerMode: Bool) -> String {
        var parts = ["Watt?", accessibilityState]
        if let slot = percentageSlot, slot.standalone {
            parts.append(slot.spoken)
        } else {
            parts.append(spokenAccessibilityReading)
            if let slot = percentageSlot {
                parts.append(slot.spoken)
            }
        }
        if let spoken = batteryPresentation(lowPowerMode: lowPowerMode, symbolExists: { _ in true })?.tint.spoken {
            parts.append(spoken)
        }
        parts.append("menu extra.")
        return parts.joined(separator: ", ")
    }

    static let accessibilityHint = "Click for details. VO-Shift-M for options."

    /// The visual reading may change every sample; state transitions are the
    /// stable announcement boundary used by the native status-item bridge.
    var accessibilityStateKey: String {
        let base = [reading.mode.rawValue, reading.batteryState.rawValue,
                    reading.freshness.rawValue, reading.capabilities.battery.rawValue,
                    reading.capabilities.charger.rawValue].joined(separator: "|")
        // Defaults match the historical key. Extra segments appear only once a
        // battery menu-bar option is on, so VoiceOver hears Low Power Mode and
        // a low-battery color without announcing every percent tick.
        guard preferences.batteryPercentageStyle != .off || preferences.menuBarIcon != .bolt else {
            return base
        }
        let tint: String = switch batteryPresentation?.tint {
        case .lowPower: "low-power"
        case .lowBattery: "low-battery"
        case .template, nil: "template"
        }
        return [base, preferences.batteryPercentageStyle.rawValue,
                preferences.menuBarIcon.rawValue, tint].joined(separator: "|")
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
        if let batteryPresentation { return batteryPresentation.symbolName }
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

    /// Two-digit reserve for the reading that is actually on screen. One- and
    /// two-digit values share it. A three-digit integer is wider than it.
    var statusWidthReferences: [String] {
        switch effectiveMode {
        case .iconOnly:
            return []
        case .delta:
            return MenuBarStatusReserve.signed(precision: preferences.precision)
        case .charger, .draw:
            return MenuBarStatusReserve.unsigned(precision: preferences.precision)
        case .components:
            return MenuBarStatusReserve.components(
                labels: componentWidthLabels,
                precision: preferences.precision,
                sharesUnit: componentSharesUnit
            )
        }
    }

    func statusWidthIdentity(font: NSFont) -> MenuBarStatusWidthIdentity {
        MenuBarStatusWidthIdentity(
            mode: effectiveMode,
            precision: preferences.precision,
            unit: MenuBarStatusReserve.unit,
            fontName: font.fontName,
            fontSize: font.pointSize,
            components: effectiveMode == .components ? componentWidthLabels : [],
            componentSharesUnit: effectiveMode == .components && componentSharesUnit
        )
    }

    /// Names as the label prints them, so the reserve matches the live line.
    private var componentWidthLabels: [String] {
        preferences.selectedComponents.map { id in
            reading.components.first { $0.id.lowercased() == id.lowercased() }?.name ?? id
        }
    }

    /// A full per-component sample shares one unit. An empty sample reserves
    /// that same shape, so the item does not shrink while watts are missing
    /// and grow again when they return.
    private var componentSharesUnit: Bool {
        reading.mode == .perComponent || !reading.hasCurrentSample
    }

    @State private var storedReserve = ""
    @State private var storedWidthIdentity: MenuBarStatusWidthIdentity?

    private var measurementFont: NSFont { MenuBarStatusFont.swiftUILabel() }

    private var currentWidthIdentity: MenuBarStatusWidthIdentity {
        statusWidthIdentity(font: measurementFont)
    }

    /// Strings that compete for the text slot. SwiftUI lays them out and keeps
    /// the widest, so the slot matches the rendered reading rather than an inset.
    private var reserveCandidates: [String] {
        let displayed = text ?? ""
        var candidates = statusWidthReferences
        if !displayed.isEmpty { candidates.append(displayed) }
        if storedWidthIdentity == currentWidthIdentity, !storedReserve.isEmpty {
            candidates.append(storedReserve)
        }
        var unique: [String] = []
        for candidate in candidates where !unique.contains(candidate) {
            unique.append(candidate)
        }
        return unique
    }

    private var statusWidthToken: String {
        let identity = currentWidthIdentity
        return [
            identity.mode.rawValue,
            identity.precision.rawValue,
            identity.unit,
            identity.fontName,
            String(Double(identity.fontSize)),
            identity.componentSharesUnit ? "shared" : "separate",
            identity.components.joined(separator: "\u{1e}"),
            text ?? ""
        ].joined(separator: "\u{1f}")
    }

    private func rememberStatusWidth() {
        let identity = currentWidthIdentity
        let displayed = text ?? ""
        let references = statusWidthReferences
        let metrics = MenuBarFontMetrics.measuring(
            measurementFont,
            covering: [displayed, storedReserve] + references
        )
        let winner = MenuBarStatusWidth.widest(
            [displayed] + references + (storedWidthIdentity == identity ? [storedReserve] : []),
            metrics: metrics
        )
        if storedWidthIdentity != identity { storedWidthIdentity = identity }
        if storedReserve != winner { storedReserve = winner }
    }

    /// Charge from the same power-source reading the rest of the menu bar uses.
    /// Nil when the option is off, or this Mac has no battery.
    var percentageSlot: MenuBarPercentageSlot? {
        guard preferences.batteryPercentageStyle != .off else { return nil }
        guard MenuBarBatteryAvailability.isPresent(reading) else { return nil }
        let percentage = reading.batteryPercentage.flatMap { (0...100).contains($0) ? $0 : nil }
        return MenuBarPercentageSlot(
            visible: MenuBarPercentageSlot.visibleText(percentage: percentage),
            standalone: preferences.batteryPercentageStyle == .alone || text == nil
        )
    }

    /// Title the status item shows, including a charge percent when that option is on.
    /// Nil keeps `text`, so the watt reading stays available to a width reserve.
    var percentagePlainTitle: String? {
        guard let slot = percentageSlot else { return nil }
        if slot.standalone { return slot.visible }
        guard let text, !text.isEmpty else { return slot.visible }
        return text + slot.visibleText
    }

    var showsWattText: Bool { percentageSlot?.standalone != true }

    /// Extra width the status item adds so the percent occupies a "100%" slot.
    /// Zero when the percent is hidden. Independent of any watt-reading reserve.
    @MainActor
    func percentageSlotSlack(font: NSFont) -> CGFloat {
        percentageSlot?.slack(font: font) ?? 0
    }

    /// Battery icon for the current reading. Nil keeps the bolt glyph, including
    /// on a Mac with no battery.
    var batteryPresentation: MenuBarBatteryPresentation? {
        batteryPresentation(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                            symbolExists: { MenuBarBatteryPresentation.systemSymbolExists($0) })
    }

    func batteryPresentation(
        lowPowerMode: Bool,
        symbolExists: @MainActor (String) -> Bool
    ) -> MenuBarBatteryPresentation? {
        guard preferences.menuBarIcon == .battery else { return nil }
        guard MenuBarBatteryAvailability.isPresent(reading) else { return nil }
        return MenuBarBatteryPresentation.resolve(
            percentage: reading.batteryPercentage,
            state: reading.batteryState,
            charger: reading.capabilities.charger,
            lowPowerMode: lowPowerMode,
            symbolExists: symbolExists
        )
    }

    @MainActor
    func batteryStatusBarImage() -> NSImage? {
        batteryPresentation?.makeImage()
    }

    var body: some View {
        // The status item stays visible while the panel is closed. Leave the
        // text and symbol unanimated so samples cannot tick, jitter, or change
        // the item width. Production assigns this string to NSStatusBarButton.
        Group {
            if effectiveMode == .iconOnly && percentageSlot == nil && batteryPresentation == nil {
                // A single template SF Symbol lets MenuBarExtra own all native metrics.
                Image(systemName: symbolName)
                    .renderingMode(.template)
            } else if effectiveMode == .iconOnly && percentageSlot == nil, let presentation = batteryPresentation {
                MenuBarBatteryIcon(presentation: presentation)
            } else {
                HStack(spacing: WattSpacing.xs) {
                    if showsSymbol {
                        if let presentation = batteryPresentation {
                            MenuBarBatteryIcon(presentation: presentation)
                        } else {
                            Image(systemName: symbolName)
                        }
                    }
                    if showsWattText, let text {
                        // The hidden reading is the two-digit reserve (or the
                        // session high-water). Live text is centred in that
                        // slot, so a shorter value does not shrink the item.
                        ZStack(alignment: .center) {
                            ForEach(reserveCandidates, id: \.self) { candidate in
                                Text(candidate)
                                    .hidden()
                                    .accessibilityHidden(true)
                            }
                            Text(text)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    if let percentageSlot {
                        MenuBarPercentageSlotView(slot: percentageSlot)
                    }
                }
                .font(WattTypography.bodyEmphasized)
                .monospacedDigit()
                .onAppear(perform: rememberStatusWidth)
                .onChange(of: statusWidthToken) { _ in rememberStatusWidth() }
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
