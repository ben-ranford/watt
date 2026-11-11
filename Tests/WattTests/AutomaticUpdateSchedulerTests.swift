import CryptoKit
import XCTest
@testable import Watt

@MainActor
final class AutomaticUpdateSchedulerTests: XCTestCase {
    private func settle() async {
        for _ in 0..<40 { await Task.yield() }
    }

    private func wait(until condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            await Task.yield()
        }
    }

    private func timing(launch: TimeInterval = 0, interval: TimeInterval = 100,
                        backoff: TimeInterval = 10, maximum: TimeInterval = 40,
                        busy: TimeInterval = 7, jitter: Double = 0) -> AutomaticUpdateTiming {
        AutomaticUpdateTiming(launchDelay: launch, interval: interval, jitterFraction: jitter,
                              initialBackoff: backoff, maximumBackoff: maximum, busyRetry: busy, minimumDelay: 0)
    }

    func testProductionTimingUsesADailyIntervalWithBoundedJitterAndBackoff() {
        let production = AutomaticUpdateTiming.production
        XCTAssertEqual(production.launchDelay, 30)
        XCTAssertEqual(production.interval, 24 * 60 * 60)
        XCTAssertEqual(production.jitterFraction, 0.10)
        XCTAssertEqual(production.initialBackoff, 15 * 60)
        XCTAssertEqual(production.maximumBackoff, 6 * 60 * 60)
        XCTAssertEqual(production.busyRetry, 15 * 60)
        XCTAssertEqual(AutomaticUpdateTiming.scaled(1_000, fraction: 0.10, unit: 0, minimum: 0), 900, accuracy: 0.001)
        XCTAssertEqual(AutomaticUpdateTiming.scaled(1_000, fraction: 0.10, unit: 1, minimum: 0), 1_100, accuracy: 0.001)
        XCTAssertEqual(AutomaticUpdateTiming.scaled(1_000, fraction: 0.10, unit: 0.5, minimum: 0), 1_000, accuracy: 0.001)
        XCTAssertEqual(AutomaticUpdateTiming.scaled(5, fraction: 1, unit: 0, minimum: 30), 30, accuracy: 0.001)
    }

    func testLaunchCheckRunsWhenEnabledAndStaysSilentWhenUpToDate() async {
        let service = ScriptedUpdateService([.success(nil)])
        let harness = Harness(service: service, timing: timing())
        harness.coordinator.start()
        XCTAssertEqual(harness.scheduler.nextDelay, 0)
        harness.scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(service.checks, 1)
        XCTAssertEqual(service.downloads, 0)
        XCTAssertTrue(harness.routes.isEmpty)
        XCTAssertFalse(harness.router.upToDatePresented)
        XCTAssertFalse(harness.router.couldntCheckPresented)
        XCTAssertEqual(harness.router.updates.state, .idle)
        XCTAssertEqual(harness.scheduler.nextDelay, 100)
    }

    func testTurningAutomaticChecksOffCancelsTheScheduleAndOnChecksAgain() async {
        let service = ScriptedUpdateService([.success(nil), .success(nil)])
        let harness = Harness(service: service, timing: timing(launch: 5, interval: 80), checksEnabled: false)
        harness.coordinator.start()
        XCTAssertNil(harness.scheduler.nextDelay)
        harness.scheduler.advance(by: 1_000)
        await settle()
        XCTAssertEqual(service.checks, 0)

        harness.preferences.checkForUpdatesAutomatically = true
        XCTAssertEqual(harness.scheduler.nextDelay, 5)
        harness.scheduler.advance(by: 4)
        await settle()
        XCTAssertEqual(service.checks, 0)
        harness.scheduler.advance(by: 1)
        await settle()
        XCTAssertEqual(service.checks, 1)
        XCTAssertEqual(harness.scheduler.nextDelay, 80)

        harness.preferences.checkForUpdatesAutomatically = false
        XCTAssertNil(harness.scheduler.nextDelay)
        harness.scheduler.advance(by: 80)
        await settle()
        XCTAssertEqual(service.checks, 1)
        XCTAssertTrue(harness.routes.isEmpty)
    }

    func testPeriodicCheckWaitsForTheScheduledInterval() async {
        let service = ScriptedUpdateService([.success(nil), .success(nil)])
        let harness = Harness(service: service, timing: timing(interval: 50))
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(service.checks, 1)
        harness.scheduler.advance(by: 49)
        await settle()
        XCTAssertEqual(service.checks, 1)
        harness.scheduler.advance(by: 1)
        await settle()
        XCTAssertEqual(service.checks, 2)
        XCTAssertTrue(harness.routes.isEmpty)
    }

    func testJitterScalesTheIntervalInsideTheConfiguredFraction() async {
        let service = ScriptedUpdateService([.success(nil)])
        let jitter = FixedJitter(values: [0])
        let harness = Harness(service: service, timing: timing(interval: 1_000, jitter: 0.10), jitter: jitter)
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(harness.scheduler.nextDelay ?? -1, 900, accuracy: 0.001)
    }

    func testNetworkFailureStaysSilentAndRetriesWithBackoffUntilSuccess() async {
        let service = ScriptedUpdateService([
            .failure(.network), .failure(.network), .failure(.timedOut), .success(nil)
        ])
        let harness = Harness(service: service, timing: timing(interval: 100, backoff: 10, maximum: 40))
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(service.checks, 1)
        XCTAssertEqual(harness.router.updates.state, .failed(.network, nil))
        XCTAssertTrue(harness.routes.isEmpty)
        XCTAssertFalse(harness.router.couldntCheckPresented)
        XCTAssertNil(harness.router.checkFailurePresentation)
        XCTAssertEqual(harness.scheduler.nextDelay, 10)

        harness.scheduler.advance(by: 9)
        await settle()
        XCTAssertEqual(service.checks, 1)
        harness.scheduler.advance(by: 1)
        await settle()
        XCTAssertEqual(service.checks, 2)
        XCTAssertEqual(harness.scheduler.nextDelay, 20)

        harness.scheduler.advance(by: 20)
        await settle()
        XCTAssertEqual(service.checks, 3)
        XCTAssertEqual(harness.scheduler.nextDelay, 40)

        harness.scheduler.advance(by: 40)
        await settle()
        XCTAssertEqual(service.checks, 4)
        XCTAssertEqual(harness.router.updates.state, .idle)
        XCTAssertEqual(harness.scheduler.nextDelay, 100)
        XCTAssertTrue(harness.routes.isEmpty)
    }

    func testDisablingChecksWhileACheckIsInFlightDropsTheResult() async {
        let service = GatedUpdateService()
        let harness = Harness(service: service, timing: timing(), automaticInstall: true)
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await wait { service.checks == 1 }
        harness.preferences.checkForUpdatesAutomatically = false
        service.finish(.success("9"))
        await settle()
        XCTAssertTrue(harness.routes.isEmpty)
        XCTAssertEqual(service.downloads, 0)
        XCTAssertEqual(harness.router.updates.state, .idle)
        XCTAssertNil(harness.scheduler.nextDelay)
        XCTAssertFalse(harness.router.helperUpdate.presented)
    }

    func testFoundUpdateWithoutAutomaticInstallShowsTheExistingOfferAndDoesNotDownload() async {
        let service = ScriptedUpdateService([.success("9"), .success("9")])
        let harness = Harness(service: service, timing: timing(interval: 30, busy: 4))
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(harness.routes, [.softwareUpdate])
        XCTAssertEqual(harness.router.updates.state, .available(version: "9"))
        XCTAssertEqual(service.downloads, 0)
        XCTAssertEqual(service.installs, 0)
        XCTAssertFalse(harness.router.upToDatePresented)
        XCTAssertFalse(harness.router.isUnattendedInstall)

        harness.scheduler.advance(by: 30)
        await settle()
        XCTAssertEqual(service.checks, 1)
        XCTAssertEqual(harness.scheduler.nextDelay, 4)
    }

    func testManualCheckStillConfirmsBeforeInstallUntilThePreferenceIsOn() async throws {
        let optedOut = ScriptedUpdateService([.success("4")])
        let plain = Harness(service: optedOut, timing: timing())
        XCTAssertTrue(plain.router.checkForUpdatesFromMenu(presentationID: plain.router.beginMenuSetupPresentation()))
        await settle()
        XCTAssertEqual(plain.router.updates.state, .available(version: "4"))
        XCTAssertEqual(optedOut.downloads, 0)
        XCTAssertEqual(plain.routes, [.softwareUpdate])

        let optedIn = ScriptedUpdateService([.success("4")])
        let automatic = Harness(service: optedIn, timing: timing(), automaticInstall: true)
        XCTAssertTrue(automatic.router.checkForUpdatesFromMenu(presentationID: automatic.router.beginMenuSetupPresentation()))
        await wait {
            if case .staged = automatic.router.updates.state { return automatic.router.updates.downloadReceipt != nil }
            return false
        }
        let receipt = try XCTUnwrap(automatic.router.updates.downloadReceipt)
        XCTAssertEqual(optedIn.installs, 0)
        XCTAssertEqual(automatic.router.updates.state, .staged(receipt))
        XCTAssertFalse(automatic.router.isUnattendedInstall)
    }

    func testMenuCheckStillPresentsUpToDateAndTransientFailure() async {
        let current = ScriptedUpdateService([.success(nil)])
        let router = AppRouter(updateService: current)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        XCTAssertTrue(router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation()))
        await settle()
        XCTAssertEqual(routes, [.softwareUpdate])
        XCTAssertTrue(router.upToDatePresented)
        XCTAssertFalse(router.couldntCheckPresented)

        let failed = ScriptedUpdateService([.failure(.network)])
        let failing = AppRouter(updateService: failed)
        XCTAssertTrue(failing.checkForUpdatesFromMenu(presentationID: failing.beginMenuSetupPresentation()))
        await settle()
        XCTAssertTrue(failing.couldntCheckPresented)
        XCTAssertEqual(failing.checkFailurePresentation?.reason, .network)
    }

    func testMissingConfigurationDoesNotScheduleOrCheck() async {
        let configuredFailure = ScriptedUpdateService([.success("9")])
        let failedRouter = AppRouter(updateService: configuredFailure, updateConfigurationFailure: .invalidData)
        let failedClock = FakeWattClock()
        let failedScheduler = ManualUpdateScheduler(clock: failedClock)
        let failedPreferences = PreferencesStore(storage: InMemoryStorage())
        let failedCoordinator = AutomaticUpdateCoordinator(router: failedRouter, preferences: failedPreferences,
                                                           scheduler: failedScheduler, timing: timing(), jitter: FixedJitter(values: [0.5]))
        failedCoordinator.start()
        XCTAssertNil(failedScheduler.nextDelay)
        failedScheduler.advance(by: 10_000)
        await settle()
        XCTAssertEqual(configuredFailure.checks, 0)

        let unconfigured = AppRouter()
        let idle = ManualUpdateScheduler(clock: FakeWattClock())
        AutomaticUpdateCoordinator(router: unconfigured, preferences: PreferencesStore(storage: InMemoryStorage()),
                                   scheduler: idle, timing: timing(), jitter: FixedJitter(values: [0.5])).start()
        idle.advance(by: 10_000)
        XCTAssertNil(idle.nextDelay)
        XCTAssertFalse(unconfigured.canScheduleAutomaticChecks)
    }

    func testSavedInstallPreferenceDoesNotInstallAStagedUpdateOnItsOwn() async {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "9"), generation: store.generation))
        let receipt = OperationReceipt(createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(store.beginDownload(version: "9", receipt: receipt, generation: store.generation))
        XCTAssertTrue(store.accept(.staged(receipt), generation: store.generation))
        XCTAssertTrue(store.saveAutomaticInstallChoice(true))
        let service = ScriptedUpdateService([.success("9")])
        let router = AppRouter(updateService: service, updates: store)
        let scheduler = ManualUpdateScheduler(clock: FakeWattClock())
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let coordinator = AutomaticUpdateCoordinator(router: router, preferences: preferences, scheduler: scheduler,
                                                     timing: timing(busy: 12), jitter: FixedJitter(values: [0.5]))
        coordinator.start()
        scheduler.advance(by: 0)
        await settle()
        XCTAssertEqual(service.checks, 0)
        XCTAssertEqual(service.downloads, 0)
        XCTAssertEqual(service.installs, 0)
        XCTAssertEqual(store.state, .staged(receipt))
        XCTAssertEqual(scheduler.nextDelay, 12)
    }

    func testOptedInBackgroundInstallVerifiesThenRelaunchesAndFollowsUpWhenTheHelperChanged() async throws {
        let rig = try UpdateRig()
        let changed = try await installAutomatically(rig: rig, helperChanged: true)
        XCTAssertEqual(rig.driver.launchCount, 1)
        XCTAssertEqual(rig.driver.replacementCount, 1)
        XCTAssertEqual(rig.driver.stageCount, 1)
        XCTAssertEqual(changed.router.updates.state, .completed(try XCTUnwrap(changed.router.updates.downloadReceipt)))
        XCTAssertEqual(changed.routes.filter { $0 == .softwareUpdate }.count, 1)
        XCTAssertTrue(changed.relaunchQuit)
        XCTAssertEqual(changed.routes.filter { $0 == .update }.count, 0)
        changed.router.notePresentationReady()
        XCTAssertEqual(changed.routes.filter { $0 == .update }.count, 0)

        let sameStore = AppRouter(updateService: rig.adapter, updates: UpdateStore(storage: changed.storage))
        var repeated: [AppDestination] = []
        sameStore.present = { repeated.append($0) }
        sameStore.helperChangedAfterUpdate = { true }
        await sameStore.recoverUpdateStartup(adapter: rig.adapter)
        sameStore.notePresentationReady()
        XCTAssertEqual(repeated, [.update])
    }

    func testOptedInInstallStaysQuietWhenTheHelperDidNotChangeAndCanAlertOnALaterLaunch() async throws {
        let rig = try UpdateRig()
        let quiet = try await installAutomatically(rig: rig, helperChanged: false)
        XCTAssertEqual(rig.driver.launchCount, 1)
        XCTAssertFalse(quiet.routes.contains(.update))
        XCTAssertFalse(quiet.router.helperUpdate.presented)

        let later = AppRouter(updateService: rig.adapter)
        var routes: [AppDestination] = []
        later.present = { routes.append($0) }
        later.helperChangedAfterUpdate = { true }
        await later.recoverUpdateStartup(adapter: rig.adapter)
        XCTAssertTrue(routes.isEmpty)
        later.notePresentationReady()
        XCTAssertEqual(routes, [.update])
    }

    func testUntrustedSignatureAndChecksumNeverInstall() async throws {
        let unsigned = try UpdateRig()
        if let release = unsigned.source.release {
            var signature = release.signature
            signature[0] ^= 0xff
            unsigned.source.release = SignedUpdate(payload: release.payload, signature: signature)
        }
        let rejected = try await installAutomatically(rig: unsigned, helperChanged: true)
        await settle()
        XCTAssertEqual(unsigned.driver.launchCount, 0)
        XCTAssertEqual(unsigned.driver.replacementCount, 0)
        XCTAssertEqual(unsigned.driver.stageCount, 0)
        XCTAssertEqual(rejected.router.updates.state, .failed(.untrustedIdentity, nil))
        XCTAssertTrue(rejected.routes.isEmpty)

        let mismatched = try UpdateRig()
        mismatched.source.bytes.append(0)
        let harness = try await installAutomatically(rig: mismatched, helperChanged: true)
        await wait { mismatched.driver.stageCount == 0 && harness.router.updates.downloadReceipt != nil }
        let receipt = try XCTUnwrap(harness.router.updates.downloadReceipt)
        await wait {
            if case .failed(.invalidData, receipt) = harness.router.updates.state { return true }
            return false
        }
        XCTAssertEqual(harness.router.updates.state, .failed(.invalidData, receipt))
        XCTAssertEqual(mismatched.driver.stageCount, 0)
        XCTAssertEqual(mismatched.driver.launchCount, 0)
        XCTAssertEqual(mismatched.driver.replacementCount, 0)
        XCTAssertFalse(harness.routes.contains(.update))
    }

    private func installAutomatically(rig: UpdateRig, helperChanged: Bool) async throws -> Harness {
        let harness = Harness(service: rig.service, timing: timing(), automaticInstall: true)
        harness.router.configureUpdateInstallation(adapter: rig.adapter)
        harness.router.onMaintenanceHandoff = { [weak harness] in harness?.relaunchQuit = true }
        harness.router.helperChangedAfterUpdate = { helperChanged }
        harness.router.notePresentationReady()
        harness.coordinator.start()
        harness.scheduler.advance(by: 0)
        await wait {
            if rig.driver.launchCount >= 1 {
                if case .completed = harness.router.updates.state { return true }
                return false
            }
            if case .failed = harness.router.updates.state { return true }
            return false
        }
        await settle()
        return harness
    }
}

