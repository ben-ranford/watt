import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J24SettingsApprovalTests: XCTestCase {
    private func preferences() -> PreferencesStore {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = false
        return preferences
    }

    #if DEBUG || SWIFT_PACKAGE
    func testExactPendingRowsAndFixtureAreNotApproval() async throws {
        let helper = FakeHelperService(); helper.status = .pending
        let setup = SettingsHelperSetup(service: helper)
        let preferences = preferences()
        await setup.turnOn(preferences: preferences)
        XCTAssertEqual(setup.state, .requiresApproval)
        XCTAssertEqual(setup.statusTitle, "Waiting for approval…")
        XCTAssertEqual(setup.statusSubtitle, "Turn on “Watt? Helper” in Login Items & Extensions.")
        XCTAssertEqual(SettingsHelperRows.openSettings, "Open System Settings")
        XCTAssertNil(setup.message)
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertTrue(helper.registeredReceipts.isEmpty)
        XCTAssertEqual(setup.approvals.checkpoint.origins[.settings]?.interested, true)
        let fixture = try ScenarioRegistry.resolve("J2.4")
        XCTAssertEqual(fixture.story.node, "29:3926")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J2.4/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.story(ScenarioRegistry.resolve("J2.4", variant: "dark")).smokeLaunchArguments())
        let window = J24FixtureLaunch.makeWindow()
        XCTAssertEqual(window.title, SettingsRootView.title)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertNil(window.appearance) // Follow native appearance; no production/fixture style override.
        window.close()
    }
    #endif

    func testOpenSettingsCallbackDoesNotApproveOrNavigate() async {
        let router = AppRouter()
        let helper = FakeHelperService(); helper.status = .pending
        router.settingsHelperSetup.service = helper
        let preferences = preferences()
        await router.settingsHelperSetup.turnOn(preferences: preferences)
        let before = router.settingsHelperSetup.approvals.checkpoint
        var opens = 0
        router.openApprovalSettings = { opens += 1 }
        router.present = { _ in XCTFail("Opening Login Items must not navigate to success") }
        router.openApprovalSettings()
        XCTAssertEqual(opens, 1)
        XCTAssertEqual(router.settingsHelperSetup.state, .requiresApproval)
        XCTAssertEqual(router.settingsHelperSetup.approvals.checkpoint, before)
        XCTAssertFalse(preferences.componentReadings)
    }

    func testPendingCancellationPreservesOtherOriginAndRetryUsesFreshEvidence() async throws {
        let approvals = HelperApprovalStore()
        let other = try approvals.join(.onboarding, reconciled: .pending).token
        let helper = FakeHelperService(); helper.status = .pending
        let setup = SettingsHelperSetup(service: helper, approvals: approvals)
        let preferences = preferences()
        await setup.turnOn(preferences: preferences)
        setup.cancel()
        XCTAssertEqual(setup.state, .cancelled)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertTrue(approvals.canNavigate(other))
        helper.status = .failed(.denied)
        await setup.turnOn(preferences: preferences)
        XCTAssertEqual(setup.state, .denied)
        XCTAssertEqual(setup.actionTitle, "Retry")
        helper.status = .pending
        await setup.turnOn(preferences: preferences)
        XCTAssertEqual(setup.state, .requiresApproval)
        helper.status = .connected
        await setup.turnOn(preferences: preferences)
        XCTAssertTrue(setup.helperOn)
        XCTAssertTrue(preferences.componentReadings)
    }

    func testCancelPersistenceFailureDoesNotClaimSuccess() async {
        let storage = InMemoryStorage()
        let helper = FakeHelperService(); helper.status = .pending
        let setup = SettingsHelperSetup(service: helper, approvals: HelperApprovalStore(storage: storage))
        let preferences = preferences()
        await setup.turnOn(preferences: preferences)
        storage.failWrites = true
        setup.cancel()
        XCTAssertEqual(setup.state, .failed(.persistence))
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(preferences.componentReadings)
    }

    func testLateConfirmationAfterCancelCannotEnableOrReplaceRetry() async {
        let helper = J24SuspendedConfirmation()
        let setup = SettingsHelperSetup(service: helper)
        let preferences = preferences()
        let first = Task { await setup.turnOn(preferences: preferences) }
        while helper.reply == nil { await Task.yield() }
        setup.cancel()
        helper.suspend = false
        await setup.turnOn(preferences: preferences)
        XCTAssertEqual(setup.state, .requiresApproval)
        helper.reply?.resume(returning: .connected)
        await first.value
        XCTAssertEqual(setup.state, .requiresApproval)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(setup.helperOn)
    }

    func testForegroundApprovalDeliversActiveSettingsOnlyOnceAndPreservesOnboarding() async throws {
        let helper = FakeHelperService(); helper.status = .pending
        let approvals = HelperApprovalStore()
        let onboarding = try approvals.join(.onboarding, reconciled: .pending).token
        let setup = SettingsHelperSetup(service: helper, approvals: approvals)
        let preferences = preferences()
        await setup.turnOn(preferences: preferences)
        helper.status = .connected
        await setup.refreshStatus(preferences: preferences)
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertTrue(setup.helperOn)
        XCTAssertTrue(approvals.canNavigate(onboarding))
        XCTAssertFalse(preferences.onboarding.completed)
        preferences.componentReadings = false
        await setup.refreshStatus(preferences: preferences)
        XCTAssertFalse(preferences.componentReadings) // Settings delivery is single-use.
        XCTAssertEqual(try approvals.receive(.connected, operationID: onboarding.operationID,
                                            generation: onboarding.generation), [onboarding])
        XCTAssertEqual(try approvals.receive(.connected, operationID: onboarding.operationID,
                                            generation: onboarding.generation), [])
    }

    func testImmediateConnectedDeliveryDoesNotConsumeOtherOrigin() async throws {
        let helper = FakeHelperService(); helper.status = .connected
        let approvals = HelperApprovalStore()
        let onboarding = try approvals.join(.onboarding, reconciled: .pending).token
        let setup = SettingsHelperSetup(service: helper, approvals: approvals)
        await setup.turnOn(preferences: preferences())
        XCTAssertTrue(approvals.canNavigate(onboarding))
        XCTAssertEqual(try approvals.receive(.connected, operationID: onboarding.operationID,
                                            generation: onboarding.generation, origin: .onboarding), [onboarding])
    }

    func testOriginScopedDeliveryWorksInEitherOrder() throws {
        for first in [ApprovalOrigin.settings, .onboarding] {
            let approvals = HelperApprovalStore()
            let settings = try approvals.join(.settings, reconciled: .pending).token
            let onboarding = try approvals.join(.onboarding, reconciled: .pending).token
            let tokens = first == .settings ? [settings, onboarding] : [onboarding, settings]
            for token in tokens {
                XCTAssertTrue(approvals.canNavigate(token))
                XCTAssertEqual(try approvals.receive(.connected, operationID: token.operationID,
                    generation: token.generation, origin: token.origin), [token])
                XCTAssertFalse(approvals.canNavigate(token))
                XCTAssertEqual(try approvals.receive(.connected, operationID: token.operationID,
                    generation: token.generation, origin: token.origin), [])
            }
        }
    }

    func testPassiveCancelledAndClosedRefreshNeverOptIn() async {
        for detach in ["passive", "cancel", "close"] {
            let helper = FakeHelperService(); helper.status = .pending
            let setup = SettingsHelperSetup(service: helper)
            let preferences = preferences()
            if detach != "passive" { await setup.turnOn(preferences: preferences) }
            if detach == "cancel" { setup.cancel() }
            if detach == "close" {
                let before = setup.approvals.checkpoint
                setup.close()
                XCTAssertEqual(setup.approvals.checkpoint, before)
                XCTAssertTrue(setup.approvals.checkpoint.desiredOn)
            }
            helper.status = .connected
            await setup.refreshStatus(preferences: preferences)
            XCTAssertTrue(setup.helperOn) // Fresh service evidence, not restored presentation authority.
            XCTAssertFalse(preferences.componentReadings, detach)
            XCTAssertFalse(preferences.onboarding.completed)
        }
    }

    func testCloseDuringConfirmationDropsLateReplyButRetainsInterest() async {
        let helper = J24SuspendedConfirmation()
        let setup = SettingsHelperSetup(service: helper)
        let preferences = preferences()
        let task = Task { await setup.turnOn(preferences: preferences) }
        while helper.reply == nil { await Task.yield() }
        let before = setup.approvals.checkpoint
        setup.close()
        XCTAssertEqual(setup.approvals.checkpoint, before)
        XCTAssertTrue(before.desiredOn)
        helper.reply?.resume(returning: .connected)
        await task.value
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(setup.helperOn)
    }

    func testLateRefreshAfterCancelAndMissingServiceFailClosed() async {
        let helper = J24SuspendedConfirmation()
        helper.queries = 1
        let setup = SettingsHelperSetup(service: helper)
        let task = Task { await setup.refreshStatus() }
        while helper.reply == nil { await Task.yield() }
        setup.cancel()
        helper.reply?.resume(returning: .connected)
        await task.value
        XCTAssertEqual(setup.state, .cancelled)
        XCTAssertFalse(setup.helperOn)
        setup.service = nil
        await setup.refreshStatus()
        XCTAssertEqual(setup.statusTitle, "Unavailable")
        let preferences = preferences(); preferences.componentReadings = true
        await setup.turnOn(preferences: preferences)
        XCTAssertEqual(setup.state, .notDetermined)
        XCTAssertFalse(setup.helperOn) // Persisted intent and preview telemetry confer no authority.
    }
}

@MainActor
private final class J24SuspendedConfirmation: HelperService {
    var queries = 0
    var suspend = true
    var reply: CheckedContinuation<HelperReconciliation, Never>?
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation {
        queries += 1
        if queries == 2 && suspend { return await withCheckedContinuation { reply = $0 } }
        return .pending
    }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> {
        XCTFail("Discovered pending registration must not register again")
        return .failure(.unknownStatus)
    }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome {
        XCTFail("Cancel must not unregister a shared helper")
        return .failed(.unknownStatus)
    }
}
