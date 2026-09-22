import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J17CoachMarkTests: XCTestCase {
    func testExactCopyAndFixture() throws {
        XCTAssertEqual(CoachMarkView.title, "Watt? lives here")
        XCTAssertEqual(CoachMarkView.message, "Click for the detail. Right-click to change the number.")
        let fixture = try ScenarioRegistry.resolve("J1.7")
        XCTAssertEqual(fixture.story.node, "28:2621")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J1.7/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J1.7", variant: "unavailable"))
    }

    func testDoneThenGotItPersistsAndRoutesExactlyOnce() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .allSet, helperOptIn: true)
        preferences.displayMode = .charger
        preferences.openAtLogin = false
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        AllSetView.finish(preferences: preferences, router: router) {}
        XCTAssertEqual(destinations, [.coachMark])
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        XCTAssertEqual(destinations, [.coachMark, .statusPanel])
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.onboarding.checkpoint, .livePanel)
        XCTAssertTrue(restored.onboarding.completed)
        XCTAssertTrue(restored.onboarding.helperOptIn)
        XCTAssertEqual(restored.displayMode, .charger)
        XCTAssertFalse(restored.openAtLogin)
    }

    func testFailedPersistenceRetainsCoachMarkAndAllowsRetry() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        let router = AppRouter()
        var count = 0
        router.present = { _ in count += 1 }
        storage.failWrites = true
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        XCTAssertEqual(count, 0)
        XCTAssertEqual(preferences.onboarding.checkpoint, .coachMark)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        storage.failWrites = false
        CoachMarkView.acknowledge(preferences: preferences, router: router)
        XCTAssertEqual(count, 1)
        XCTAssertNil(preferences.persistenceFailure)
    }

    func testWrongCheckpointOrIncompleteSetupDoesNotRoute() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        router.present = { _ in XCTFail("Unexpected navigation") }
        for state in [OnboardingState(checkpoint: .coachMark), .init(checkpoint: .allSet, completed: true), .init(checkpoint: .livePanel, completed: true)] {
            preferences.onboarding = state
            CoachMarkView.acknowledge(preferences: preferences, router: router)
            XCTAssertEqual(preferences.onboarding, state)
        }
    }

    func testNativePopoverContractAndDismissalDoesNotAcknowledge() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding = .init(checkpoint: .coachMark, completed: true)
        let router = AppRouter()
        router.present = { _ in XCTFail("Close is not acknowledgement") }
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        XCTAssertEqual(popover.behavior, .transient)
        XCTAssertNil(popover.appearance, "Production popover inherits system appearance")
        XCTAssertEqual(popover.contentSize, NSSize(width: 260, height: 136))
        XCTAssertNotNil(popover.contentViewController)
        popover.close()
        XCTAssertEqual(preferences.onboarding.checkpoint, .coachMark)
    }

    func testExistingPersistedCoachMarkDecodes() throws {
        let data = Data(#"{"checkpoint":"coachMark","completed":true,"helperOptIn":false}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(OnboardingState.self, from: data).checkpoint, .coachMark)
    }
}
