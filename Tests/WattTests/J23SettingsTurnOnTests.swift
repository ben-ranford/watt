import AppKit
import ServiceManagement
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
import WattHelperShared
#endif
@testable import Watt

@MainActor
final class J23SettingsTurnOnTests: XCTestCase {
    private func preferences() -> PreferencesStore {
        let value = PreferencesStore(storage: InMemoryStorage())
        value.componentReadings = false
        value.onboarding.completed = true
        return value
    }
    #if DEBUG || SWIFT_PACKAGE
    func testExactCopyNativeControlsAndFixture() throws {
        XCTAssertEqual(SettingsRootView.title, "Watt? Settings")
        XCTAssertEqual(SettingsHelperRows.statusTitle, "Status")
        XCTAssertEqual(SettingsHelperRows.helperTitle, "Helper")
        XCTAssertEqual(SettingsHelperRows.statusSubtitle, "Reading CPU and GPU power.")
        XCTAssertEqual(SettingsHelperRows.privacy, "Reads power sensors only. No network, nothing leaves this Mac.")
        XCTAssertEqual(SettingsHelperRows.turnOn, "Turn On…")
        let fixture = try ScenarioRegistry.resolve("J2.3")
        XCTAssertEqual(fixture.story.node, "J2.3")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J2.3/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J2.3", variant: "dark"))
        let window = J23FixtureLaunch.makeWindow()
        XCTAssertEqual(window.title, SettingsRootView.title)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.contentView?.fittingSize.width, WattSpacing.settingsExcerptWidth)
        window.close()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
        for token in ["Form {", "Picker(\"Show\"", ".pickerStyle(.menu)", ".buttonStyle(.borderedProminent)", ".disabled(removing || !setup.canTurnOn)", "ProgressView()", "role: .cancel", "router.openApprovalSettings()", "Text(Self.helperTitle)", "Text(mode.title).accessibilityLabel(mode.title)"] {
            XCTAssertTrue(source.contains(token), token)
        }
    }
    #endif
    func testMissingServiceIsExplicitlyUnavailableInsteadOfADeadRetry() async {
        let setup = SettingsHelperSetup(); let prefs = preferences()
        XCTAssertEqual(setup.state, .notDetermined)
        XCTAssertEqual(setup.statusTitle, "Unavailable")
        XCTAssertEqual(setup.statusSubtitle, HelperUnavailableReason.missingBundle.message)
        XCTAssertEqual(setup.actionTitle, "Unavailable")
        XCTAssertFalse(setup.canTurnOn)
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .notDetermined)
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertNil(setup.message)
    }
    func testRequiresApprovalIsNotSuccessAndRetryReconciles() async {
        let service = FakeHelperService(); service.status = .pending
        let setup = SettingsHelperSetup(service: service); let prefs = preferences()
        let before = prefs.onboarding
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .requiresApproval)
        XCTAssertEqual(setup.actionTitle, "Check Approval")
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertTrue(service.registeredReceipts.isEmpty)
        service.status = .connected
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .connected)
        XCTAssertFalse(setup.canTurnOn)
        XCTAssertTrue(prefs.componentReadings)
        XCTAssertEqual(prefs.onboarding, before)
    }
    func testDeniedUnknownAndRegistrationFailureRemainOff() async {
        for (status, expected) in [(HelperReconciliation.failed(.denied), SettingsHelperSetup.State.denied),
                                    (.unknown, .failed(.unknownStatus)), (.absent, .failed(.untrustedIdentity))] {
            let service = FakeHelperService(); service.status = status
            service.registrationOutcome = .failure(.untrustedIdentity)
            let setup = SettingsHelperSetup(service: service); let prefs = preferences()
            await setup.turnOn(preferences: prefs)
            XCTAssertEqual(setup.state, expected)
            XCTAssertFalse(prefs.componentReadings)
            XCTAssertTrue(setup.canTurnOn)
        }
    }
    func testRegistrationAcknowledgementDoesNotEnableReadings() async {
        let service = FakeHelperService(); service.registrationOutcome = .success(.connected)
        let setup = SettingsHelperSetup(service: service); let prefs = preferences()
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(service.registeredReceipts.count, 1)
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertEqual(setup.state, .failed(.unknownStatus))
    }
    func testLoadingDuplicateAndLateReplyAfterCancel() async {
        let service = SuspendedJ23Helper(); let setup = SettingsHelperSetup(service: service)
        let prefs = preferences()
        let task = Task { await setup.turnOn(preferences: prefs) }
        while service.continuation == nil { await Task.yield() }
        XCTAssertTrue(setup.isLoading)
        XCTAssertFalse(setup.canTurnOn)
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(service.queries, 1)
        setup.cancel()
        service.continuation?.resume(returning: .connected)
        await task.value
        XCTAssertEqual(setup.state, .cancelled)
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertTrue(setup.canTurnOn)
    }
    func testCancelPreservesOtherOriginAndPersistenceFailureIsVisible() async throws {
        let storage = InMemoryStorage(); let approvals = HelperApprovalStore(storage: storage)
        let token = try approvals.join(.onboarding, reconciled: .pending).token
        let service = FakeHelperService(); service.status = .pending
        let setup = SettingsHelperSetup(service: service, approvals: approvals)
        await setup.turnOn(preferences: preferences())
        setup.cancel()
        XCTAssertTrue(approvals.canNavigate(token))
        XCTAssertTrue(approvals.checkpoint.desiredOn)
        storage.failWrites = true
        setup.cancel()
        XCTAssertEqual(setup.state, .failed(.persistence))
    }
    func testErrorAndCancellationRetryUseFreshServiceEvidence() async {
        let service = FakeHelperService(); service.status = .failed(.denied)
        let setup = SettingsHelperSetup(service: service); let prefs = preferences()
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .denied)
        setup.cancel()
        service.status = .connected
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .connected)
        XCTAssertTrue(prefs.componentReadings)
        setup.resetAfterVerifiedRemoval()
        XCTAssertEqual(setup.state, .notDetermined)
        XCTAssertTrue(setup.canTurnOn)
    }

    func testPreviewAndPersistedOptInCannotClaimHelperOnWithoutService() async throws {
        let prefs = preferences(); prefs.componentReadings = true
        let preview = PowerReadingStore.preview
        XCTAssertEqual(preview.currentReading.capabilities.components, .available)
        let setup = AppRouter().settingsHelperSetup
        await setup.refreshStatus()
        XCTAssertNil(setup.service)
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(setup.canTurnOn)
        XCTAssertEqual(setup.actionTitle, "Unavailable")
        XCTAssertEqual(setup.statusTitle, "Unavailable")
        XCTAssertNil(setup.message)
        XCTAssertTrue(prefs.componentReadings) // Persisted intent is not silently rewritten.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/SettingsRootView.swift"), encoding: .utf8)
        let helperSource = try XCTUnwrap(source.components(separatedBy: "struct SettingsHelperRows: View").last)
        XCTAssertFalse(helperSource.contains("powerStore"), "Telemetry must not grant helper lifecycle authority")
        XCTAssertFalse(setup.canRemoveHelper, "Telemetry and preferences cannot authorize removal")
        XCTAssertTrue(source.contains("router.removeVerifiedHelper(preferences: preferences)"))
        let routerSource = try String(contentsOf: root.appendingPathComponent("App/AppRouter.swift"), encoding: .utf8)
        XCTAssertTrue(routerSource.contains("guard settingsHelperSetup.canRemoveHelper else"))
    }

    func testCompositionRemovalAndReplacementInvalidateConnectedEvidence() async {
        let service = FakeHelperService(); service.status = .connected
        let setup = SettingsHelperSetup(service: service)
        await setup.turnOn(preferences: preferences())
        XCTAssertTrue(setup.helperOn)
        setup.service = nil
        XCTAssertFalse(setup.helperOn)
        XCTAssertEqual(setup.state, .notDetermined)
        XCTAssertEqual(setup.actionTitle, "Unavailable")
        setup.service = FakeHelperService() // Replacement is not trusted by the old connection.
        XCTAssertFalse(setup.helperOn)
    }

    func testQueryOnlyServiceRefreshRevokesConnectedPresentation() async {
        let service = FakeHelperService(); service.status = .connected
        let setup = SettingsHelperSetup(service: service)
        let prefs = preferences()
        await setup.turnOn(preferences: prefs)
        XCTAssertTrue(setup.helperOn)
        service.status = .failed(.disconnected)
        await setup.refreshStatus()
        XCTAssertFalse(setup.helperOn)
        XCTAssertEqual(setup.state, .failed(.disconnected))
        XCTAssertTrue(setup.canTurnOn)
        XCTAssertTrue(prefs.componentReadings) // Intent survives loss of verified availability.
    }

    func testLateConnectedReplyCannotRestoreRemovedService() async {
        let service = SuspendedJ23Helper()
        let setup = SettingsHelperSetup(service: service)
        let task = Task { await setup.refreshStatus() }
        while service.continuation == nil { await Task.yield() }
        XCTAssertFalse(setup.helperOn)
        setup.service = nil
        service.continuation?.resume(returning: .connected)
        await task.value
        XCTAssertFalse(setup.helperOn)
        XCTAssertEqual(setup.state, .notDetermined)
    }

    func testRealAdapterDisconnectAndRevocationImmediatelyRevokeOn() async {
        let driver = J23LifecycleDriver(), transport = J23Transport()
        let adapter = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: transport.peer)
        let setup = SettingsHelperSetup(service: adapter)
        await setup.turnOn(preferences: preferences())
        XCTAssertTrue(setup.helperOn)
        adapter.disconnect() // Event, not a Settings refresh or a telemetry sample.
        XCTAssertFalse(setup.helperOn)
        XCTAssertEqual(setup.state, .failed(.disconnected))
        await setup.refreshStatus()
        XCTAssertTrue(setup.helperOn)
        driver.statusValue = .disabled
        _ = await adapter.reconcile(receipt: nil)
        XCTAssertFalse(setup.helperOn)
        XCTAssertNotEqual(setup.state, .connected)
        await setup.refreshStatus()
        XCTAssertEqual(setup.state, .denied)
        XCTAssertFalse(setup.helperOn)
    }

    func testDisconnectedAdapterRejectsLateAuthenticatedReply() async {
        let driver = J23LifecycleDriver(), transport = J23Transport()
        let adapter = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: transport.peer)
        let setup = SettingsHelperSetup(service: adapter)
        transport.onSend = { adapter.disconnect() }
        let prefs = preferences()
        await setup.turnOn(preferences: prefs)
        XCTAssertEqual(setup.state, .failed(.disconnected))
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertTrue(setup.canTurnOn)
    }

    func testSettingsRoutingDoesNotOptInOrCompleteOnboarding() {
        let router = AppRouter(); let prefs = preferences(); let before = prefs.onboarding
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        router.showSettings()
        XCTAssertEqual(destinations, [.settings])
        XCTAssertEqual(router.settingsHelperSetup.state, .notDetermined)
        XCTAssertFalse(prefs.componentReadings)
        XCTAssertEqual(prefs.onboarding, before)
    }
    func testProductionRepairRouteRecoversDisconnectedHelperAndReusesDurableReceipt() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = RepairRegistrationSystem()
        let transport = RepairTransport()
        let peer = transport.peer
        func driver() throws -> ProductionHelperLifecycle {
            try ProductionHelperLifecycle(system: system, journalURL: url, targetBuild: "2",
                candidate: { peer }, installedBuild: { "2" }, processesAbsent: { true })
        }
        let first = try driver()
        let adapter = HelperLifecycleAdapter(driver: first, transport: transport, expectedPeer: peer)
        let setup = SettingsHelperSetup(service: adapter)
        setup.configureRepair(receipt: { first.updateReceipt() })
        await setup.refreshStatus()
        XCTAssertTrue(setup.canRepairHelper)
        system.failRegistration = true
        await setup.repairHelper()
        XCTAssertEqual(system.removals, 1)
        let receipt = try XCTUnwrap(first.journal?.receipt)

        let resumed = try driver()
        let resumedAdapter = HelperLifecycleAdapter(driver: resumed, transport: transport, expectedPeer: peer)
        let resumedSetup = SettingsHelperSetup(service: resumedAdapter)
        resumedSetup.configureRepair(receipt: { resumed.updateReceipt() }, pending: { true })
        await resumedSetup.refreshStatus()
        XCTAssertTrue(resumedSetup.canRepairHelper)
        system.failRegistration = false
        transport.connected = true
        await resumedSetup.repairHelper()
        XCTAssertTrue(resumedSetup.helperOn)
        XCTAssertEqual(resumed.journal?.receipt, receipt)
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(system.registrations, 2)
        resumedAdapter.connectionLost()
        XCTAssertFalse(resumedSetup.helperOn)
        XCTAssertTrue(resumedSetup.canRemoveHelper)
        XCTAssertTrue(resumedSetup.canRepairHelper)
        await resumedSetup.refreshStatus()
        XCTAssertTrue(resumedSetup.helperOn)
    }

    func testProductionRepairRouteReplacesIncompatibleHelper() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = RepairRegistrationSystem(), transport = RepairTransport()
        transport.connected = true
        transport.protocolVersion = 99
        let peer = transport.peer
        system.onRegister = { transport.protocolVersion = 1 }
        let driver = try ProductionHelperLifecycle(system: system, journalURL: url, targetBuild: "2",
            candidate: { peer }, installedBuild: { "2" }, processesAbsent: { true })
        let adapter = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: peer)
        let setup = SettingsHelperSetup(service: adapter)
        setup.configureRepair(receipt: { driver.updateReceipt() })
        await setup.refreshStatus()
        XCTAssertEqual(setup.state, .failed(.incompatibleVersion))
        XCTAssertTrue(setup.canRepairHelper)
        await setup.repairHelper()
        XCTAssertTrue(setup.helperOn)
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(system.registrations, 1)
    }

    func testDiagnosticExportUsesFixedCommandAndRejectsUncorrelatedEvidence() async throws {
        var authenticated = false
        let data = try await HelperDiagnosticExport.capture(connect: { authenticated = true }, request: { request in
            XCTAssertTrue(authenticated)
            XCTAssertEqual(request.command, .diagnosticCapture)
            XCTAssertNil(request.receipt)
            return HelperReply(request: request, build: "1", daemonInstance: UUID(), status: .sourceUnvalidated,
                capture: HelperCapture(startedAt: Date(), duration: 1, stdout: Data("source".utf8),
                    stderr: Data(), exitStatus: 0, status: .completed, terminationConfirmed: true))
        })
        XCTAssertLessThan(data.count, HelperLimits.diagnosticReplyBytes)
        do {
            _ = try await HelperDiagnosticExport.capture(connect: {}, request: { request in
                HelperReply(request: HelperRequest(command: request.command, generation: UUID()),
                            build: "1", daemonInstance: UUID(), status: .unavailable)
            })
            XCTFail("Uncorrelated evidence must be rejected")
        } catch { }
    }

    func testConfigurationFailureReasonsPreserveDisabledRegistrationAndSharedCopy() {
        let cases: [(Error, Bool, HelperUnavailableReason)] = [
            (HelperSigningError.missingTeam, false, .missingBundle),
            (HelperSigningError.missingTeam, true, .signingRequired),
            (HelperSigningError.invalidSignature, true, .verificationFailed),
            (HelperSigningError.invalidRequirement, true, .verificationFailed),
            (ServiceFailure.untrustedIdentity, true, .verificationFailed),
            (ServiceFailure.invalidData, true, .verificationFailed),
            (ServiceFailure.persistence, true, .configurationFailed),
            (NSError(domain: "private diagnostic", code: 99), true, .configurationFailed)
        ]
        for (error, present, expected) in cases {
            let reason = HelperUnavailableReason.configurationFailure(error, packagedHelperPresent: present)
            XCTAssertEqual(reason, expected)
            let setup = SettingsHelperSetup()
            setup.unavailableReason = reason
            XCTAssertFalse(setup.helperServiceAvailable)
            XCTAssertFalse(setup.canTurnOn)
            XCTAssertFalse(setup.helperOn)
            XCTAssertEqual(setup.statusTitle, "Unavailable")
            XCTAssertEqual(setup.statusSubtitle, reason.message)
            XCTAssertNil(setup.message, "The status row already shows the explanation")
            XCTAssertTrue(OfferComponentReadingsView.unavailableMessage(for: reason).contains(reason.message))
            XCTAssertFalse(reason.message.contains("private diagnostic"))
        }
        XCTAssertTrue(HelperUnavailableReason.signingRequired.message.contains("certificate-based"))
        XCTAssertFalse(HelperUnavailableReason.verificationFailed.message.contains("does not include"))
    }

}

