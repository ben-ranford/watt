import AppKit
import SwiftUI

/// AppKit semantic colors resolve against the host appearance, including increased contrast.
/// Reference swatches live in DESIGN.md; controls follow the user's macOS accent choice.
enum WattColors {
    static let accent = Color.accentColor
    static let primaryLabel = Color(nsColor: .labelColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let disabledLabel = Color(nsColor: .disabledControlTextColor)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let rowFill = Color(nsColor: .quaternaryLabelColor)
    static let separator = Color(nsColor: .separatorColor)
    static let focusRing = Color(nsColor: .keyboardFocusIndicatorColor)
    static let success = Color(nsColor: .systemGreen)
    static let destructive = Color(nsColor: .systemRed)
}
