import CryptoKit
import XCTest
@testable import Watt

@MainActor
private final class P04Source: UpdateSource {
    var release: SignedUpdate?
    var bytes = Data()
    var error: ServiceFailure?
    var suspended: CheckedContinuation<Data, Error>?
    var suspend = false
    func check() async throws -> SignedUpdate? { if let error { throw error }; return release }
    func download(_ release: SignedUpdate) async throws -> Data {
        if let error { throw error }
        if suspend { return try await withCheckedThrowingContinuation { suspended = $0 } }
        return bytes
    }
}

// No filesystem install/launch: only this driver's private dictionaries may change.
@MainActor
private final class P04Installation: UpdateInstallationDriver {
    struct Artifact: Codable { let identity: String; let build: UInt64 }
    let original: Data
    let originalSignature: Data
    let originalKey: Curve25519.Signing.PublicKey
    var installed: Data
    var staged: [UUID: Data] = [:]
    var receipts: [UUID: OperationReceipt] = [:]
    var running: OperationReceipt?
    var runningBytes: Data?
    var failure: String?
    var replacementCount = 0
    var launchCount = 0
    var discardLeavesArtifact = false
    var unrelated = Data("unrelated install and preferences sentinel".utf8)
    init() {
        let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
        original = try! JSONEncoder().encode(Artifact(identity: "test.watt", build: 1))
        originalSignature = try! key.signature(for: original)
        originalKey = key.publicKey
        installed = original
    }
    func fail(_ step: String) throws { if failure == step { throw ServiceFailure.interruptedUpdate } }
    func valid(_ bytes: Data, _ manifest: UpdateManifest) -> Bool {
        guard let artifact = try? JSONDecoder().decode(Artifact.self, from: bytes) else { return false }
        return artifact.identity == manifest.identity && artifact.build == manifest.build && Data(SHA256.hash(data: bytes)) == manifest.sha256
    }
    func exact(_ receipt: OperationReceipt) throws {
        guard receipts[receipt.id] == receipt else { throw ServiceFailure.invalidData }
    }
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try fail("stage")
        guard valid(bytes, manifest) else { throw ServiceFailure.untrustedIdentity }
        receipts[receipt.id] = receipt; staged[receipt.id] = bytes
    }
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try exact(receipt); try fail("verify")
        guard let bytes = staged[receipt.id], valid(bytes, manifest) else { throw ServiceFailure.untrustedIdentity }
    }
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try verifyStaged(manifest: manifest, receipt: receipt)
        replacementCount += 1
        try fail("beforeReplace")
        if failure == "partialReplace" { installed = Data(); throw ServiceFailure.interruptedUpdate }
        installed = staged[receipt.id]!
        try fail("afterReplace")
    }
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement {
        try exact(receipt); try fail("placement")
        if installed == original && originalKey.isValidSignature(originalSignature, for: installed) { return .original }
        return valid(installed, manifest) ? .replacement : .uncertain
    }
    func rollback(receipt: OperationReceipt) throws { try exact(receipt); try fail("rollback"); installed = original }
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try exact(receipt); try fail("launch")
        guard valid(installed, manifest) else { throw ServiceFailure.untrustedIdentity }
        launchCount += 1; running = receipt; runningBytes = installed
    }
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool {
        try exact(receipt)
        return running == receipt && runningBytes == installed && valid(installed, manifest)
    }
    func discard(receipt: OperationReceipt) throws {
        if let known = receipts[receipt.id], known != receipt { throw ServiceFailure.invalidData }
        try fail("discard")
        if !discardLeavesArtifact { staged[receipt.id] = nil }
    }
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool { staged[receipt.id] == nil }
}

@MainActor
private final class P04DiskJournal: PreferenceStorage {
    let url: URL
    init(url: URL) { self.url = url }
    func read(key: String) throws -> Data? {
        FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    }
    func write(_ data: Data, key: String) throws { try data.write(to: url, options: .atomic) }
}

