import AppKit
import SwiftUI

extension Color {
    static let wattAccentLight = Color(red: 0.0, green: 0.533, blue: 1.0)
    static let wattAccentDark = Color(red: 0.0, green: 0.569, blue: 1.0)
    static let wattSuccess = Color(red: 0.204, green: 0.780, blue: 0.361)
    static let wattDestructive = Color(red: 0.961, green: 0.184, blue: 0.196)
}

enum WattColors {
    static let accent = Color.accentColor
    static let lightWindowBackground = Color(nsColor: .windowBackgroundColor)
    static let lightRowFill = Color.black.opacity(0.03)
    static let darkRowFill = Color.white.opacity(0.08)
    static let lightPrimaryLabel = Color.black.opacity(0.85)
    static let darkPrimaryLabel = Color.white.opacity(0.85)
    static let lightSecondaryLabel = Color.black.opacity(0.50)
    static let darkSecondaryLabel = Color.white.opacity(0.55)
}
