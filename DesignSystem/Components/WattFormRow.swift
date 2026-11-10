import SwiftUI

/// Native label/value alignment; the containing Form owns row spacing and separators.
struct WattFormRow<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        LabeledContent {
            trailing
        } label: {
            leading
        }
    }
}

/// Descriptive copy is product content; control states remain system-managed.
struct WattRowLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: WattSpacing.xxs) {
            Text(title).font(WattTypography.body)
            Text(subtitle)
                .font(WattTypography.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
