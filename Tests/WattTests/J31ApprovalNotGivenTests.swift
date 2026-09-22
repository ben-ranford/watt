import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J31ApprovalNotGivenTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactCopyAndFixture() throws {
        XCTAssertEqual(HelperNotApprovedAlert.title, "Helper not approved")
        XCTAssertEqual(HelperNotApprovedAlert.message, "Watt? can’t read components without it. Delta, Charger and Draw still work. Turn it on any time in Settings.")
        XCTAssertEqual(HelperNotApprovedAlert.primary, "Open System Settings")
        XCTAssertEqual(HelperNotApprovedAlert.secondary, "Skip for Now")
        let fixture = try ScenarioRegistry.resolve("J3.1")
        XCTAssertEqual(fixture.story.node, "29:5253")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J3.1/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.story(ScenarioRegistry.resolve("J3.1", variant: "timeout")).smokeLaunchArguments())
    }
    #endif

    func testFailureStatesPresentAndButtonsNeverApprove() async {
        for reason in [ServiceFailure.denied, .cancelled, .timedOut] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.componentReadings = true
            let router = AppRouter()
            let helper = FakeHelperService(); helper.status = .failed(reason)
            router.settingsHelperSetup.service = helper
            await router.settingsHelperSetup.turnOn(preferences: preferences)
            XCTAssertTrue(router.helperNotApprovedPresented)
            XCTAssertFalse(preferences.componentReadings)
            XCTAssertFalse(router.settingsHelperSetup.helperOn)
            let checkpoint = router.settingsHelperSetup.approvals.checkpoint
            var opens = 0
            router.openApprovalSettings = { opens += 1 }
            router.openSettingsAfterApprovalFailure(preferences: preferences)
            XCTAssertEqual(opens, 1)
            XCTAssertFalse(router.helperNotApprovedPresented)
            XCTAssertEqual(router.settingsHelperSetup.approvals.checkpoint, checkpoint)
            router.skipUnapprovedHelper(preferences: preferences)
            XCTAssertFalse(preferences.componentReadings)
            XCTAssertEqual(router.settingsHelperSetup.approvals.checkpoint.origins[.settings]?.interested, false)
            for mode in [WattDisplayMode.delta, .charger, .draw] {
                preferences.displayMode = mode
                XCTAssertEqual(preferences.displayMode, mode)
            }
            helper.status = .pending
            await router.settingsHelperSetup.turnOn(preferences: preferences)
            XCTAssertEqual(router.settingsHelperSetup.state, .requiresApproval)
            XCTAssertFalse(preferences.componentReadings)
            router.settingsHelperSetup.close()
        }
    }

    func testPendingDeadlineWithdrawsInterestAndLateRefreshDoesNotOptIn() async throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        let helper = FakeHelperService(); helper.status = .pending
        router.settingsHelperSetup.service = helper
        router.settingsHelperSetup.approvalTimeoutNanoseconds = 1_000_000
        await router.settingsHelperSetup.turnOn(preferences: preferences)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(router.settingsHelperSetup.state, .failed(.timedOut))
        XCTAssertTrue(router.helperNotApprovedPresented)
        router.skipUnapprovedHelper(preferences: preferences)
        helper.status = .connected
        await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(router.helperNotApprovedPresented)
    }

    func testCancellationAndTimeoutDiscardLateConfirmation() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        let helper = J31SuspendedHelper()
        router.settingsHelperSetup.service = helper
        let work = Task { await router.settingsHelperSetup.turnOn(preferences: preferences) }
        while helper.reply == nil { await Task.yield() }
        router.settingsHelperSetup.cancel()
        XCTAssertTrue(router.helperNotApprovedPresented)
        router.skipUnapprovedHelper(preferences: preferences)
        helper.reply?.resume(returning: .connected)
        await work.value
        XCTAssertEqual(router.settingsHelperSetup.state, .cancelled)
        XCTAssertFalse(preferences.componentReadings)
        XCTAssertFalse(router.helperNotApprovedPresented)
    }

    func testCrossOriginFailureAndSkipPreserveOtherWaiter() async throws {
        for origin in [ApprovalOrigin.settings, .onboarding] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            let router = AppRouter()
            let approvals = router.settingsHelperSetup.approvals
            preferences.onboarding.checkpoint = .approval
            let other: ApprovalOrigin = origin == .settings ? .onboarding : .settings
            let token = try approvals.join(other, reconciled: .pending).token
            _ = try approvals.join(origin, reconciled: .pending)
            if origin == .settings {
                let helper = J31FailingConfirmation()
                router.settingsHelperSetup.service = helper
                await router.settingsHelperSetup.turnOn(preferences: preferences)
            } else {
                router.approvalNotGiven(.timedOut, preferences: preferences)
            }
            XCTAssertTrue(router.helperNotApprovedPresented)
            router.skipUnapprovedHelper(preferences: preferences)
            XCTAssertTrue(approvals.canNavigate(token))
            XCTAssertTrue(approvals.checkpoint.desiredOn)
            XCTAssertFalse(preferences.componentReadings)
            XCTAssertEqual(try approvals.receive(.connected, operationID: token.operationID,
                generation: token.generation, origin: other), [token])
        }
    }

    func testRepeatedFailureAndCloseDoNotPresentAgain() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        let helper = FakeHelperService(); helper.status = .failed(.denied)
        router.settingsHelperSetup.service = helper
        await router.settingsHelperSetup.turnOn(preferences: preferences)
        router.skipUnapprovedHelper(preferences: preferences)
        await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        XCTAssertFalse(router.helperNotApprovedPresented)
        router.settingsHelperSetup.close()
        await router.settingsHelperSetup.refreshStatus(preferences: preferences)
        XCTAssertFalse(router.helperNotApprovedPresented)
    }

    func testLateOnboardingReplyAfterCloseOrSkipHasNoAuthority() throws {
        for close in [true, false] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.componentReadings = false
            preferences.onboarding.checkpoint = .approval
            let router = AppRouter()
            let token = try router.settingsHelperSetup.approvals.join(.onboarding, reconciled: .pending).token
            if close { router.settingsHelperSetup.approvals.close(.onboarding) }
            else {
                router.approvalNotGiven(.cancelled, preferences: preferences)
                router.skipUnapprovedHelper(preferences: preferences)
            }
            router.receiveOnboardingApprovalFailure(.denied, token: token, preferences: preferences)
            XCTAssertFalse(router.helperNotApprovedPresented)
            XCTAssertFalse(preferences.componentReadings)
        }
    }

    func testSceneScopedNativeAlertSource() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/AppRouter.swift"), encoding: .utf8)
        let alert = source.components(separatedBy: "struct HelperNotApprovedPresentation")[1]
        XCTAssertTrue(alert.contains("content.alert(HelperNotApprovedAlert.title"))
        XCTAssertTrue(alert.contains("router.failureOrigin == origin"))
        XCTAssertTrue(alert.contains("role: .cancel"))
        XCTAssertTrue(alert.contains(".keyboardShortcut(.defaultAction)"))
        for painted in ["RoundedRectangle", ".frame(", ".background(", "Image(", "NSAlert", "UNUserNotification"] {
            XCTAssertFalse(alert.contains(painted), painted)
        }
        for (file, origin) in [("Features/Settings/Views/SettingsRootView.swift", "settings"),
                               ("Features/Onboarding/Views/OnboardingFlowView.swift", "onboarding")] {
            let view = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertTrue(view.contains("HelperNotApprovedPresentation(router: router, preferences: preferences, origin: .\(origin))"))
        }
    }

    func testOnboardingCancellationAndFailureEntryNeverPretendApproval() {
        for reason in [ServiceFailure.cancelled, .denied, .timedOut] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.checkpoint = .approval
            let router = AppRouter()
            var cancellations = 0
            router.cancelOnboardingApproval = { cancellations += 1 }
            if reason == .cancelled {
                WaitingForApprovalView.cancel(preferences: preferences, router: router)
                XCTAssertEqual(cancellations, 1)
            } else { router.approvalNotGiven(reason, preferences: preferences) }
            XCTAssertTrue(router.helperNotApprovedPresented)
            router.skipUnapprovedHelper(preferences: preferences)
            XCTAssertFalse(preferences.componentReadings)
            XCTAssertFalse(preferences.onboarding.helperOptIn)
            XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
            XCTAssertFalse(preferences.onboarding.completed)
            var destination: AppDestination?
            router.present = { destination = $0 }
            router.showSettings()
            XCTAssertEqual(destination, .settings)
        }
    }
}

@MainActor
private final class J31SuspendedHelper: HelperService {
    var queries = 0
    var reply: CheckedContinuation<HelperReconciliation, Never>?
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation {
        queries += 1
        if queries == 2 { return await withCheckedContinuation { reply = $0 } }
        return .pending
    }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> { .failure(.unknownStatus) }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome { .failed(.unknownStatus) }
}

@MainActor
private final class J31FailingConfirmation: HelperService {
    var queries = 0
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation {
        queries += 1
        return queries == 1 ? .pending : .failed(.denied)
    }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> { .failure(.unknownStatus) }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome { .failed(.unknownStatus) }
}
