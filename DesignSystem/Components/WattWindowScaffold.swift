import SwiftUI

struct WattWindowScaffold<Content: View>: View {
    private let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                Text(title)
                    .font(WattTypography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, WattSpacing.xl)
                    .padding(.top, WattSpacing.lg)
                    .padding(.bottom, WattSpacing.sm)
            }
            content
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
