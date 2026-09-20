import SwiftUI

struct SettingsRootView: View {
    var body: some View {
        WattWindowScaffold(title: "Watt? Settings") {
            VStack(alignment: .leading, spacing: WattSpacing.lg) {
                Text("Settings shell")
                    .font(WattTypography.title)
                Text("The grouped settings surface is established here; individual controls and persistence are implemented by the C05/J7/J9/J10/J12 stories in SCREEN-BACKLOG.md.")
                    .font(WattTypography.body)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: WattSpacing.sm) {
                    ForEach(["Menu Bar", "Readings", "Component Readings", "Notifications", "General"], id: \.self) { section in
                        Label(section, systemImage: "chevron.right")
                            .font(WattTypography.bodyEmphasized)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Native Settings scene")
                        .font(WattTypography.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Phase 1 shell")
                        .font(WattTypography.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(WattSpacing.xl)
        }
        .frame(width: 540, height: 320)
    }
}
