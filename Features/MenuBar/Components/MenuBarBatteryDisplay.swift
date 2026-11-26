import AppKit
import SwiftUI

/// A Mac has a battery when the power-source reading says so.
/// Desktop machines report no battery, or a battery the hardware does not support.
enum MenuBarBatteryAvailability {
    static func isPresent(_ reading: PowerReading) -> Bool {
        reading.batteryState != .noBattery && reading.capabilities.battery != .unsupported
    }
}

/// How the charge percent is drawn in the menu bar. Off is the default.
enum MenuBarBatteryPercentageStyle: String, CaseIterable, Codable, Sendable {
    case off
    case withReading
    case alone

    var title: String {
        switch self {
        case .off: return "Off"
        case .withReading: return "With the reading"
        case .alone: return "On its own"
        }
    }
}

/// Bolt keeps today's glyph. Battery follows the charge.
enum MenuBarIconChoice: String, CaseIterable, Codable, Sendable {
    case bolt
    case battery

    var title: String {
        switch self {
        case .bolt: return "Bolt"
        case .battery: return "Battery"
        }
    }
}

/// The percent has its own slot, reserved at "100%".
/// It is not part of the watt text, so a watt-reading width reserve can stay
/// independent and the item does not move between 9%, 87% and 100%.
struct MenuBarPercentageSlot: Equatable, Sendable {
    var visible: String
    /// No watt text beside the percent: percent-only mode, or a mode with no reading.
    var standalone: Bool

    static let reserve = "100%"
    static let separator = " · "
    static let unavailable = "—"

    static func visibleText(percentage: Int?) -> String {
        guard let percentage, (0...100).contains(percentage) else { return unavailable }
        return "\(percentage)%"
    }

    var prefix: String { standalone ? "" : Self.separator }
    var visibleText: String { prefix + visible }
    var reserveText: String { prefix + Self.reserve }

    /// Spoken without the percent sign, so VoiceOver does not say "percent percent".
    var spoken: String {
        guard visible != Self.unavailable, visible.hasSuffix("%") else { return "charge unavailable" }
        return String(visible.dropLast()) + " percent"
    }

    /// How much wider "100%" is than the live percent, in the menu-bar font.
    /// Callers add this on top of the measured title. A shorter percent then
    /// occupies the same slot as 100%.
    @MainActor
    func slack(font: NSFont) -> CGFloat {
        Self.slack(visible: visibleText, reserve: reserveText, font: font)
    }

    @MainActor
    static func slack(visible: String, reserve: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let reserved = (reserve as NSString).size(withAttributes: attributes).width
        let shown = (visible as NSString).size(withAttributes: attributes).width
        return max(0, reserved - shown)
    }
}

struct MenuBarPercentageSlotView: View {
    let slot: MenuBarPercentageSlot

    var body: some View {
        // The hidden "100%" (plus the separator, when the percent follows a
        // reading) is the slot. The live value is trailing-aligned inside it
        // and uses tabular digits, so 9% and 100% are the same width.
        ZStack(alignment: .trailing) {
            Text(slot.reserveText)
                .hidden()
                .accessibilityHidden(true)
            Text(slot.visibleText)
        }
        .monospacedDigit()
        .fixedSize(horizontal: true, vertical: false)
    }
}

enum MenuBarBatteryTint: Equatable, Sendable {
    case template
    case lowBattery
    case lowPower

    var color: Color? {
        switch self {
        case .template: return nil
        case .lowBattery: return Color(nsColor: .systemRed)
        case .lowPower: return Color(nsColor: .systemYellow)
        }
    }

    var nsColor: NSColor? {
        switch self {
        case .template: return nil
        case .lowBattery: return .systemRed
        case .lowPower: return .systemYellow
        }
    }

    /// Low Power Mode is a state VoiceOver should hear. The low-battery color
    /// is already covered by the charge percent and "on battery".
    var spoken: String? {
        switch self {
        case .lowPower: return "Low Power Mode"
        case .template, .lowBattery: return nil
        }
    }
}

