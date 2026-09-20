import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WattWindowScaffold(title: "Onboarding shell") {
            VStack(alignment: .leading, spacing: WattSpacing.md) {
                Text("The Figma onboarding frames are intentionally tracked as separate stories in SCREEN-BACKLOG.md.")
                    .font(WattTypography.body)
                Text("Current route: \(router.onboardingStep.label)")
                    .font(WattTypography.subheadline)
                    .foregroundStyle(.secondary)
                Text("This phase establishes the scene and typed route only; helper approval and screen transitions are not simulated.")
                    .font(WattTypography.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    WattActionButton(title: "Close", action: close)
                }
            }
            .padding(WattSpacing.xl)
        }
        .frame(width: 440, height: 238)
    }

    private func close() {
        router.showStatusPanel()
        dismiss()
    }
}

private extension OnboardingStep {
    var label: String {
        switch self {
        case .welcome: return "welcome"
        case .menuBarReading: return "menu-bar reading"
        case .componentReadings: return "component readings"
        case .helperApproval: return "helper approval"
        case .componentPreview: return "component preview"
        case .allSet: return "all set"
        case .coachMark: return "coach mark"
        }
    }
}
