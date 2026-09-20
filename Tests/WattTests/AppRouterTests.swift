import XCTest
@testable import Watt

@MainActor
final class AppRouterTests: XCTestCase {
    func testOnboardingAdvancesAndReturnsToStatusPanel() {
        let router = AppRouter()
        router.beginOnboarding()

        XCTAssertEqual(router.destination, .onboarding)
        XCTAssertEqual(router.onboardingStep, .welcome)

        for _ in OnboardingStep.welcome.rawValue..<OnboardingStep.coachMark.rawValue {
            router.advanceOnboarding()
        }
        XCTAssertEqual(router.onboardingStep, .coachMark)

        router.advanceOnboarding()
        XCTAssertEqual(router.destination, .statusPanel)
    }

    func testSampleReadingMatchesChargingFixture() {
        let reading = PowerReading.sampleCharging

        XCTAssertEqual(reading.mode, .charging)
        XCTAssertEqual(reading.watts, 42.1)
        XCTAssertEqual(reading.batteryPercentage, 64)
        XCTAssertEqual(reading.components.map(\.name), ["CPU", "GPU", "Display", "Other"])
    }
}