@MainActor
private final class Harness {
    let storage = InMemoryStorage()
    let preferences: PreferencesStore
    let router: AppRouter
    let scheduler: ManualUpdateScheduler
    let coordinator: AutomaticUpdateCoordinator
    var routes: [AppDestination] = []
    var relaunchQuit = false

    init(service: any UpdateService, timing: AutomaticUpdateTiming, checksEnabled: Bool = true,
         automaticInstall: Bool = false, jitter: any UpdateJitter = FixedJitter(values: [0.5])) {
        preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.checkForUpdatesAutomatically = checksEnabled
        let updates = UpdateStore(storage: storage)
        if automaticInstall { XCTAssertTrue(updates.saveAutomaticInstallChoice(true)) }
        router = AppRouter(updateService: service, updates: updates)
        let clock = FakeWattClock()
        scheduler = ManualUpdateScheduler(clock: clock)
        coordinator = AutomaticUpdateCoordinator(router: router, preferences: preferences, scheduler: scheduler,
                                                 timing: timing, jitter: jitter)
        router.present = { [weak self] route in self?.routes.append(route) }
    }
}

@MainActor
private final class ManualUpdateScheduler: UpdateScheduling {
    struct Item {
        let id: UUID
        let due: Date
        let perform: @MainActor () -> Void
    }
    let clock: FakeWattClock
    private(set) var pending: [Item] = []
    init(clock: FakeWattClock) { self.clock = clock }
    var nextDelay: TimeInterval? { pending.map { $0.due.timeIntervalSince(clock.now) }.min() }
    func schedule(after delay: TimeInterval, perform: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID()
        pending.append(Item(id: id, due: clock.now.addingTimeInterval(delay), perform: perform))
        return id
    }
    func cancel(_ id: UUID) { pending.removeAll { $0.id == id } }
    func advance(by interval: TimeInterval) {
        clock.advance(by: interval)
        let due = pending.filter { $0.due <= clock.now }.sorted { $0.due < $1.due }
        let ids = Set(due.map(\.id))
        pending.removeAll { ids.contains($0.id) }
        due.forEach { $0.perform() }
    }
}