/// Charge glyph for the Battery menu-bar icon.
///
/// The deployment target can draw a variable battery symbol, so the fill tracks
/// the exact percent and the charging bolt does not look full at a partial charge.
/// `battery.100percent.bolt` is the only bolt glyph. Quarter symbols
/// (`battery.0percent` … `battery.100percent`, then the older `battery.0` names)
/// are the fallback when that variable symbol is missing.
struct MenuBarBatteryPresentation: Equatable, Sendable {
    var symbolName: String
    /// 0...1 when `symbolName` is the variable battery symbol. Nil for a quarter glyph.
    var variableValue: Double?
    var tint: MenuBarBatteryTint

    /// Same threshold as the system battery item.
    static let lowBatteryThreshold = 20
    static let quarters = [0, 25, 50, 75, 100]

    /// Nearest quarter. 12% is empty, 13% is a quarter, 87% is three quarters, 88% is full.
    static func quarter(for percentage: Int) -> Int {
        let clamped = min(100, max(0, percentage))
        return quarters.min { lhs, rhs in
            let left = abs(lhs - clamped)
            let right = abs(rhs - clamped)
            if left == right { return lhs < rhs }
            return left < right
        } ?? 0
    }

    /// Charging, paused charging, and full are plugged in. Draining stays unplugged
    /// even when a charger is connected but cannot keep up.
    static func showsChargingBolt(state: BatteryState, charger: Capability) -> Bool {
        switch state {
        case .charging, .chargingHold, .full:
            return true
        case .discharging, .noBattery:
            return false
        case .unknown:
            return charger == .available
        }
    }

    static func tint(percentage: Int?, unplugged: Bool, lowPowerMode: Bool) -> MenuBarBatteryTint {
        if lowPowerMode { return .lowPower }
        if unplugged, let percentage, (0...lowBatteryThreshold).contains(percentage) {
            return .lowBattery
        }
        return .template
    }

    @MainActor
    static func resolve(
        percentage: Int?,
        state: BatteryState,
        charger: Capability,
        lowPowerMode: Bool,
        symbolExists: @MainActor (String) -> Bool
    ) -> MenuBarBatteryPresentation {
        let unplugged = state == .discharging
        let tint = tint(percentage: percentage, unplugged: unplugged, lowPowerMode: lowPowerMode)
        guard let percentage, (0...100).contains(percentage) else {
            return MenuBarBatteryPresentation(symbolName: "bolt.fill", variableValue: nil, tint: .template)
        }
        let showsBolt = showsChargingBolt(state: state, charger: charger)
        let value = Double(percentage) / 100
        let variableNames = showsBolt
            ? ["battery.100percent.bolt", "battery.100.bolt"]
            : ["battery.100percent", "battery.100"]
        if let name = variableNames.first(where: symbolExists) {
            return MenuBarBatteryPresentation(symbolName: name, variableValue: value, tint: tint)
        }
        let level = quarter(for: percentage)
        var discrete = ["battery.\(level)percent", "battery.\(level)"]
        if showsBolt && level == 100 {
            discrete = ["battery.100percent.bolt", "battery.100.bolt"] + discrete
        }
        let name = discrete.first(where: symbolExists) ?? discrete[0]
        return MenuBarBatteryPresentation(symbolName: name, variableValue: nil, tint: tint)
    }

    @MainActor
    static func systemSymbolExists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    @MainActor
    func makeImage() -> NSImage? {
        let image: NSImage?
        if let variableValue {
            image = NSImage(systemSymbolName: symbolName, variableValue: variableValue, accessibilityDescription: nil)
        } else {
            image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
        guard let image else { return nil }
        guard let color = tint.nsColor else {
            image.isTemplate = true
            return image
        }
        let tinted = image.withSymbolConfiguration(.init(paletteColors: [color])) ?? image
        tinted.isTemplate = false
        return tinted
    }
}

struct MenuBarBatteryIcon: View {
    let presentation: MenuBarBatteryPresentation

    var body: some View {
        Group {
            if let value = presentation.variableValue {
                Image(systemName: presentation.symbolName, variableValue: value)
            } else {
                Image(systemName: presentation.symbolName)
            }
        }
        .modifier(MenuBarBatteryTintModifier(tint: presentation.tint))
    }
}

private struct MenuBarBatteryTintModifier: ViewModifier {
    let tint: MenuBarBatteryTint

    @ViewBuilder
    func body(content: Content) -> some View {
        if let color = tint.color {
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(color)
        } else {
            content
        }
    }
}
