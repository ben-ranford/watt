import SwiftUI

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
        Button(title, action: action)
            .buttonStyle(.plain)
            .padding(.horizontal, WattSpacing.md)
            .frame(height: WattSpacing.buttonHeight)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .tint(tint)
    }

    private var backgroundColor: Color {
        style == .prominent ? tint : Color.primary.opacity(0.08)
    }

    private var tint: Color {
        switch style {
        case .bordered: return .accentColor
        case .prominent: return .accentColor
        case .destructive: return .wattDestructive
        }
    }
}
