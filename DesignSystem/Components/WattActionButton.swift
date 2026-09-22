import SwiftUI

/// Shared intent, not custom chrome: AppKit/SwiftUI owns enabled, focus and accent rendering.
struct WattActionButton: View {
    enum Style: Equatable {
        case bordered
        case prominent
        case destructive
    }

    let title: String
    var style: Style = .bordered
    let action: () -> Void

    var body: some View {
        styledButton.controlSize(.regular)
    }

    @ViewBuilder
    private var styledButton: some View {
        switch style {
        case .prominent:
            Button(title, action: action).buttonStyle(.borderedProminent)
        case .bordered:
            Button(title, action: action).buttonStyle(.bordered)
        case .destructive:
            Button(title, role: .destructive, action: action).buttonStyle(.bordered)
        }
    }
}
