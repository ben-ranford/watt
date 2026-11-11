import AppKit
import CryptoKit
import XCTest
import WattMaintenanceShared
@testable import Watt

@MainActor
final class UpdateHandoffTests: XCTestCase {
    func testEncodedBuildIsTheMarketingVersionInTheOfferHeadline() {
        XCTAssertEqual(manifest(1_001_000).offerVersion, "1.1.0")
        XCTAssertEqual(manifest(1_000_001).offerVersion, "1.0.1")
        XCTAssertEqual(manifest(1_002_003).offerVersion, "1.2.3")
        XCTAssertEqual(manifest(2).offerVersion, "2")
        XCTAssertEqual(UpdateAvailableContent.headline(version: "1.1.0"), "Watt? 1.1.0 is out")
        XCTAssertNotEqual(UpdateAvailableContent.headline(version: manifest(1_001_000).offerVersion), "Watt? 1001000 is out")
    }

    func testCheckOffersTheMarketingVersionAndNotesFollowThatString() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let bytes = Data("watt-1.1.0".utf8)
        let signed = try sign(key, manifest(1_001_000, sha256: Data(SHA256.hash(data: bytes)), notes: "### Fixes\n\n* relaunch"))
        let source = OfferSource()
        source.release = signed
        let trust = UpdateTrust(identity: "test.watt", currentBuild: 1_000_001,
                                hostSystemVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
                                publicKey: key.publicKey)
        let adapter = UpdateAdapter(source: source, driver: OfferDriver(), storage: InMemoryStorage(), trust: trust)
        guard case .success("1.1.0") = await adapter.check() else {
            return XCTFail("expected marketing version, state \(adapter.state)")
        }
        XCTAssertEqual(adapter.state, .available(version: "1.1.0"))
        XCTAssertEqual(adapter.releaseNotes(for: "1.1.0"), "### Fixes\n\n* relaunch")
        XCTAssertNil(adapter.releaseNotes(for: "1001000"))
    }

    func testCompletedRelaunchQuitsAndTimeoutKeepsTheReadyInstallRetryable() async throws {
        let script = InstallScript()
        script.next = [.failure(.timedOut), .success(.completed(OperationReceipt(createdAt: Date())))]
        let (router, receipt) = try await stageReady(script)
        var quit = false
        router.onMaintenanceHandoff = { quit = true }
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1.0",
                                               generation: router.updates.generation, receipt: receipt, presentation: presentation))
        await waitUntil { router.readyInstallFailure != nil }
        XCTAssertFalse(quit)
        XCTAssertNil(router.readyIntent)
        XCTAssertEqual(router.updates.state, .staged(receipt))
        XCTAssertEqual(router.readyInstallFailure?.message, AppRouter.readyInstallFailureMessage(.timedOut))
        XCTAssertEqual(router.readyReceipt, receipt)

        let retry = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1.0",
                                               generation: router.updates.generation, receipt: receipt, presentation: retry))
        await waitUntil { quit }
        XCTAssertTrue(quit)
        XCTAssertEqual(script.calls, 2)
        XCTAssertEqual(router.updates.state, .completed(receipt))
    }

    func testOtherInstallFailureReenablesTheButtons() async throws {
        let script = InstallScript()
        script.next = [.failure(.invalidData)]
        let (router, receipt) = try await stageReady(script)
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1.0",
                                               generation: router.updates.generation, receipt: receipt, presentation: presentation))
        await waitUntil { router.readyInstallFailure != nil }
        XCTAssertNil(router.readyIntent)
        XCTAssertEqual(router.updates.state, .staged(receipt))
        XCTAssertEqual(router.readyInstallFailure?.message, AppRouter.readyInstallFailureMessage(.invalidData))
        XCTAssertNotNil(router.beginReadyPresentation())
    }

    func testHandoffAcceptedQuitsEvenWhenConfirmQuitWouldCancel() async throws {
        XCTAssertEqual(UpdateHandoffQuit.reply(handoffRequiresQuit: true, confirmationAllowsQuit: false), .terminateNow)
        XCTAssertEqual(UpdateHandoffQuit.reply(handoffRequiresQuit: false, confirmationAllowsQuit: false), .terminateCancel)
        let delegate = WattApplicationDelegate()
        WattApplicationDelegate.handoffRequiresQuit = true
        defer { WattApplicationDelegate.handoffRequiresQuit = false }
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateNow)

        let script = InstallScript()
        script.next = [.success(.handoffAccepted(OperationReceipt(createdAt: Date())))]
        let (router, receipt) = try await stageReady(script)
        var quit = false
        router.onMaintenanceHandoff = { quit = true }
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1.0",
                                               generation: router.updates.generation, receipt: receipt, presentation: presentation))
        await waitUntil { quit }
        XCTAssertTrue(quit)
        XCTAssertEqual(router.updates.state, .handoffAccepted(receipt))
    }

    func testSupersededInstallDoesNotLeaveTheButtonsDisabled() async throws {
        let script = InstallScript()
        let (router, receipt) = try await stageReady(script)
        router.configureUpdateInstallation { [weak router] _ in
            _ = await router?.updates.renewGeneration()
            return .failure(.timedOut)
        }
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1.0",
                                               generation: router.updates.generation, receipt: receipt, presentation: presentation))
        await waitUntil { router.readyIntent == nil && router.readyInstallFailure != nil }
        XCTAssertNil(router.readyIntent)
        XCTAssertEqual(router.readyInstallFailure?.message, AppRouter.readyInstallFailureMessage(.cancelled))
        XCTAssertEqual(router.updates.state, .staged(receipt))
    }

    func testHandshakeTransportTimeoutIsDistinctFromAnOversizedFrame() {
        let timedOut = AuthenticatedUpdateProcessWitness.classifyHandshakeTransportError(MaintenanceProtocolError.invalidRequest)
        guard let failure = timedOut as? ServiceFailure else { return XCTFail("timeout must be a service failure") }
        XCTAssertEqual(failure, .timedOut)
        let oversized = AuthenticatedUpdateProcessWitness.classifyHandshakeTransportError(MaintenanceProtocolError.oversized)
        guard let protocolError = oversized as? MaintenanceProtocolError, case .oversized = protocolError else {
            return XCTFail("oversized frames stay protocol errors")
        }
    }

    func testStartupEvidenceDoesNotKeepTheProcessAHandshakeChild() throws {
        let request = try UpdateLaunchRequest(receipt: OperationReceipt(createdAt: Date()), identity: "test.watt",
                                              build: 1_001_000, minimumSystemVersion: "13.0", challenge: Data(repeating: 3, count: 32))
        UpdateLaunchAcknowledgementService.retainStartupEvidenceForTesting(request)
        defer { UpdateLaunchAcknowledgementService.retireHandshakeEvidence() }
        XCTAssertTrue(UpdateLaunchAcknowledgementService.isHandshakeChild)
        XCTAssertEqual(UpdateLaunchAcknowledgementService.acceptedRequest, request as UpdateLaunchRequest?)
        UpdateLaunchAcknowledgementService.retireHandshakeEvidence()
        XCTAssertFalse(UpdateLaunchAcknowledgementService.isHandshakeChild)
        XCTAssertNil(UpdateLaunchAcknowledgementService.acceptedRequest)
    }

    func testSingleInstanceAsksThenTerminatesOnlyOtherCopies() {
        let registry = FakeInstances()
        registry.instances = [
            AppInstance(processIdentifier: 10, bundleIdentifier: "io.github.ben-ranford.watt"),
            AppInstance(processIdentifier: 11, bundleIdentifier: "io.github.ben-ranford.watt"),
            AppInstance(processIdentifier: 12, bundleIdentifier: "other.app"),
            AppInstance(processIdentifier: 99, bundleIdentifier: "io.github.ben-ranford.watt")
        ]
        registry.polite = [10]
        let stopped = SingleInstanceClaim.becomeOnlyInstance(bundleIdentifier: "io.github.ben-ranford.watt",
                                                             currentProcessIdentifier: 99, registry: registry)
        XCTAssertEqual(registry.queried, ["io.github.ben-ranford.watt"])
        XCTAssertEqual(registry.requested, [10, 11])
        XCTAssertEqual(registry.forced, [11])
        XCTAssertEqual(stopped, [10, 11])
        XCTAssertFalse(registry.requested.contains(99))
        XCTAssertFalse(registry.forced.contains(12))
    }

    func testRelaunchedProcessDeliversTheHelperFollowUpOnce() async throws {
        let storage = InMemoryStorage()
        let receipt = OperationReceipt(createdAt: Date())
        try storage.write(JSONEncoder().encode(UpdateState.completed(receipt)), key: "update.v1")
        let store = UpdateStore(storage: storage)
        XCTAssertEqual(store.state, .completed(receipt))
        let key = Curve25519.Signing.PrivateKey()
        let trust = UpdateTrust(identity: "test.watt", currentBuild: 1,
                                hostSystemVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
                                publicKey: key.publicKey)
        let adapter = UpdateAdapter(source: OfferSource(), driver: OfferDriver(), storage: InMemoryStorage(), trust: trust)
        let router = AppRouter(updateService: adapter, updates: store)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        router.helperChangedAfterUpdate = { true }
        await router.recoverUpdateStartup(adapter: adapter)
        router.notePresentationReady()
        XCTAssertEqual(routes, [.update])
        router.notePresentationReady()
        XCTAssertEqual(routes, [.update])
    }

    func testSingleInstanceDoesNothingWhenThisProcessIsAlone() {
        let registry = FakeInstances()
        registry.instances = [AppInstance(processIdentifier: 4, bundleIdentifier: "io.github.ben-ranford.watt")]
        let stopped = SingleInstanceClaim.becomeOnlyInstance(bundleIdentifier: "io.github.ben-ranford.watt",
                                                             currentProcessIdentifier: 4, registry: registry)
        XCTAssertTrue(stopped.isEmpty)
        XCTAssertTrue(registry.requested.isEmpty)
        XCTAssertTrue(registry.forced.isEmpty)
        XCTAssertTrue(SingleInstanceClaim.becomeOnlyInstance(bundleIdentifier: "", currentProcessIdentifier: 4, registry: registry).isEmpty)
    }

    private func manifest(_ build: UInt64, sha256: Data = Data(repeating: 1, count: 32), notes: String? = nil) -> UpdateManifest {
        UpdateManifest(identity: "test.watt", build: build, sha256: sha256, minimumSystemVersion: "13.0", notes: notes)
    }

    private func sign(_ key: Curve25519.Signing.PrivateKey, _ manifest: UpdateManifest) throws -> SignedUpdate {
        let payload = try JSONEncoder().encode(manifest)
        return SignedUpdate(payload: payload, signature: try key.signature(for: payload))
    }

    private func stageReady(_ script: InstallScript) async throws -> (AppRouter, OperationReceipt) {
        let store = UpdateStore(storage: InMemoryStorage())
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1.0"), generation: store.generation)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        router.configureUpdateInstallation { await script.run($0) }
        XCTAssertTrue(router.startUpdateDownload(version: "1.1.0", generation: store.generation))
        for _ in 0..<40 { await Task.yield() }
        return (router, try XCTUnwrap(router.readyReceipt))
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<80 {
            if condition() { return }
            await Task.yield()
        }
    }
}