@MainActor
private final class SuspendedJ23Helper: HelperService {
    var continuation: CheckedContinuation<HelperReconciliation, Never>?
    var queries = 0
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation {
        queries += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> { .failure(.unknownStatus) }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome { .failed(.unknownStatus) }
}

@MainActor
private final class J23LifecycleDriver: HelperLifecycleDriver {
    var statusValue: HelperRegistrationStatus = .enabled
    func status() async throws -> HelperRegistrationStatus { statusValue }
    func verifyCandidate() throws -> HelperPeer { HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 1) }
    func register(receipt: OperationReceipt) async throws { XCTFail("Read-only verification must not register") }
    func update(receipt: OperationReceipt) async throws { XCTFail("Unexpected update") }
    func unregister(receipt: OperationReceipt) async throws { XCTFail("Unexpected removal") }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { false }
}

@MainActor
private final class J23Transport: HelperIPCTransport {
    let peer = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 1)
    func connect() async throws -> HelperPeer { peer }
    var onSend: (() -> Void)?
    func send(_ request: HelperMessage) async throws -> HelperMessage {
        onSend?()
        return request
    }
    func invalidate() {}

}

@MainActor
private final class RepairRegistrationSystem: HelperRegistrationSystem {
    var unregisterInFlight = false
    var registrationStatus: SMAppService.Status = .enabled
    var failRegistration = false
    var onRegister: () -> Void = {}
    var registrations = 0
    var removals = 0
    func register() throws {
        registrations += 1
        if failRegistration { throw ServiceFailure.denied }
        registrationStatus = .enabled
        onRegister()
    }
    func unregister() async throws { removals += 1; registrationStatus = .notRegistered }
}

@MainActor
private final class RepairTransport: HelperIPCTransport {
    let peer = HelperPeer(identifier: "helper", team: "TEAM", protocolVersion: 1)
    var connected = false
    var protocolVersion = 1
    func connect() async throws -> HelperPeer {
        guard connected else { throw ServiceFailure.disconnected }
        return HelperPeer(identifier: peer.identifier, identity: peer.identity, protocolVersion: protocolVersion)
    }
    func send(_ request: HelperMessage) async throws -> HelperMessage { request }
    func invalidate() {}
}
