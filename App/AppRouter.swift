import AppKit
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var destination: AppDestination = .statusPanel
    @Published var onboardingStep: OnboardingStep = .welcome

    func beginOnboarding() {
        onboardingStep = .welcome
        destination = .onboarding
    }

    func showStatusPanel() {
        destination = .statusPanel
    }

    func showSettings() {
        destination = .settings
        NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func showUpdate() {
        destination = .update
    }

    func advanceOnboarding() {
        guard let next = OnboardingStep(rawValue: onboardingStep.rawValue + 1) else {
            showStatusPanel()
            return
        }
        onboardingStep = next
    }

    func goBackInOnboarding() {
        guard let previous = OnboardingStep(rawValue: onboardingStep.rawValue - 1) else {
            return
        }
        onboardingStep = previous
    }
}
