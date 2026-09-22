import XCTest
@testable import Watt

@MainActor
private final class RemovalMemoryDriver: OwnedRemovalDriver {
    let manifest: RemovalManifest
    var files: [String: String]
    var helperRunning = true
    var appRunning = true
    var saved: RemovalTransaction?
    var removed: [String: String] = [:]
    var calls: [RemovalManifest.Kind] = []
    var restored: [RemovalManifest.Kind] = []
    var fail: RemovalManifest.Kind?
    var failAfterEffect = false
    var restoreFailure: RemovalManifest.Kind?
    var failInventory = false
    var failSave = false
    var noEffect = false
    var retainProcess = false
    var retainApp = false
    var stopAppOnHelperRemoval = false
    var noRestore = false
    var suspended: CheckedContinuation<Void, Never>?
    var suspend = false
    let sentinel = "/fixture/unrelated/sentinel"
    init(_ manifest: RemovalManifest) {
        self.manifest = manifest
        files = Dictionary(uniqueKeysWithValues: manifest.resources.map { ($0.path, "owned-\($0.kind)") })
        files[sentinel] = "DO NOT TOUCH"
    }
    func inventory(manifest: RemovalManifest) async throws -> RemovalInventory {
        guard !failInventory else { throw ServiceFailure.unknownStatus }
        guard manifest == self.manifest else { throw ServiceFailure.untrustedIdentity }
        return RemovalInventory(presentPaths: Set(manifest.resources.map(\.path).filter { files[$0] != nil }),
                                helperRunning: helperRunning, appRunning: appRunning)
    }
    func transaction() throws -> RemovalTransaction? { saved }
    func save(_ transaction: RemovalTransaction) throws {
        if failSave { throw ServiceFailure.persistence }
        saved = transaction
    }
    func remove(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        guard transaction == saved, manifest.resources.contains(resource) else { throw ServiceFailure.untrustedIdentity }
        calls.append(resource.kind)
        if suspend { await withCheckedContinuation { suspended = $0 } }
        if fail == resource.kind && !failAfterEffect { throw ServiceFailure.denied }
        if !noEffect {
            if let value = files.removeValue(forKey: resource.path) { removed[resource.path] = value }
            if !retainProcess {
                if resource.kind == .helper {
                    helperRunning = false
                    if stopAppOnHelperRemoval { appRunning = false }
                }
                if resource.kind == .application && !retainApp { appRunning = false }
            }
        }
        if fail == resource.kind { throw ServiceFailure.disconnected }
    }
    func restore(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        if restoreFailure == resource.kind { throw ServiceFailure.persistence }
        if noRestore { return }
        guard let backup = removed[resource.path] else { return }
        guard files[resource.path] == nil else { throw ServiceFailure.untrustedIdentity }
        restored.append(resource.kind)
        files[resource.path] = backup
        removed[resource.path] = nil
        if resource.kind == .helper { helperRunning = transaction.baseline.helperRunning }
        if resource.kind == .application { appRunning = transaction.baseline.appRunning }
    }
}

@MainActor
private final class RemovalHelperDriver: HelperLifecycleDriver {
    let peer = HelperPeer(identifier: "fixture.helper", team: "FIXTURE", protocolVersion: 1)
    func status() async throws -> HelperRegistrationStatus { .enabled }
    func verifyCandidate() throws -> HelperPeer { peer }
    func register(receipt: OperationReceipt) async throws { XCTFail("must not register") }
    func update(receipt: OperationReceipt) async throws { XCTFail("must not update") }
    func unregister(receipt: OperationReceipt) async throws { XCTFail("owned driver owns removal") }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { false }
}

@MainActor
private final class RemovalTransport: HelperIPCTransport {
    var peer = HelperPeer(identifier: "fixture.helper", team: "FIXTURE", protocolVersion: 1)
    var failure: ServiceFailure?
    var badReply = false
    var connections = 0
    func connect() async throws -> HelperPeer {
        connections += 1
        if let failure { throw failure }
        return peer
    }
    func send(_ request: HelperMessage) async throws -> HelperMessage {
        badReply ? HelperMessage(requestID: UUID(), generation: request.generation,
                                 receiptID: request.receiptID, command: request.command) : request
    }
    func invalidate() {}
}

