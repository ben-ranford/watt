import SwiftUI

/// SF Pro via system text styles; macOS owns font metrics and accessibility behavior.
enum WattTypography {
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let headline = Font.body.weight(.bold)
    static let welcomeTitle = Font.title.weight(.bold)
    static let title = Font.title2.weight(.bold)
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
}