@MainActor
private final class P04FailingJournal: PreferenceStorage {
    let memory = InMemoryStorage()
    var writes = 0
    var failingWrite = 0
    func read(key: String) throws -> Data? { try memory.read(key: key) }
    func write(_ data: Data, key: String) throws {
        writes += 1
        if writes == failingWrite { throw ServiceFailure.persistence }
        try memory.write(data, key: key)
    }
}

final class P04UpdaterTests: XCTestCase {
    @MainActor
    private final class Rig {
        let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
        let source = P04Source()
        let driver = P04Installation()
        let memory = InMemoryStorage()
        let receipt = OperationReceipt(createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        var host = OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 1)
        var trust: UpdateTrust { .init(identity: "test.watt", currentBuild: 1, hostSystemVersion: host, publicKey: key.publicKey) }
        var storage: any PreferenceStorage
        var adapter: UpdateAdapter!
        init(storage: (any PreferenceStorage)? = nil) throws {
            self.storage = storage ?? memory
            try release()
            restart()
        }
        func restart() { adapter = UpdateAdapter(source: source, driver: driver, storage: storage, trust: trust) }
        func release(identity: String = "test.watt", build: UInt64 = 2, artifactIdentity: String = "test.watt", minimumSystemVersion: String = "13.0") throws {
            source.bytes = try JSONEncoder().encode(P04Installation.Artifact(identity: artifactIdentity, build: build))
            let payload = try JSONEncoder().encode(UpdateManifest(identity: identity, build: build, sha256: Data(SHA256.hash(data: source.bytes)), minimumSystemVersion: minimumSystemVersion))
            source.release = SignedUpdate(payload: payload, signature: try key.signature(for: payload))
        }
        func stage() async throws {
            guard case .success(.some("2")) = await adapter.check(),
                  case .success(.staged(receipt)) = await adapter.download(version: "2", receipt: receipt) else {
                throw ServiceFailure.invalidData
            }
        }
        func install() async throws -> ServiceOutcome<UpdateState> {
            try await stage(); try adapter.confirmInstall(receipt: receipt)
            return await adapter.install(receipt: receipt)
        }
    }
    private func expect<T>(_ outcome: ServiceOutcome<T>, _ failure: ServiceFailure, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let actual) = outcome else { return XCTFail("Expected failure \(failure)", file: file, line: line) }
        XCTAssertEqual(actual, failure, file: file, line: line)
    }
    private func expect(_ outcome: ServiceOutcome<UpdateState>, state: UpdateState, file: StaticString = #filePath, line: UInt = #line) {
        guard case .success(let actual) = outcome else { return XCTFail("Expected \(state), got \(outcome)", file: file, line: line) }
        XCTAssertEqual(actual, state, file: file, line: line)
    }

    @MainActor func testJ33ComposedBoundaryRequiresSignedRelaunchAndRenewedApproval() async throws {
        let rig = try Rig()
        _ = try await rig.install()
        let driver = J33Driver(), transport = J33Transport()
        let helper = HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: J33Transport.identity)
        let prompt = HelperUpdatePrompt()
        prompt.configure(updater: rig.adapter, appReceipt: rig.receipt, helper: helper)
        await prompt.update()
        XCTAssertEqual(driver.updates, 0)
        guard case .failure(.interruptedUpdate) = prompt.outcome else { return XCTFail() }
        _ = await rig.adapter.relaunch(receipt: rig.receipt)
        // Merely configuring or deferring never invokes installation.
        prompt.later()
        XCTAssertEqual(driver.updates, 0)
        await prompt.update()
        guard case .success(.awaitingApproval) = prompt.outcome else { return XCTFail() }
        XCTAssertEqual(driver.updates, 1)
        driver.registration = .enabled
        await prompt.update()
        guard case .success(.connected) = prompt.outcome else { return XCTFail() }
        XCTAssertEqual(driver.updates, 1)
    }

    @MainActor func testJ33FailuresPublishReceiptScopedRecoveryState() async throws {
        let rig = try Rig()
        _ = await rig.adapter.check()
        rig.source.error = .network
        expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .network)
        XCTAssertEqual(rig.adapter.state, .failed(.network, rig.receipt))
        let installRig = try Rig()
        installRig.driver.failure = "afterReplace"
        expect(try await installRig.install(), .interruptedUpdate)
        XCTAssertEqual(installRig.adapter.state, .failed(.interruptedUpdate, installRig.receipt))
        installRig.driver.failure = nil
        expect(await installRig.adapter.recover(receipt: installRig.receipt), state: .awaitingRelaunch(installRig.receipt))
        installRig.driver.failure = "launch"
        expect(await installRig.adapter.relaunch(receipt: installRig.receipt), .interruptedUpdate)
        XCTAssertEqual(installRig.adapter.state, .failed(.interruptedUpdate, installRig.receipt))
    }

    @MainActor func testMinimumSystemVersionCurrentAndOlderCandidates() async throws {
        for minimum in ["14.2.1", "14.2", "14.2.0", "14.1.99", "13.99.99"] {
            let rig = try Rig(); try rig.release(minimumSystemVersion: minimum)
            expect(try await rig.install(), state: .awaitingRelaunch(rig.receipt))
        }
    }
    @MainActor func testMinimumSystemVersionNewerCandidatesHaveNoEffects() async throws {
        for minimum in ["14.2.2", "14.3", "15.0"] {
            let rig = try Rig(); try rig.release(minimumSystemVersion: minimum)
            expect(await rig.adapter.check(), .incompatibleVersion)
            expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .invalidData)
            XCTAssertTrue(rig.driver.staged.isEmpty)
            XCTAssertEqual(rig.driver.replacementCount, 0)
            XCTAssertNil(try rig.storage.read(key: "updater.transactions.v1"))
        }
    }
    @MainActor func testMinimumSystemVersionMalformedOrMissingRejected() async throws {
        let malformed = ["", "14", "14.", ".2", "14..2", "14.2.1.0", "14.-1", "+14.2",
                         "14.2beta", " 14.2", "14.2\n", "014.2", "14.02", "0.2", "１４.2",
                         "999999999999999999999999.0"]
        for minimum in malformed {
            let rig = try Rig(); try rig.release(minimumSystemVersion: minimum)
            expect(await rig.adapter.check(), .invalidData)
            XCTAssertTrue(rig.driver.staged.isEmpty)
            XCTAssertEqual(rig.driver.replacementCount, 0)
        }
        for value in [nil, NSNull(), 14] as [Any?] {
            let rig = try Rig()
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: rig.source.release!.payload) as? [String: Any])
            payload["minimumSystemVersion"] = value
            let bytes = try JSONSerialization.data(withJSONObject: payload)
            rig.source.release = SignedUpdate(payload: bytes, signature: try rig.key.signature(for: bytes))
            expect(await rig.adapter.check(), .invalidData)
            XCTAssertTrue(rig.driver.staged.isEmpty)
            XCTAssertEqual(rig.driver.replacementCount, 0)
        }
    }
    @MainActor func testMinimumSystemVersionRecheckedBeforeInstallWithoutBlockingCleanup() async throws {
        let rig = try Rig(); try rig.release(minimumSystemVersion: "14.2.1"); try await rig.stage()
        rig.host = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
        rig.restart(); try rig.adapter.confirmInstall(receipt: rig.receipt)
        expect(await rig.adapter.install(receipt: rig.receipt), .incompatibleVersion)
        XCTAssertEqual(rig.driver.replacementCount, 0)
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .staged(rig.receipt))
        guard case .success = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
        XCTAssertTrue(rig.driver.staged.isEmpty)
    }

    @MainActor func testSignedInstallRelaunchRestartAndSentinel() async throws {
        let rig = try Rig()
        let sentinel = rig.driver.unrelated
        expect(try await rig.install(), state: .awaitingRelaunch(rig.receipt))
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .awaitingRelaunch(rig.receipt))
        expect(await rig.adapter.relaunch(receipt: rig.receipt), state: .completed(rig.receipt))
        rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .completed(rig.receipt))
        XCTAssertEqual(rig.driver.replacementCount, 1); XCTAssertEqual(rig.driver.launchCount, 1)
        XCTAssertEqual(rig.driver.unrelated, sentinel)
    }
    @MainActor func testNoUpdateAndNetworkFailureRetry() async throws {
        let rig = try Rig(); rig.source.release = nil
        guard case .success(nil) = await rig.adapter.check() else { return XCTFail() }
        rig.source.error = .network; expect(await rig.adapter.check(), .network)
        rig.source.error = nil; try rig.release(); try await rig.stage()
    }
    @MainActor func testInvalidSignatureWrongIdentityAndDowngrade() async throws {
        let rig = try Rig()
        rig.source.release = SignedUpdate(payload: rig.source.release!.payload, signature: Data(repeating: 0, count: 64))
        expect(await rig.adapter.check(), .untrustedIdentity)
        try rig.release(identity: "other.app"); expect(await rig.adapter.check(), .untrustedIdentity)
        try rig.release(build: 1); expect(await rig.adapter.check(), .incompatibleVersion)
        try rig.release(build: 0); expect(await rig.adapter.check(), .incompatibleVersion)
        XCTAssertEqual(rig.driver.replacementCount, 0)
    }
    @MainActor func testCorruptDownloadNeverStages() async throws {
        let rig = try Rig(); _ = await rig.adapter.check(); rig.source.bytes.append(0)
        expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .invalidData)
        XCTAssertTrue(rig.driver.staged.isEmpty); XCTAssertEqual(rig.driver.installed, rig.driver.original)
    }
    @MainActor func testSignedManifestCannotOverrideArtifactIdentity() async throws {
        let rig = try Rig(); try rig.release(artifactIdentity: "other.app"); _ = await rig.adapter.check()
        expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .untrustedIdentity)
        XCTAssertTrue(rig.driver.staged.isEmpty)
    }
    @MainActor func testConfirmationRequiredAndNotRestored() async throws {
        let rig = try Rig(); try await rig.stage()
        expect(await rig.adapter.install(receipt: rig.receipt), .denied)
        try rig.adapter.confirmInstall(receipt: rig.receipt); rig.restart()
        expect(await rig.adapter.install(receipt: rig.receipt), .denied)
        XCTAssertEqual(rig.driver.replacementCount, 0)
    }
    @MainActor func testStagedArtifactRevalidatedBeforeInstallAndRecovery() async throws {
        let rig = try Rig(); try await rig.stage(); try rig.adapter.confirmInstall(receipt: rig.receipt)
        rig.driver.staged[rig.receipt.id] = Data()
        expect(await rig.adapter.install(receipt: rig.receipt), .untrustedIdentity)
        expect(await rig.adapter.recover(receipt: rig.receipt), .untrustedIdentity)
        XCTAssertEqual(rig.driver.replacementCount, 0)
    }
    @MainActor func testExactReceiptNotOnlyUUID() async throws {
        let rig = try Rig(); try await rig.stage()
        let wrong = OperationReceipt(id: rig.receipt.id, createdAt: rig.receipt.createdAt.addingTimeInterval(1))
        expect(await rig.adapter.install(receipt: wrong), .invalidData)
        expect(await rig.adapter.cancel(receipt: wrong), .invalidData)
        expect(await rig.adapter.discard(receipt: wrong), .invalidData)
        expect(await rig.adapter.recover(receipt: wrong), .invalidData)
        XCTAssertEqual(rig.driver.staged.count, 1)
    }
    @MainActor func testCancelledDiscardedReceiptCannotBeReusedAcrossRestart() async throws {
        let rig = try Rig(); try await rig.stage()
        expect(await rig.adapter.cancel(receipt: rig.receipt), state: .failed(.cancelled, rig.receipt))
        for _ in 0..<2 {
            guard case .success(let receipt) = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
            XCTAssertEqual(receipt, rig.receipt); rig.restart()
        }
        _ = await rig.adapter.check()
        expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .invalidData)
        XCTAssertTrue(rig.driver.staged.isEmpty)
        let fresh = OperationReceipt(createdAt: rig.receipt.createdAt)
        expect(await rig.adapter.download(version: "2", receipt: fresh), state: .staged(fresh))
    }
    @MainActor func testCancelSuspendedDownloadRejectsLateReplyAndConcurrentWork() async throws {
        let rig = try Rig(); _ = await rig.adapter.check(); rig.source.suspend = true
        let task = Task { await rig.adapter.download(version: "2", receipt: rig.receipt) }
        while rig.source.suspended == nil { await Task.yield() }
        expect(await rig.adapter.check(), .interruptedUpdate)
        expect(await rig.adapter.cancel(receipt: rig.receipt), state: .failed(.cancelled, rig.receipt))
        expect(await rig.adapter.discard(receipt: rig.receipt), .interruptedUpdate)
        rig.source.suspended!.resume(returning: rig.source.bytes)
        expect(await task.value, .cancelled)
        XCTAssertTrue(rig.driver.staged.isEmpty)
    }
    @MainActor func testJ104FailedCancellationJournalStillInvalidatesLateDownload() async throws {
        let rig = try Rig(); _ = await rig.adapter.check(); rig.source.suspend = true
        let task = Task { await rig.adapter.download(version: "2", receipt: rig.receipt) }
        while rig.source.suspended == nil { await Task.yield() }
        rig.memory.failWrites = true
        expect(await rig.adapter.cancel(receipt: rig.receipt), .persistence)
        rig.source.suspended!.resume(returning: rig.source.bytes)
        expect(await task.value, .cancelled)
        XCTAssertEqual(rig.adapter.state, .failed(.persistence, rig.receipt))
        XCTAssertTrue(rig.driver.staged.isEmpty)
        rig.memory.failWrites = false
        expect(await rig.adapter.cancel(receipt: rig.receipt), state: .failed(.cancelled, rig.receipt))
        guard case .success(let receipt) = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
        XCTAssertEqual(receipt, rig.receipt)
    }

    @MainActor func testInterruptedReplacementRecoveryAtEveryBoundary() async throws {
        for point in ["beforeReplace", "partialReplace", "afterReplace"] {
            let rig = try Rig(); rig.driver.failure = point
            expect(try await rig.install(), .interruptedUpdate)
            rig.driver.failure = nil; rig.restart()
            let expected: UpdateState = point == "afterReplace" ? .awaitingRelaunch(rig.receipt) : .failed(.interruptedUpdate, rig.receipt)
            expect(await rig.adapter.recover(receipt: rig.receipt), state: expected)
            XCTAssertEqual(rig.driver.replacementCount, 1)
            XCTAssertEqual(rig.driver.installed, point == "afterReplace" ? rig.source.bytes : rig.driver.original)
            XCTAssertEqual(rig.driver.launchCount, 0)
        }
    }
    @MainActor func testRollbackFailureRemainsRecoverable() async throws {
        let rig = try Rig(); rig.driver.failure = "partialReplace"; _ = try await rig.install()
        rig.driver.failure = "rollback"; expect(await rig.adapter.recover(receipt: rig.receipt), .interruptedUpdate)
        rig.driver.failure = nil; rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .failed(.interruptedUpdate, rig.receipt))
        XCTAssertEqual(rig.driver.installed, rig.driver.original)
    }
    @MainActor func testRelaunchFailureWrongRunningReceiptAndRetry() async throws {
        let rig = try Rig(); _ = try await rig.install(); rig.driver.failure = "launch"
        expect(await rig.adapter.relaunch(receipt: rig.receipt), .interruptedUpdate)
        rig.driver.running = OperationReceipt(createdAt: rig.receipt.createdAt); rig.driver.runningBytes = rig.source.bytes
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .awaitingRelaunch(rig.receipt))
        rig.driver.failure = nil
        expect(await rig.adapter.relaunch(receipt: rig.receipt), state: .completed(rig.receipt))
    }
    @MainActor func testPostInstallCancelDiscardAndReplayRejected() async throws {
        let rig = try Rig(); _ = try await rig.install()
        expect(await rig.adapter.cancel(receipt: rig.receipt), .interruptedUpdate)
        expect(await rig.adapter.discard(receipt: rig.receipt), .interruptedUpdate)
        expect(await rig.adapter.install(receipt: rig.receipt), .denied)
        XCTAssertEqual(rig.driver.installed, rig.source.bytes)
    }
    @MainActor func testPersistenceFailurePreventsEffectsAndRetryPreservesReceipt() async throws {
        let rig = try Rig(); _ = await rig.adapter.check(); rig.memory.failWrites = true
        expect(await rig.adapter.download(version: "2", receipt: rig.receipt), .persistence)
        XCTAssertTrue(rig.driver.staged.isEmpty)
        rig.memory.failWrites = false; try await rig.stage(); try rig.adapter.confirmInstall(receipt: rig.receipt)
        rig.memory.failWrites = true; expect(await rig.adapter.install(receipt: rig.receipt), .persistence)
        XCTAssertEqual(rig.driver.replacementCount, 0)
        rig.memory.failWrites = false
        expect(await rig.adapter.install(receipt: rig.receipt), state: .awaitingRelaunch(rig.receipt))
    }
    @MainActor func testDiscardRequiresAbsenceAndCanRetry() async throws {
        let rig = try Rig(); try await rig.stage(); rig.driver.discardLeavesArtifact = true
        expect(await rig.adapter.discard(receipt: rig.receipt), .interruptedUpdate)
        expect(await rig.adapter.install(receipt: rig.receipt), .denied)
        rig.driver.discardLeavesArtifact = false
        guard case .success = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
    }
    @MainActor func testDurableAtomicJournalRestartAndCorruptionFailClosed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) } // only the test's unique directory
        let url = directory.appendingPathComponent("journal.json")
        let sentinel = directory.appendingPathComponent("unrelated")
        try Data("keep".utf8).write(to: sentinel)
        let rig = try Rig(storage: P04DiskJournal(url: url)); _ = try await rig.install()
        rig.storage = P04DiskJournal(url: url); rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .awaitingRelaunch(rig.receipt))
        expect(await rig.adapter.relaunch(receipt: rig.receipt), state: .completed(rig.receipt))
        try Data("broken".utf8).write(to: url, options: .atomic); rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), .persistence)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("keep".utf8))
    }
    @MainActor func testJournalSignatureTamperAndReadFailure() async throws {
        let rig = try Rig(); try await rig.stage()
        let key = "updater.transactions.v1"
        let entries = try JSONDecoder().decode([UpdateTransaction].self, from: rig.memory.values[key]!)
        let entry = entries[0]
        rig.memory.values[key] = try JSONEncoder().encode([UpdateTransaction(receipt: entry.receipt, release: SignedUpdate(payload: entry.release.payload, signature: Data()), phase: .staged)])
        expect(await rig.adapter.recover(receipt: rig.receipt), .untrustedIdentity)
        rig.memory.failReads = true; expect(await rig.adapter.recover(receipt: rig.receipt), .persistence)
    }
    @MainActor func testCompletedBuildCannotBeOfferedAgainAndNewBinaryCanRecover() async throws {
        let rig = try Rig(); _ = try await rig.install()
        _ = await rig.adapter.relaunch(receipt: rig.receipt)
        expect(await rig.adapter.check(), .incompatibleVersion)
        let newTrust = UpdateTrust(identity: "test.watt", currentBuild: 2, hostSystemVersion: rig.host, publicKey: rig.key.publicKey)
        let newProcess = UpdateAdapter(source: rig.source, driver: rig.driver, storage: rig.storage, trust: newTrust)
        expect(await newProcess.recover(receipt: rig.receipt), state: .completed(rig.receipt))
    }
    @MainActor func testTaskCancellationDoesNotStageLateDownload() async throws {
        let rig = try Rig(); _ = await rig.adapter.check(); rig.source.suspend = true
        let task = Task { await rig.adapter.download(version: "2", receipt: rig.receipt) }
        while rig.source.suspended == nil { await Task.yield() }
        task.cancel(); rig.source.suspended!.resume(returning: rig.source.bytes)
        expect(await task.value, .cancelled)
        rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .failed(.interruptedUpdate, rig.receipt))
        XCTAssertTrue(rig.driver.staged.isEmpty)
    }
    @MainActor func testStageVerificationNetworkAndCleanupFailuresRemainRecoverable() async throws {
        for point in ["stage", "verify", "network"] {
            let rig = try Rig(); _ = await rig.adapter.check()
            if point == "network" { rig.source.error = .network } else { rig.driver.failure = point }
            expect(await rig.adapter.download(version: "2", receipt: rig.receipt), point == "network" ? .network : .interruptedUpdate)
            rig.restart(); expect(await rig.adapter.recover(receipt: rig.receipt), state: .failed(.interruptedUpdate, rig.receipt))
            rig.driver.failure = "discard"
            expect(await rig.adapter.discard(receipt: rig.receipt), .interruptedUpdate)
            rig.driver.failure = nil
            guard case .success = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
            XCTAssertTrue(rig.driver.staged.isEmpty)
        }
    }
    @MainActor func testInstalledCorruptionNeverLaunchesAndRecoveryRestoresOriginal() async throws {
        let rig = try Rig(); _ = try await rig.install(); rig.driver.installed = Data("corrupt".utf8)
        expect(await rig.adapter.relaunch(receipt: rig.receipt), .untrustedIdentity)
        XCTAssertEqual(rig.driver.launchCount, 0)
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .failed(.interruptedUpdate, rig.receipt))
        XCTAssertEqual(rig.driver.installed, rig.driver.original)
    }
    @MainActor func testDuplicateJournalReceiptsAndWrongVersionFailClosed() async throws {
        let rig = try Rig(); _ = await rig.adapter.check()
        expect(await rig.adapter.download(version: "3", receipt: rig.receipt), .invalidData)
        try await rig.stage()
        let key = "updater.transactions.v1"
        let entries = try JSONDecoder().decode([UpdateTransaction].self, from: rig.memory.values[key]!)
        rig.memory.values[key] = try JSONEncoder().encode(entries + entries)
        expect(await rig.adapter.recover(receipt: rig.receipt), .invalidData)
        XCTAssertEqual(rig.driver.replacementCount, 0)
    }

    @MainActor func testPostReplacementAndCompletionWriteFailuresRecoverWithoutReplay() async throws {
        let storage = P04FailingJournal(); storage.failingWrite = 4
        let rig = try Rig(storage: storage)
        expect(try await rig.install(), .persistence)
        XCTAssertEqual(rig.driver.installed, rig.source.bytes)
        rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .awaitingRelaunch(rig.receipt))
        storage.failingWrite = storage.writes + 1
        expect(await rig.adapter.relaunch(receipt: rig.receipt), .persistence)
        rig.restart()
        expect(await rig.adapter.recover(receipt: rig.receipt), state: .completed(rig.receipt))
        XCTAssertEqual(rig.driver.replacementCount, 1); XCTAssertEqual(rig.driver.launchCount, 1)
    }
    @MainActor func testDiscardTombstoneWriteFailureCanRetryButCannotInstall() async throws {
        let storage = P04FailingJournal(); let rig = try Rig(storage: storage); try await rig.stage()
        storage.failingWrite = 4
        expect(await rig.adapter.discard(receipt: rig.receipt), .persistence)
        XCTAssertTrue(rig.driver.staged.isEmpty)
        rig.restart(); expect(await rig.adapter.install(receipt: rig.receipt), .denied)
        guard case .success = await rig.adapter.discard(receipt: rig.receipt) else { return XCTFail() }
    }

}