final class P05RemovalTests: XCTestCase {
    @MainActor private func fixture() throws -> (ScopedRemovalAdapter, RemovalMemoryDriver, RemovalTransport, OperationReceipt) {
        let manifest = RemovalManifest(installationID: UUID(), resources: [
            .init(path: "/fixture/app", kind: .application),
            .init(path: "/fixture/config", kind: .configuration),
            .init(path: "/fixture/helper", kind: .helper),
            .init(path: "/fixture/login", kind: .login)
        ])
        let driver = RemovalMemoryDriver(manifest)
        let transport = RemovalTransport()
        let helperDriver = RemovalHelperDriver()
        let helper = HelperLifecycleAdapter(driver: helperDriver, transport: transport, expectedPeer: helperDriver.peer)
        return (try ScopedRemovalAdapter(manifest: manifest, driver: driver, helper: helper), driver, transport,
                OperationReceipt(createdAt: Date(timeIntervalSince1970: 100)))
    }

    @MainActor func testOrderedSuccessAndSecondRetryPreservesSentinel() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .verifiedAbsent)
        XCTAssertEqual(driver.calls, [.login, .helper, .configuration, .application])
        XCTAssertEqual(driver.files, [driver.sentinel: "DO NOT TOUCH"])
        XCTAssertEqual(adapter.report?.remainingPaths, [])
        XCTAssertFalse(driver.appRunning)
        let retry = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(retry, .verifiedAbsent)
        XCTAssertEqual(driver.calls.count, 4)
    }

    @MainActor func testFailureAtEveryStepListsRemainingAndRetryIsSafe() async throws {
        for step in RemovalManifest.Kind.allCases {
            let (adapter, driver, _, receipt) = try fixture()
            driver.fail = step
            let result = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(result, .failed(.denied))
            XCTAssertEqual(adapter.report?.failedStep, step)
            XCTAssertEqual(Set(adapter.report!.remainingPaths), Set(driver.manifest.resources.filter { $0.kind.rawValue >= step.rawValue }.map(\.path)))
            XCTAssertEqual(driver.calls.last, step)
            driver.fail = nil
            let retry = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(retry, .verifiedAbsent)
            let calls = driver.calls
            let secondRetry = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(secondRetry, .verifiedAbsent)
            XCTAssertEqual(driver.calls, calls)
            XCTAssertEqual(driver.files[driver.sentinel], "DO NOT TOUCH")
        }
    }

    @MainActor func testAmbiguousFailureAfterEveryEffectReconcilesWithoutReplay() async throws {
        for step in RemovalManifest.Kind.allCases {
            let (adapter, driver, _, receipt) = try fixture()
            driver.fail = step; driver.failAfterEffect = true
            let result = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(result, .failed(.disconnected))
            XCTAssertFalse(adapter.report!.remainingPaths.contains(driver.manifest.resources.first { $0.kind == step }!.path))
            driver.fail = nil
            let retry = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(retry, .verifiedAbsent)
            XCTAssertEqual(driver.calls.filter { $0 == step }.count, 1)
        }
    }

    @MainActor func testHelperRemovalLeavesAppRunningAndOtherOwnedResourcesIntact() async throws {
        let (adapter, driver, transport, receipt) = try fixture()
        let result = await adapter.removeHelper(receipt: receipt)
        XCTAssertEqual(result, .verifiedAbsent)
        XCTAssertTrue(driver.appRunning)
        XCTAssertFalse(driver.helperRunning)
        XCTAssertEqual(driver.calls, [.helper])
        XCTAssertEqual(driver.files.count, 4)
        XCTAssertEqual(transport.connections, 1)
        let retry = await adapter.removeHelper(receipt: receipt)
        XCTAssertEqual(retry, .verifiedAbsent)
        XCTAssertEqual(driver.calls, [.helper])
    }

    @MainActor func testReconnectAuthenticatesEveryTime() async throws {
        let (adapter, driver, transport, _) = try fixture()
        let first = await adapter.reconnect()
        guard case .connected = first else { return XCTFail("not connected") }
        transport.peer = HelperPeer(identifier: "imposter", team: "FIXTURE", protocolVersion: 1)
        let second = await adapter.reconnect()
        guard case .failed(.untrustedIdentity) = second else { return XCTFail("accepted imposter") }
        XCTAssertEqual(transport.connections, 2)
        XCTAssertTrue(driver.calls.isEmpty)
    }

    @MainActor func testAuthenticationFailureBlocksHelperRemovalAndLaterSteps() async throws {
        let (adapter, driver, transport, receipt) = try fixture()
        transport.failure = .untrustedIdentity
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.untrustedIdentity))
        XCTAssertEqual(driver.calls, [.login])
        XCTAssertEqual(adapter.report?.remainingPaths.count, 3)
        XCTAssertTrue(driver.helperRunning)
    }

    @MainActor func testReconnectRejectsTimeoutAndUncorrelatedHandshake() async throws {
        let (adapter, _, transport, _) = try fixture()
        transport.failure = .timedOut
        let timeout = await adapter.reconnect()
        guard case .failed(.timedOut) = timeout else { return XCTFail("ignored timeout") }
        transport.failure = nil; transport.badReply = true
        let invalid = await adapter.reconnect()
        guard case .failed(.invalidData) = invalid else { return XCTFail("accepted bad reply") }
    }

    @MainActor func testNoOpDriverCannotClaimSuccess() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.noEffect = true
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.interruptedRemoval))
        XCTAssertEqual(adapter.report?.remainingPaths.count, 4)
    }

    @MainActor func testMissingBytesWithRunningHelperCannotClaimSuccess() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.retainProcess = true
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.interruptedRemoval))
        XCTAssertTrue(adapter.report!.inventory!.helperRunning)
        XCTAssertFalse(driver.calls.contains(.configuration))
    }

    @MainActor func testAlreadyAbsentPathsAreNotRemoved() async throws {
        let (adapter, driver, transport, receipt) = try fixture()
        driver.files = [driver.sentinel: "DO NOT TOUCH"]
        driver.helperRunning = false; driver.appRunning = false
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .verifiedAbsent)
        XCTAssertTrue(driver.calls.isEmpty)
        XCTAssertEqual(transport.connections, 0)
    }

    @MainActor func testUnknownInventoryFailsClosedAndListsAllPaths() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.failInventory = true
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.unknownStatus))
        XCTAssertEqual(adapter.report?.remainingPaths.count, 4)
        XCTAssertNil(adapter.report?.inventory)
        XCTAssertTrue(driver.calls.isEmpty)
    }

    @MainActor func testJournalFailurePreventsEffects() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.failSave = true
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.persistence))
        XCTAssertTrue(driver.calls.isEmpty)
    }

    @MainActor func testRestartRecoveryUsesSameManifestAndFreshInventory() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.fail = .configuration
        _ = await adapter.removeOwnedResources(receipt: receipt)
        let helper = FakeHelperService()
        let restarted = try ScopedRemovalAdapter(manifest: driver.manifest, driver: driver, helper: helper)
        let pending = await restarted.reconcile(receipt: receipt)
        XCTAssertEqual(pending, .interrupted(receipt))
        driver.fail = nil
        let retry = await restarted.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(retry, .verifiedAbsent)
        driver.files["/fixture/config"] = "reappeared"
        let staleSuccess = await restarted.reconcile(receipt: receipt)
        XCTAssertEqual(staleSuccess, .interrupted(receipt))
    }

    @MainActor func testReceiptAndScopeMismatchCannotEscalateCleanup() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        _ = await adapter.removeHelper(receipt: receipt)
        let wrongScope = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(wrongScope, .failed(.interruptedRemoval))
        let wrongReceipt = await adapter.removeHelper(receipt: .init(id: receipt.id, createdAt: .distantFuture))
        XCTAssertEqual(wrongReceipt, .failed(.invalidData))
        XCTAssertEqual(driver.calls, [.helper])
    }

    @MainActor func testRollbackAfterEveryPartialFailureRestoresBaselineAndIsIdempotent() async throws {
        for step in RemovalManifest.Kind.allCases {
            let (adapter, driver, _, receipt) = try fixture()
            let baseline = driver.files
            driver.fail = step; driver.failAfterEffect = true
            _ = await adapter.removeOwnedResources(receipt: receipt)
            if case .failure(let reason) = await adapter.rollback(receipt: receipt) { XCTFail("\(reason)") }
            XCTAssertEqual(driver.files, baseline)
            XCTAssertTrue(driver.appRunning); XCTAssertTrue(driver.helperRunning)
            XCTAssertEqual(driver.restored, driver.calls.reversed())
            let restores = driver.restored
            if case .failure(let reason) = await adapter.rollback(receipt: receipt) { XCTFail("\(reason)") }
            XCTAssertEqual(driver.restored, restores)
            let reconcile = await adapter.reconcile(receipt: receipt)
            XCTAssertEqual(reconcile, .interrupted(receipt))
        }
    }

    @MainActor func testRollbackFailureAtEveryStepCanRecover() async throws {
        for step in RemovalManifest.Kind.allCases {
            let (adapter, driver, _, receipt) = try fixture()
            let baseline = driver.files
            _ = await adapter.removeOwnedResources(receipt: receipt)
            driver.restoreFailure = step
            guard case .failure(.persistence) = await adapter.rollback(receipt: receipt) else { return XCTFail("false recovery success") }
            XCTAssertEqual(driver.saved?.phase, .rollingBack)
            let retryRemoval = await adapter.removeOwnedResources(receipt: receipt)
            XCTAssertEqual(retryRemoval, .failed(.interruptedRemoval))
            driver.restoreFailure = nil
            if case .failure(let reason) = await adapter.rollback(receipt: receipt) { XCTFail("\(reason)") }
            XCTAssertEqual(driver.files, baseline)
        }
    }

    @MainActor func testRollbackPreservesInterveningDataInsteadOfOverwriting() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        _ = await adapter.removeOwnedResources(receipt: receipt)
        driver.files["/fixture/config"] = "another owner's data"
        guard case .failure(.untrustedIdentity) = await adapter.rollback(receipt: receipt) else { return XCTFail("unsafe restore") }
        XCTAssertEqual(driver.files["/fixture/config"], "another owner's data")
        XCTAssertEqual(driver.files[driver.sentinel], "DO NOT TOUCH")
    }

    @MainActor func testMalformedAndOverlappingManifestRejected() throws {
        for paths in [["/"], ["relative"], ["/a/../b"], ["/a", "/a/b"], ["/a", "/a"], []] {
            let manifest = RemovalManifest(installationID: UUID(), resources: paths.map { .init(path: $0, kind: .helper) })
            XCTAssertThrowsError(try manifest.validate())
        }
    }

    @MainActor func testConcurrentRetryCannotDuplicateEffectsAndCancellationReportsReality() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.suspend = true
        let task = Task { await adapter.removeOwnedResources(receipt: receipt) }
        while driver.suspended == nil { await Task.yield() }
        let concurrent = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(concurrent, .interrupted(receipt))
        task.cancel()
        driver.suspended?.resume(); driver.suspended = nil; driver.suspend = false
        let result = await task.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertEqual(driver.calls, [.login])
        XCTAssertEqual(adapter.report?.remainingPaths.count, 3)
        let retry = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(retry, .verifiedAbsent)
    }
    @MainActor func testRunningAppPreventsFullUninstallSuccessEvenWithNoPaths() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.retainApp = true
        let result = await adapter.removeOwnedResources(receipt: receipt)
        XCTAssertEqual(result, .failed(.interruptedRemoval))
        XCTAssertEqual(adapter.report?.remainingPaths, [])
        XCTAssertEqual(adapter.report?.inventory?.appRunning, true)
        let recovered = await adapter.reconcile(receipt: receipt)
        XCTAssertEqual(recovered, .interrupted(receipt))
    }

    @MainActor func testRollbackNoOpCannotClaimRestoration() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        _ = await adapter.removeOwnedResources(receipt: receipt)
        driver.noRestore = true
        guard case .failure(.interruptedRemoval) = await adapter.rollback(receipt: receipt) else {
            return XCTFail("false rollback success")
        }
        XCTAssertEqual(driver.saved?.phase, .rollingBack)
    }

    @MainActor func testForeignInstallationJournalRejected() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        _ = await adapter.removeHelper(receipt: receipt)
        let foreign = RemovalManifest(installationID: UUID(), resources: driver.manifest.resources)
        let other = try ScopedRemovalAdapter(manifest: foreign, driver: driver, helper: FakeHelperService())
        let result = await other.reconcile(receipt: receipt)
        XCTAssertEqual(result, .failed(.invalidData))
        XCTAssertEqual(driver.calls, [.helper])
    }

    @MainActor func testReconcileWithoutJournalCannotClaimSuccess() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.files = [driver.sentinel: "DO NOT TOUCH"]
        driver.helperRunning = false; driver.appRunning = false
        let result = await adapter.reconcile(receipt: receipt)
        XCTAssertEqual(result, .failed(.unknownStatus))
    }

    @MainActor func testHelperRetryCannotHideUnexpectedAppExit() async throws {
        let (adapter, driver, _, receipt) = try fixture()
        driver.stopAppOnHelperRemoval = true
        let first = await adapter.removeHelper(receipt: receipt)
        XCTAssertEqual(first, .failed(.interruptedRemoval))
        let retry = await adapter.removeHelper(receipt: receipt)
        XCTAssertEqual(retry, .failed(.interruptedRemoval))
        let recovered = await adapter.reconcile(receipt: receipt)
        XCTAssertEqual(recovered, .interrupted(receipt))
        XCTAssertEqual(driver.calls, [.helper])
    }

}
