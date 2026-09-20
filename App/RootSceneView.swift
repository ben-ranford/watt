import AppKit
import SwiftUI

struct RootSceneView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var powerStore: PowerReadingStore

    var body: some View {
        switch router.destination {
        case .onboarding:
            OnboardingFlowView()
        case .update:
            VStack(spacing: WattSpacing.md) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                Text("Update coordinator shell")
                    .font(WattTypography.headline)
                Text("The update states are tracked in SCREEN-BACKLOG.md and are not implemented in phase one.")
                    .font(WattTypography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(WattSpacing.xl)
        case .settings:
            SettingsRootView()
        case .statusPanel:
            StatusPanelView(reading: powerStore.currentReading, onSettings: router.showSettings, onQuit: quit)
                .frame(width: 320)
        }
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
