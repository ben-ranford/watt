import AppKit
import SwiftUI
import XCTest
@testable import Watt

@MainActor
final class J52FinishSetupTests: XCTestCase {
    private let checkpoints: [OnboardingCheckpoint] = [
        .welcome, .picker, .helperOffer, .approval, .preview, .allSet,
        .coachMark, .livePanel, .welcomeClosed, .runningDefaults
    ]

    func testExactCopyAndPromptGatingForEveryCheckpoint() {
        XCTAssertEqual(SetupPromptPresentation.title, "Finish setup")
        XCTAssertEqual(SetupPromptPresentation.subtitle, "2 steps left")
        XCTAssertEqual(SetupPromptPresentation.action, "Continue…")
        XCTAssertEqual(SetupPromptPresentation.failure, "Couldn’t save. Try again.")
        for checkpoint in checkpoints {
            for completed in [false, true] {
                XCTAssertEqual(SetupPromptPresentation.canPresent(.init(checkpoint: checkpoint, completed: completed)),
                               !completed && [.welcomeClosed, .runningDefaults].contains(checkpoint))
            }
        }
    }

    func testExactPowerRowsAndNativeGeometryWithWorkingFooterCallbacks() {
        for failed in [false, true] {
            let model = StatusPanelModel(reading: .sampleCharging, componentReadingsEnabled: false,
                                         setupIncomplete: true, setupSaveFailed: failed)
            XCTAssertEqual(model.charger, "65.0 W")
            XCTAssertEqual(model.system, "22.9 W")
            XCTAssertEqual(model.battery, "+42.1 W")
            XCTAssertEqual(model.subtitle, "64% · full in about 38 min")
            XCTAssertNil(model.chargerSubtitle)
            XCTAssertFalse(model.showsComponents)
            XCTAssertEqual(model.panelHeight, failed ? 347 : 319)
            var actions: [String] = []
            let panel = StatusPanelView(reading: .sampleCharging, componentReadingsEnabled: false,
                setupIncomplete: true, setupSaveFailed: failed,
                onContinueSetup: { actions.append("continue") },
                onSettings: { actions.append("settings") }, onQuit: { actions.append("quit") })
            let host = NSHostingView(rootView: panel)
            host.appearance = NSAppearance(named: .aqua)
            XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: failed ? 347 : 319))
            panel.onSettings()
            panel.onQuit()
            panel.onContinueSetup()
            XCTAssertEqual(actions, ["settings", "quit", "continue"])
        }
        XCTAssertTrue(StatusPanelModel(reading: .sampleCharging).showsComponents)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).panelHeight, 473)
    }

    func testContinuePersistsPickerBeforeNavigationPreservesPreferencesAndRestartsIncomplete() {
        for checkpoint in [OnboardingCheckpoint.welcomeClosed, .runningDefaults] {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = .init(checkpoint: checkpoint, helperOptIn: true, deferredSetupID: UUID())
            preferences.displayMode = .charger
            preferences.precision = .whole
            preferences.componentReadings = false
            preferences.showSymbol = false
            preferences.openAtLogin = false
            let expected = preferences.onboarding
            let router = AppRouter()
            let id = router.beginPanelSetupPresentation()
            var routes: [AppDestination] = []
            router.present = {
                routes.append($0)
                let disk = PreferencesStore(storage: storage)
                XCTAssertEqual(disk.onboarding, preferences.onboarding)
                XCTAssertEqual(disk.onboarding.checkpoint, .picker)
                XCTAssertFalse(disk.onboarding.completed)
                XCTAssertNil(disk.onboarding.deferredSetupID)
                XCTAssertTrue(disk.onboarding.helperOptIn)
                XCTAssertEqual(disk.displayMode, .charger)
                XCTAssertEqual(disk.precision, .whole)
                XCTAssertFalse(disk.componentReadings || disk.showSymbol || disk.openAtLogin)
                XCTAssertFalse(router.statusPanelPresented)
            }
            let writes = storage.writes
            XCTAssertTrue(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: id))
            XCTAssertEqual(storage.writes, writes + 1)
            XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: id))
            XCTAssertEqual(storage.writes, writes + 1)
            XCTAssertEqual(routes, [.onboarding])
            let restarted = AppRouter()
            var restartRoutes: [AppDestination] = []
            restarted.present = { restartRoutes.append($0) }
            restarted.launch(preferences: PreferencesStore(storage: storage))
            XCTAssertEqual(restartRoutes, [.onboarding])
        }
    }

    func testFailedWriteLeavesMemoryDiskAndPresentationRetryable() {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .runningDefaults)
        let expected = preferences.onboarding
        let disk = storage.values
        let router = AppRouter()
        let id = router.beginPanelSetupPresentation()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        storage.failWrites = true
        XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: id))
        XCTAssertEqual(preferences.onboarding, expected)
        XCTAssertEqual(storage.values, disk)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        XCTAssertTrue(router.statusPanelPresented)
        XCTAssertTrue(routes.isEmpty)
        storage.failWrites = false
        XCTAssertTrue(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: id))
        XCTAssertNil(preferences.persistenceFailure)
        XCTAssertEqual(routes, [.onboarding])
    }

    func testCompletedAndNonDeferredCheckpointsNeverWriteOrNavigate() {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        router.present = { _ in XCTFail("Ineligible state navigated") }
        for checkpoint in checkpoints {
            for completed in [false, true] {
                let state = OnboardingState(checkpoint: checkpoint, completed: completed)
                guard !SetupPromptPresentation.canPresent(state) else { continue }
                preferences.onboarding = state
                let id = router.beginPanelSetupPresentation()
                let writes = storage.writes
                XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: state, presentationID: id))
                XCTAssertEqual(preferences.onboarding, state)
                XCTAssertEqual(storage.writes, writes)
            }
        }
    }

    func testClosedMissingAndReplacedPresentationCallbacksNeverWrite() {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .runningDefaults)
        let expected = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let first = router.beginPanelSetupPresentation()
        router.endPanelSetupPresentation(first)
        let writes = storage.writes
        XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: first))
        let second = router.beginPanelSetupPresentation()
        XCTAssertNotEqual(first, second)
        router.endPanelSetupPresentation(first)
        router.endPanelSetupPresentation(nil)
        XCTAssertTrue(router.statusPanelPresented)
        for stale in [nil, first, UUID()] {
            XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: stale))
        }
        router.statusPanelPresented = false
        router.statusPanelPresented = true
        XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: second))
        XCTAssertEqual(storage.writes, writes)
        XCTAssertTrue(routes.isEmpty)
        let third = router.beginPanelSetupPresentation()
        XCTAssertTrue(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: third))
        XCTAssertEqual(routes, [.onboarding])
    }

    func testChangedSnapshotAndNewDeferredPromptRejectOldCallback() {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .welcomeClosed, deferredSetupID: UUID())
        let old = preferences.onboarding
        let router = AppRouter()
        let id = router.beginPanelSetupPresentation()
        router.present = { _ in XCTFail("Changed setup navigated") }
        for newer in [OnboardingState(checkpoint: .runningDefaults),
                      .init(checkpoint: .welcomeClosed, helperOptIn: true, deferredSetupID: old.deferredSetupID),
                      .init(checkpoint: .welcomeClosed, deferredSetupID: UUID())] {
            preferences.onboarding = newer
            let writes = storage.writes
            XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: old, presentationID: id))
            XCTAssertEqual(storage.writes, writes)
            XCTAssertEqual(preferences.onboarding, newer)
        }
    }

    func testPanelSuccessInvalidatesOpposingAndRepeatedCoachMarkActions() throws {
        let storage = CountingStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .welcomeClosed, deferredSetupID: UUID())
        let expected = preferences.onboarding
        let coachID = try XCTUnwrap(expected.deferredSetupID)
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let panelID = router.beginPanelSetupPresentation()
        XCTAssertTrue(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: panelID))
        let writes = storage.writes
        CoachMarkView.notNow(preferences: preferences, router: router, presentationID: coachID)
        CoachMarkView.finishSetup(preferences: preferences, router: router, presentationID: coachID)
        XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: panelID))
        XCTAssertEqual(storage.writes, writes)
        XCTAssertEqual(routes, [.onboarding])
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
        XCTAssertFalse(preferences.onboarding.completed)
    }

    func testCoachMarkResolutionMakesPreviouslyCapturedPanelActionStale() throws {
        for finish in [false, true] {
            let storage = CountingStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.onboarding = .init(checkpoint: .welcomeClosed, deferredSetupID: UUID())
            let expected = preferences.onboarding
            let coachID = try XCTUnwrap(expected.deferredSetupID)
            let router = AppRouter()
            var routes: [AppDestination] = []
            router.present = { routes.append($0) }
            let panelID = router.beginPanelSetupPresentation()
            if finish {
                CoachMarkView.finishSetup(preferences: preferences, router: router, presentationID: coachID)
            } else {
                CoachMarkView.notNow(preferences: preferences, router: router, presentationID: coachID)
            }
            let resolved = preferences.onboarding
            let writes = storage.writes
            XCTAssertFalse(router.continuePanelSetup(preferences: preferences, expected: expected, presentationID: panelID))
            XCTAssertEqual(storage.writes, writes)
            XCTAssertEqual(preferences.onboarding, resolved)
            XCTAssertEqual(routes, [finish ? .onboarding : .statusPanel])
        }
    }

    @MainActor
    private final class CountingStorage: PreferenceStorage {
        var values: [String: Data] = [:]
        var writes = 0
        var failWrites = false
        func read(key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws {
            writes += 1
            if failWrites { throw ServiceFailure.persistence }
            values[key] = data
        }
    }
}
