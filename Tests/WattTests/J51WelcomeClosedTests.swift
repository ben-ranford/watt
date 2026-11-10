import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J51WelcomeClosedTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactCopyAndFixtureRegistration() throws {
        XCTAssertEqual(CoachMarkView.Variant.welcomeClosed.title, "Watt? is on, showing Delta.")
        XCTAssertEqual(CoachMarkView.Variant.welcomeClosed.message,
                       "Setup can wait. Two steps, whenever you’re ready.")
        XCTAssertEqual(CoachMarkView.Variant.standard.title, CoachMarkView.title)
        XCTAssertEqual(CoachMarkView.Variant.standard.message, CoachMarkView.message)
        let fixture = try ScenarioRegistry.resolve("J5.1")
        XCTAssertEqual(fixture.story.node, "J5.1")
        XCTAssertEqual(fixture.story.appearance, "light")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J5.1/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J5.1", variant: "unavailable"))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J51FixtureLaunch.requested)
        #endif
    }
    #endif

    func testCloseWelcomePersistsBeforeRoutingOnceAndPreservesPreferences() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.displayMode = .charger
        preferences.openAtLogin = false
        preferences.onboarding.helperOptIn = true
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = {
            destinations.append($0)
            let restored = PreferencesStore(storage: storage)
            XCTAssertEqual(restored.displayMode, .delta)
            XCTAssertEqual(restored.onboarding.checkpoint, .welcomeClosed)
            XCTAssertNotNil(restored.onboarding.deferredSetupID)
            XCTAssertEqual(restored.onboarding, preferences.onboarding)
        }
        XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: router))
        let token = try XCTUnwrap(preferences.onboarding.deferredSetupID)
        XCTAssertFalse(OnboardingFlowView.closeWelcome(preferences: preferences, router: router))
        XCTAssertEqual(destinations, [.coachMark])
        XCTAssertEqual(preferences.onboarding.deferredSetupID, token)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertTrue(preferences.onboarding.helperOptIn)
        XCTAssertFalse(PreferencesStore(storage: storage).openAtLogin)
    }

    func testFailedWelcomeCloseIsAtomicAndRetrySucceeds() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.displayMode = .draw
        let before = preferences.onboarding
        let persisted = storage.values
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        storage.failWrites = true
        XCTAssertFalse(OnboardingFlowView.closeWelcome(preferences: preferences, router: router))
        XCTAssertEqual(preferences.onboarding, before)
        XCTAssertEqual(preferences.displayMode, .draw)
        XCTAssertEqual(storage.values, persisted)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        XCTAssertTrue(destinations.isEmpty)
        storage.failWrites = false
        XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: router))
        XCTAssertEqual(destinations, [.coachMark])
        XCTAssertNil(preferences.persistenceFailure)
    }

    func testCloseAndContinueIgnoreCompletedOrAdvancedWelcome() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        router.present = { _ in XCTFail("Stale welcome action navigated") }
        for state in [OnboardingState(checkpoint: .welcome, completed: true),
                      .init(checkpoint: .picker), .init(checkpoint: .runningDefaults),
                      .init(checkpoint: .livePanel, completed: true)] {
            preferences.onboarding = state
            XCTAssertFalse(OnboardingFlowView.closeWelcome(preferences: preferences, router: router))
            OnboardingFlowView.continueWelcome(preferences: preferences)
            XCTAssertEqual(preferences.onboarding, state)
        }
    }

    func testContinueFailureKeepsWelcomeAndRetryPersistsPicker() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        let before = preferences.onboarding
        storage.failWrites = true
        OnboardingFlowView.continueWelcome(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, before)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        storage.failWrites = false
        OnboardingFlowView.continueWelcome(preferences: preferences)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .picker)
        XCTAssertNil(preferences.persistenceFailure)
    }

    func testBothActionsPersistBeforeRoutingAndIgnoreRepeatedOrOpposingAction() throws {
        for finish in [false, true] {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding.helperOptIn = true
            preferences.openAtLogin = false
            XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter()))
            let token = try XCTUnwrap(preferences.onboarding.deferredSetupID)
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = {
                destinations.append($0)
                let restored = PreferencesStore(storage: storage)
                XCTAssertEqual(restored.onboarding.checkpoint, finish ? .picker : .runningDefaults)
                XCTAssertNil(restored.onboarding.deferredSetupID)
                XCTAssertEqual(restored.onboarding, preferences.onboarding)
            }
            act(finish, preferences: preferences, router: router, token: token)
            let after = preferences.onboarding
            act(finish, preferences: preferences, router: router, token: token)
            act(!finish, preferences: preferences, router: router, token: token)
            XCTAssertEqual(destinations, [finish ? .onboarding : .statusPanel])
            XCTAssertEqual(preferences.onboarding, after)
            XCTAssertFalse(after.completed)
            XCTAssertTrue(after.helperOptIn)
            XCTAssertEqual(preferences.displayMode, .delta)
            XCTAssertFalse(PreferencesStore(storage: storage).openAtLogin)
        }
    }

    func testBothActionFailuresPreserveMemoryAndDiskAndAllowRetry() throws {
        for finish in [false, true] {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter()))
            let token = try XCTUnwrap(preferences.onboarding.deferredSetupID)
            let before = preferences.onboarding
            let persisted = storage.values
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = { destinations.append($0) }
            storage.failWrites = true
            act(finish, preferences: preferences, router: router, token: token)
            XCTAssertEqual(preferences.onboarding, before)
            XCTAssertEqual(storage.values, persisted)
            XCTAssertEqual(preferences.persistenceFailure, .persistence)
            XCTAssertTrue(destinations.isEmpty)
            storage.failWrites = false
            act(finish, preferences: preferences, router: router, token: token)
            XCTAssertEqual(destinations, [finish ? .onboarding : .statusPanel])
            XCTAssertNil(preferences.persistenceFailure)
        }
    }

    func testActionsRejectMissingWrongAndCompletedPresentationTokens() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        router.present = { _ in XCTFail("Stale action navigated") }
        let token = UUID()
        for state in [OnboardingState(checkpoint: .welcomeClosed),
                      .init(checkpoint: .welcomeClosed, deferredSetupID: UUID()),
                      .init(checkpoint: .welcomeClosed, completed: true, deferredSetupID: token),
                      .init(checkpoint: .welcome, deferredSetupID: token),
                      .init(checkpoint: .picker, deferredSetupID: token)] {
            preferences.onboarding = state
            for finish in [false, true] {
                act(finish, preferences: preferences, router: router, token: token)
                XCTAssertEqual(preferences.onboarding, state)
            }
        }
    }

    func testOldPromptCannotActOnNewWelcomeClosure() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter()))
        let oldToken = try XCTUnwrap(preferences.onboarding.deferredSetupID)
        CoachMarkView.finishSetup(preferences: preferences, router: AppRouter(), presentationID: oldToken)
        ChooseMenuReadingView.back(preferences: preferences)
        XCTAssertTrue(OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter()))
        let newToken = try XCTUnwrap(preferences.onboarding.deferredSetupID)
        XCTAssertNotEqual(oldToken, newToken)
        let before = preferences.onboarding
        let router = AppRouter()
        router.present = { _ in XCTFail("Old prompt navigated") }
        for finish in [false, true] {
            act(finish, preferences: preferences, router: router, token: oldToken)
            XCTAssertEqual(preferences.onboarding, before)
        }
    }

    func testLaunchResumesPendingPromptButKeepsRunningDefaultsQuietAndIsIdempotent() {
        for checkpoint in [OnboardingCheckpoint.welcomeClosed, .runningDefaults, .welcome, .picker] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding = .init(checkpoint: checkpoint, deferredSetupID: UUID())
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = { destinations.append($0) }
            router.launch(preferences: preferences)
            router.launch(preferences: preferences)
            let expected: [AppDestination] = checkpoint == .runningDefaults ? [] :
                [checkpoint == .welcomeClosed ? .coachMark : .onboarding]
            XCTAssertEqual(destinations, expected)
        }
    }

    func testReopenDeferredSetupPersistsPickerAndInvalidatesPromptBeforeRouting() {
        for checkpoint in [OnboardingCheckpoint.welcomeClosed, .runningDefaults] {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = .init(checkpoint: checkpoint, helperOptIn: true, deferredSetupID: UUID())
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = {
                destinations.append($0)
                let restored = PreferencesStore(storage: storage)
                XCTAssertEqual(restored.onboarding.checkpoint, .picker)
                XCTAssertNil(restored.onboarding.deferredSetupID)
                XCTAssertTrue(restored.onboarding.helperOptIn)
                XCTAssertFalse(restored.onboarding.completed)
            }
            router.reopen(preferences: preferences)
            XCTAssertEqual(destinations, [.onboarding])
        }
    }

    func testReopenFailureDoesNotNavigateOrMutateAndRetrySucceeds() {
        for checkpoint in [OnboardingCheckpoint.welcomeClosed, .runningDefaults] {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = .init(checkpoint: checkpoint, deferredSetupID: UUID())
            let before = preferences.onboarding
            let router = AppRouter()
            var destinations: [AppDestination] = []
            router.present = { destinations.append($0) }
            storage.failWrites = true
            router.reopen(preferences: preferences)
            XCTAssertEqual(preferences.onboarding, before)
            XCTAssertTrue(destinations.isEmpty)
            storage.failWrites = false
            router.reopen(preferences: preferences)
            XCTAssertEqual(destinations, [.onboarding])
            XCTAssertNil(preferences.persistenceFailure)
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixturePreparationIsIsolatedAndPopoverUsesNativeLightTransientSurface() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let untouched = PreferencesStore(storage: InMemoryStorage())
        J51FixtureLaunch.prepare(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .welcomeClosed)
        XCTAssertNotNil(preferences.onboarding.deferredSetupID)
        XCTAssertEqual(preferences.displayMode, .delta)
        XCTAssertEqual(untouched.onboarding.checkpoint, .welcome)
        let before = preferences.onboarding
        let router = AppRouter()
        router.present = { _ in XCTFail("Transient dismissal must not resolve setup") }
        let popover = CoachMarkView.makePopover(preferences: preferences, router: router)
        XCTAssertEqual(popover.appearance?.name, .aqua)
        XCTAssertEqual(popover.behavior, .transient)
        XCTAssertEqual(popover.contentSize, NSSize(width: 310, height: 122))
        XCTAssertNotNil(popover.contentViewController)
        popover.close()
        XCTAssertEqual(preferences.onboarding, before)
    }
    #endif

    func testExistingSavedOnboardingWithoutTokenStillDecodes() throws {
        let data = Data(#"{"checkpoint":"welcome","completed":false,"helperOptIn":true}"#.utf8)
        let state = try JSONDecoder().decode(OnboardingState.self, from: data)
        XCTAssertEqual(state.checkpoint, .welcome)
        XCTAssertNil(state.deferredSetupID)
        XCTAssertTrue(state.helperOptIn)
    }

    func testNativeCloseIsWindowScopedAndFailureKeepsWelcomeForReopen() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        router.present = { _ in XCTFail("Unrelated or failed close must not navigate") }
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let observer = OnboardingCloseView()
        observer.onClose = { OnboardingFlowView.closeWelcome(preferences: preferences, router: router) }
        window.contentView = observer
        let unrelated = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                                 backing: .buffered, defer: false)
        unrelated.isReleasedWhenClosed = false
        unrelated.close()
        XCTAssertEqual(preferences.onboarding.checkpoint, .welcome)
        XCTAssertNil(preferences.persistenceFailure)
        storage.failWrites = true
        window.close()
        XCTAssertEqual(preferences.onboarding.checkpoint, .welcome)
        XCTAssertNil(preferences.onboarding.deferredSetupID)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .welcome)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testContextMenuResumeRejectsStalePromptAndFailedWrites() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        J51FixtureLaunch.prepare(preferences: preferences)
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        let menu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        let item = try XCTUnwrap(menu.items.first(where: { $0.title == "Finish Setup…" }))
        let action = try XCTUnwrap(item.action)
        let before = preferences.onboarding
        storage.failWrites = true
        NSApplication.shared.sendAction(action, to: item.target, from: item)
        XCTAssertEqual(preferences.onboarding, before)
        XCTAssertTrue(destinations.isEmpty)
        storage.failWrites = false
        NSApplication.shared.sendAction(action, to: item.target, from: item)
        XCTAssertTrue(destinations.isEmpty) // Failed attempts consume this menu presentation.
        let retryMenu = StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
        let retryItem = try XCTUnwrap(retryMenu.items.first(where: { $0.title == "Finish Setup…" }))
        let retryAction = try XCTUnwrap(retryItem.action)
        NSApplication.shared.sendAction(retryAction, to: retryItem.target, from: retryItem)
        XCTAssertEqual(destinations, [.onboarding])
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .picker)
        ChooseMenuReadingView.back(preferences: preferences)
        OnboardingFlowView.closeWelcome(preferences: preferences, router: AppRouter())
        let newer = preferences.onboarding
        NSApplication.shared.sendAction(action, to: item.target, from: item)
        XCTAssertEqual(preferences.onboarding, newer)
        XCTAssertEqual(destinations, [.onboarding])
    }
    #endif

    private func act(_ finish: Bool, preferences: PreferencesStore, router: AppRouter, token: UUID) {
        if finish {
            CoachMarkView.finishSetup(preferences: preferences, router: router, presentationID: token)
        } else {
            CoachMarkView.notNow(preferences: preferences, router: router, presentationID: token)
        }
    }
}
