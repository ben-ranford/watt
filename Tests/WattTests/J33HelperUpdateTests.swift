import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J33HelperUpdateTests: XCTestCase {
    func testExactCopyAndNativeSemantics() throws {
        XCTAssertEqual(HelperChangedAlert.title, "The helper changed")
        XCTAssertEqual(HelperChangedAlert.message, "Watt? 1.1 comes with a new helper. macOS asks you to approve it once more.")
        XCTAssertEqual(HelperChangedAlert.primary, "Update Helper")
        XCTAssertEqual(HelperChangedAlert.secondary, "Later")
        let fixture = try ScenarioRegistry.resolve("J3.3")
        XCTAssertEqual(fixture.story.node, "29:6181")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J3.3/base"])
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/HelperUpdatePresentation.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("HelperChangedAlert.make()"))
        XCTAssertTrue(source.contains("alert.addButton(withTitle: primary)"))
        XCTAssertTrue(source.contains("alert.addButton(withTitle: secondary)"))
        XCTAssertFalse(source.contains(".frame("))
        XCTAssertFalse(source.contains("Image("))
    }
    func testLaterPreservesStateAndCallsNeitherBoundary() async {
        let prompt = HelperUpdatePrompt()
        var calls = 0
        prompt.verifyRelaunch = { calls += 1; return true }
        prompt.updateHelper = { _ in calls += 1; return .success(.connected) }
        prompt.presented = true
        prompt.later()
        XCTAssertFalse(prompt.presented)
        XCTAssertNil(prompt.outcome)
        XCTAssertEqual(calls, 0)
    }
    func testUnverifiedRelaunchCannotUpdate() async {
        let prompt = HelperUpdatePrompt()
        var calls = 0
        prompt.updateHelper = { _ in calls += 1; return .success(.connected) }
        await prompt.update()
        XCTAssertEqual(calls, 0)
        guard case .failure(.interruptedUpdate) = prompt.outcome else { return XCTFail() }
        XCTAssertFalse(prompt.presented)
    }
    func testFailureRetryRetainsReceiptAndPendingIsNotSuccess() async {
        let prompt = HelperUpdatePrompt()
        prompt.verifyRelaunch = { true }
        var receipts: [OperationReceipt] = []
        prompt.updateHelper = { receipt in
            receipts.append(receipt)
            return receipts.count == 1 ? .failure(.cancelled) : .success(.awaitingApproval)
        }
        await prompt.update()
        XCTAssertFalse(prompt.presented)
        await prompt.update()
        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts[0], receipts[1])
        guard case .success(.awaitingApproval) = prompt.outcome else { return XCTFail() }
        XCTAssertFalse(prompt.presented)
    }
    func testCloseCancellationAndDuplicateClicksIgnoreLateReplies() async {
        for cancel in [false, true] {
            let prompt = HelperUpdatePrompt()
            prompt.verifyRelaunch = { true }
            var continuation: CheckedContinuation<ServiceOutcome<HelperState>, Never>?
            var calls = 0
            prompt.updateHelper = { _ in
                calls += 1
                return await withCheckedContinuation { continuation = $0 }
            }
            let task = Task { await prompt.update() }
            while continuation == nil { await Task.yield() }
            await prompt.update()
            XCTAssertEqual(calls, 1)
            if cancel { task.cancel() } else { prompt.close() }
            continuation?.resume(returning: .success(.connected))
            await task.value
            XCTAssertNil(prompt.outcome)
            XCTAssertFalse(prompt.busy)
        }
    }
    func testUnknownAcknowledgementNeverBecomesHelperSuccess() async {
        let prompt = HelperUpdatePrompt()
        prompt.verifyRelaunch = { true }
        prompt.updateHelper = { _ in .success(.updateRequired) }
        await prompt.update()
        guard case .failure(.unknownStatus) = prompt.outcome else { return XCTFail() }
    }
}

@MainActor
final class J33Driver: HelperLifecycleDriver {
    var registration: HelperRegistrationStatus = .enabled
    var applied = true
    var updates = 0
    var failure: ServiceFailure?
    func status() async throws -> HelperRegistrationStatus { registration }
    func verifyCandidate() throws -> HelperPeer { J33Transport.identity }
    func register(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func unregister(receipt: OperationReceipt) async throws { throw ServiceFailure.unknownStatus }
    func update(receipt: OperationReceipt) async throws {
        updates += 1
        if let failure { throw failure }
        registration = .requiresApproval
    }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { applied }
}

@MainActor
final class J33Transport: HelperIPCTransport {
    static let identity = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 2)
    var peer = identity
    var reply: ((HelperMessage) async -> HelperMessage)?
    func connect() async throws -> HelperPeer { peer }
    func send(_ request: HelperMessage) async throws -> HelperMessage {
        if let reply { return await reply(request) }
        return request
    }
    func invalidate() {}
}

extension J33HelperUpdateTests {
    func testRenewedApprovalReconcilesWithoutReinstallAndRequiresInstalledProof() async {
        let driver = J33Driver(), transport = J33Transport()
        let helper = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: J33Transport.identity)
        let receipt = OperationReceipt(createdAt: Date())
        guard case .success(.awaitingApproval) = await helper.update(receipt: receipt) else { return XCTFail() }
        XCTAssertEqual(helper.state, .awaitingApproval)
        guard case .success(.awaitingApproval) = await helper.update(receipt: receipt) else { return XCTFail() }
        XCTAssertEqual(driver.updates, 1)
        driver.registration = .enabled
        driver.applied = false
        guard case .failure(.interruptedUpdate) = await helper.update(receipt: receipt) else { return XCTFail() }
        XCTAssertNotEqual(helper.state, .connected)
        driver.applied = true
        guard case .success(.connected) = await helper.update(receipt: receipt) else { return XCTFail() }
        XCTAssertEqual(driver.updates, 1)
    }
    func testOldProtocolIsUnsupportedAndDoesNotExecuteUpdate() async {
        let driver = J33Driver(), transport = J33Transport()
        transport.peer = HelperPeer(identifier: "test.helper", team: "TEST", protocolVersion: 1)
        let helper = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: J33Transport.identity)
        guard case .failure(.incompatibleVersion) = await helper.update(receipt: OperationReceipt(createdAt: Date())) else { return XCTFail() }
        XCTAssertEqual(driver.updates, 0)
        XCTAssertEqual(helper.state, .failed(.incompatibleVersion))
    }
    func testDeniedAndUntrustedReconnectNeverSucceed() async {
        for denied in [true, false] {
            let driver = J33Driver(), transport = J33Transport()
            let helper = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: J33Transport.identity)
            let receipt = OperationReceipt(createdAt: Date())
            _ = await helper.update(receipt: receipt)
            driver.registration = denied ? .disabled : .enabled
            if !denied { transport.peer = HelperPeer(identifier: "attacker", team: "TEST", protocolVersion: 2) }
            guard case .failure = await helper.update(receipt: receipt) else { return XCTFail() }
            XCTAssertNotEqual(helper.state, .connected)
        }
    }
    func testLaterReturnsToPanelWithoutChangingPreferences() {
        let router = AppRouter()
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.componentReadings = true
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        router.helperUpdate.returnToPanel = { router.showStatusPanel() }
        router.helperUpdate.later()
        XCTAssertEqual(destinations, [.statusPanel])
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertNil(router.helperUpdate.outcome)
    }
}