@MainActor
private final class FixedJitter: UpdateJitter {
    var values: [Double]
    private var index = 0
    init(values: [Double]) { self.values = values }
    func unit() -> Double {
        let value = values[min(index, values.count - 1)]
        index += 1
        return value
    }
}

@MainActor
private final class ScriptedUpdateService: UpdateService {
    var results: [ServiceOutcome<String?>]
    private(set) var checks = 0
    private(set) var downloads = 0
    private(set) var installs = 0
    init(_ results: [ServiceOutcome<String?>]) { self.results = results }
    func check() async -> ServiceOutcome<String?> {
        checks += 1
        guard !results.isEmpty else { return .success(nil) }
        return results.removeFirst()
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        downloads += 1
        return .success(.staged(receipt))
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        installs += 1
        return .success(.awaitingRelaunch(receipt))
    }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .success(.failed(.cancelled, receipt)) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .success(receipt) }
}

@MainActor
private final class GatedUpdateService: UpdateService {
    private var continuation: CheckedContinuation<ServiceOutcome<String?>, Never>?
    private(set) var checks = 0
    private(set) var downloads = 0
    func check() async -> ServiceOutcome<String?> {
        checks += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ outcome: ServiceOutcome<String?>) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        downloads += 1
        return .success(.staged(receipt))
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.denied) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}

