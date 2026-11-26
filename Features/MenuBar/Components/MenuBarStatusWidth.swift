import AppKit
import CoreGraphics
import Foundation

/// Advances for one menu-bar font. Digits share one advance when the font is
/// monospaced-digit, so a reading changes width only when its glyph count does.
struct MenuBarFontMetrics: Equatable, Sendable {
    var advances: [Character: CGFloat]
    var fallbackAdvance: CGFloat

    func width(of text: String) -> CGFloat {
        text.reduce(CGFloat(0)) { partial, character in
            partial + (advances[character] ?? fallbackAdvance)
        }
    }

    @MainActor
    static func measuring(_ font: NSFont, covering texts: [String]) -> MenuBarFontMetrics {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func measure(_ token: String) -> CGFloat {
            (token as NSString).size(withAttributes: attributes).width
        }
        var advances: [Character: CGFloat] = [:]
        for text in texts {
            for character in text where advances[character] == nil {
                advances[character] = measure(String(character))
            }
        }
        let fallback = advances["8"] ?? measure("8")
        return MenuBarFontMetrics(advances: advances, fallbackAdvance: fallback)
    }
}

enum MenuBarStatusFont {
    /// Semibold menu-bar size with tabular digits. The point size is read from
    /// the menu bar font so a size change rebuilds the minimum.
    @MainActor
    static func menuBar() -> NSFont {
        let menu = NSFont.menuBarFont(ofSize: 0)
        let size = menu.pointSize > 0 ? menu.pointSize : NSFont.systemFontSize
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
    }

    /// Matches the SwiftUI label font, `Font.body.weight(.semibold).monospacedDigit()`.
    @MainActor
    static func swiftUILabel() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    }
}

/// Settings that change the reserved reading. The session high-water resets
/// when this value changes, and stays while only the watts change.
struct MenuBarStatusWidthIdentity: Equatable, Sendable {
    var mode: WattDisplayMode
    var precision: WattPrecision
    var unit: String
    var fontName: String
    var fontSize: CGFloat
    var components: [String]
    /// Per-component readings share one trailing unit only in that presentation.
    var componentSharesUnit: Bool
}

/// The widest reading that still has two digits before the decimal.
/// Shorter readings sit inside it. Three integer digits are wider and may grow.
enum MenuBarStatusReserve {
    /// Suffix produced by `PowerFormatter`, so the reserve tracks the real unit.
    static var unit: String {
        let sample = PowerFormatter.watts(1, signed: false, precision: .whole)
        guard let space = sample.lastIndex(of: " ") else { return "W" }
        return String(sample[sample.index(after: space)...])
    }

    /// Typographic minus. The status label uses this for a discharging delta.
    static let typographicMinus = "−"
    static let missing = "—"
    static let componentSeparator = " · "

    static func number(integerDigits: Int = 2, precision: WattPrecision) -> String {
        let whole = String(repeating: "8", count: max(integerDigits, 1))
        guard precision.decimalPlaces > 0 else { return whole }
        return whole + "." + String(repeating: "8", count: precision.decimalPlaces)
    }

    static func reading(_ number: String, unit: String = Self.unit, sign: String? = nil) -> String {
        let body = (sign ?? "") + number
        return unit.isEmpty ? body : body + " " + unit
    }

    static func unsigned(precision: WattPrecision, unit: String = Self.unit) -> [String] {
        [reading(number(precision: precision), unit: unit)]
    }

    static func signed(precision: WattPrecision, unit: String = Self.unit) -> [String] {
        let number = number(precision: precision)
        return ["+", typographicMinus, "-"].map { reading(number, unit: unit, sign: $0) }
    }

    /// Full two-digit rows, plus a row with one value missing. The wider one is
    /// the minimum, so a placeholder does not shrink the item and a two-digit
    /// value does not grow it.
    static func components(labels: [String], precision: WattPrecision, sharesUnit: Bool, unit: String = Self.unit) -> [String] {
        let labels = labels.filter { !$0.isEmpty }
        guard !labels.isEmpty else { return [missing] }
        let value = number(precision: precision)
        var candidates: [String] = []
        if sharesUnit {
            let compact = labels.map { "\($0) \(value)" }.joined(separator: componentSeparator)
            candidates.append(unit.isEmpty ? compact : compact + " " + unit)
        } else {
            let separate = labels.map { "\($0) \(reading(value, unit: unit))" }
                .joined(separator: componentSeparator)
            candidates.append(separate)
        }
        guard labels.count > 1 else { return candidates }
        for missingIndex in labels.indices {
            let parts = labels.enumerated().map { index, label in
                index == missingIndex ? "\(label) \(missing)" : "\(label) \(reading(value, unit: unit))"
            }
            candidates.append(parts.joined(separator: componentSeparator))
        }
        return candidates
    }
}

/// Pure width decision. Callers pass the live string, the two-digit reserves,
/// and font metrics. The result is the text width to hold, including session
/// high-water, plus the icon when one is showing.
enum MenuBarStatusWidth {
    struct Input: Equatable, Sendable {
        var displayed: String
        var references: [String]
        var metrics: MenuBarFontMetrics
        var iconWidth: CGFloat = 0
        var iconSpacing: CGFloat = 0
        /// Text width already required earlier in this session.
        var highWater: CGFloat = 0
        var keepHighWater: Bool = true
    }

    struct Result: Equatable, Sendable {
        var displayedTextWidth: CGFloat
        var minimumTextWidth: CGFloat
        /// Live text, the two-digit reserve, and the session high-water.
        var textWidth: CGFloat
        var contentWidth: CGFloat
        var highWater: CGFloat
    }

    static func widest(_ strings: [String], metrics: MenuBarFontMetrics) -> String {
        strings.max { metrics.width(of: $0) < metrics.width(of: $1) } ?? ""
    }

    static func resolve(_ input: Input) -> Result {
        let displayedText = input.metrics.width(of: input.displayed)
        let minimumText = input.references.map { input.metrics.width(of: $0) }.max() ?? 0
        let kept = input.keepHighWater ? max(0, input.highWater) : 0
        let textWidth = max(displayedText, minimumText, kept)
        let gap = (input.iconWidth > 0 && textWidth > 0) ? max(0, input.iconSpacing) : 0
        let content = max(0, input.iconWidth) + gap + textWidth
        return Result(
            displayedTextWidth: displayedText,
            minimumTextWidth: minimumText,
            textWidth: textWidth,
            contentWidth: content,
            highWater: textWidth
        )
    }

    /// Status-item length is the button's own intrinsic width plus the text
    /// slack. Nothing else is added. The result is rounded up to a device
    /// pixel so the last glyph is not clipped.
    static func itemLength(intrinsicWidth: CGFloat, textSlack: CGFloat, scale: CGFloat) -> CGFloat {
        let raw = intrinsicWidth + max(0, textSlack)
        guard scale > 0 else { return raw }
        return (raw * scale).rounded(.up) / scale
    }
}