@MainActor
private final class InstallScript {
    var calls = 0
    var next: [ServiceOutcome<UpdateState>] = []
    func run(_ receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        calls += 1
        guard !next.isEmpty else { return .failure(.invalidData) }
        switch next.removeFirst() {
        case .success(.completed): return .success(.completed(receipt))
        case .success(.handoffAccepted): return .success(.handoffAccepted(receipt))
        case let other: return other
        }
    }
}

@MainActor
private final class FakeInstances: AppInstanceRegistry {
    var instances: [AppInstance] = []
    var polite: Set<Int32> = []
    var queried: [String] = []
    var requested: [Int32] = []
    var forced: [Int32] = []

    func runningInstances(bundleIdentifier: String) -> [AppInstance] {
        queried.append(bundleIdentifier)
        return instances
    }

    func requestTermination(_ instance: AppInstance) -> Bool {
        requested.append(instance.processIdentifier)
        guard polite.contains(instance.processIdentifier) else { return false }
        instances.removeAll { $0.processIdentifier == instance.processIdentifier }
        return true
    }

    func forceTermination(_ instance: AppInstance) -> Bool {
        forced.append(instance.processIdentifier)
        instances.removeAll { $0.processIdentifier == instance.processIdentifier }
        return true
    }
}

@MainActor
private final class OfferSource: UpdateSource {
    var release: SignedUpdate?
    func check() async throws -> SignedUpdate? { release }
    func download(_ release: SignedUpdate) async throws -> Data { Data() }
}

@MainActor
private final class OfferDriver: UpdateInstallationDriver {
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement { .original }
    func rollback(receipt: OperationReceipt) throws {}
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool { false }
    func discard(receipt: OperationReceipt) throws {}
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool { true }
}
