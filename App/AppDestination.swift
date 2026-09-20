import Foundation

enum AppDestination: Hashable {
    case statusPanel
    case onboarding
    case settings
    case update
}

enum OnboardingStep: Int, CaseIterable, Hashable {
    case welcome
    case menuBarReading
    case componentReadings
    case helperApproval
    case componentPreview
    case allSet
    case coachMark
}