@MainActor
private final class UpdateRig {
    let key = Curve25519.Signing.PrivateKey()
    let source = RigSource()
    let driver = RigDriver()
    let adapter: UpdateAdapter
    var service: any UpdateService { adapter }

    init() throws {
        let trust = UpdateTrust(identity: "test.watt", currentBuild: 1,
                                hostSystemVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 1),
                                publicKey: key.publicKey)
        adapter = UpdateAdapter(source: source, driver: driver, storage: InMemoryStorage(), trust: trust)
        try publish(build: 2)
    }

    func publish(build: UInt64) throws {
        source.bytes = Data("watt-update-\(build)".utf8)
        let payload = try JSONEncoder().encode(UpdateManifest(identity: "test.watt", build: build,
                                                              sha256: Data(SHA256.hash(data: source.bytes)),
                                                              minimumSystemVersion: "13.0"))
        source.release = SignedUpdate(payload: payload, signature: try key.signature(for: payload))
    }
}

@MainActor
private final class RigSource: UpdateSource {
    var release: SignedUpdate?
    var bytes = Data()
    func check() async throws -> SignedUpdate? { release }
    func download(_ release: SignedUpdate) async throws -> Data { bytes }
}

@MainActor
private final class RigDriver: UpdateInstallationDriver {
    var staged: [UUID: Data] = [:]
    var receipts: [UUID: OperationReceipt] = [:]
    var installed: Data?
    var running: OperationReceipt?
    private(set) var stageCount = 0
    private(set) var replacementCount = 0
    private(set) var launchCount = 0

    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws {
        guard Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw ServiceFailure.invalidData }
        stageCount += 1
        receipts[receipt.id] = receipt
        staged[receipt.id] = bytes
    }
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        guard receipts[receipt.id] == receipt, let bytes = staged[receipt.id],
              Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw ServiceFailure.untrustedIdentity }
    }
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try verifyStaged(manifest: manifest, receipt: receipt)
        replacementCount += 1
        installed = staged[receipt.id]
    }
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement {
        guard receipts[receipt.id] == receipt else { throw ServiceFailure.invalidData }
        guard let installed, Data(SHA256.hash(data: installed)) == manifest.sha256 else { return .original }
        return .replacement
    }
    func rollback(receipt: OperationReceipt) throws { installed = nil }
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        guard try placement(manifest: manifest, receipt: receipt) == .replacement else { throw ServiceFailure.untrustedIdentity }
        launchCount += 1
        running = receipt
    }
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool {
        running == receipt && installed != nil
    }
    func discard(receipt: OperationReceipt) throws { staged[receipt.id] = nil }
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool { staged[receipt.id] == nil }
}
