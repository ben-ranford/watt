import SwiftUI

struct WattFormRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: WattSpacing.md) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .font(WattTypography.body)
        .frame(minHeight: WattSpacing.formRowHeight)
        .padding(.horizontal, WattSpacing.md)
    }
}

struct WattFormSection<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WattSpacing.sm) {
            Text(title)
                .font(WattTypography.headline)
                .padding(.horizontal, WattSpacing.xs)
            VStack(spacing: 0) {
                content
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
