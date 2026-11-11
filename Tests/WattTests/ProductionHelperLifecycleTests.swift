import XCTest
import ServiceManagement
import Darwin
@testable import Watt

@MainActor
final class ProductionHelperLifecycleTests: XCTestCase {
    final class System: HelperRegistrationSystem {
        var registrationStatus: SMAppService.Status = .notRegistered
        var registrations = 0
        var removals = 0
        var failRemoval = false
        var failRegistration = false
        var unregisterInFlight = false
        var timeoutWithPendingCallback = false
        func register() throws {
            registrations += 1
            if failRegistration { throw ServiceFailure.denied }
            registrationStatus = .requiresApproval
        }
        func unregister() async throws {
            removals += 1
            if timeoutWithPendingCallback {
                unregisterInFlight = true
                registrationStatus = .notRegistered
                throw ServiceFailure.timedOut
            }
            if failRemoval { throw ServiceFailure.denied }
            registrationStatus = .notRegistered
        }
    }
    func make(_ system: System, url: URL, absent: @escaping () -> Bool = { true },
              build: @escaping () -> String? = { "2" }) throws -> ProductionHelperLifecycle {
        try ProductionHelperLifecycle(system: system, journalURL: url, targetBuild: "2",
            candidate: { HelperPeer(identifier: "helper", team: "TEAM", protocolVersion: 1) },
            installedBuild: { build() }, processesAbsent: { absent() })
    }
    func testNativeStatusMappingDoesNotTreatLookupFailureAsAbsence() throws {
        XCTAssertThrowsError(try ProductionHelperLifecycle.map(.notFound))
        guard case .requiresApproval = try ProductionHelperLifecycle.map(.requiresApproval) else { return XCTFail() }
        guard case .absent = try ProductionHelperLifecycle.map(.notRegistered) else { return XCTFail() }
    }
    func testRegistrationReceiptSurvivesRestartWithoutRepeatingEffect() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(), receipt = OperationReceipt(createdAt: Date())
        let first = try make(system, url: url)
        try await first.register(receipt: receipt)
        let restarted = try make(system, url: url)
        try await restarted.register(receipt: receipt)
        XCTAssertEqual(system.registrations, 1)
        XCTAssertEqual(restarted.journal?.phase, .complete)
    }
    func testRemovalWaitsForIndependentCessationAndCanResume() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled
        let receipt = OperationReceipt(createdAt: Date())
        var absent = false
        let first = try make(system, url: url, absent: { absent })
        do { try await first.unregister(receipt: receipt); XCTFail("child still active") } catch { }
        XCTAssertEqual(first.journal?.phase, .unregistered)
        absent = true
        let restarted = try make(system, url: url)
        try await restarted.unregister(receipt: receipt)
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(restarted.journal?.phase, .complete)
    }
    func testPendingUnregisterNeverBlindlyRepeatsAndBlocksReplacement() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled; system.timeoutWithPendingCallback = true
        let receipt = OperationReceipt(createdAt: Date())
        let first = try make(system, url: url)
        do { try await first.update(receipt: receipt); XCTFail() } catch { }
        system.unregisterInFlight = true
        let restarted = try make(system, url: url)
        do { try await restarted.update(receipt: receipt); XCTFail() } catch { }
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(system.registrations, 0)
        XCTAssertEqual(restarted.journal?.phase, .unregistering)
    }
    func testUpdateRequiresMatchingBuildAfterUnregisterCompletes() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled
        let receipt = OperationReceipt(createdAt: Date())
        var build = "1"
        let driver = try make(system, url: url, build: { build })
        do { try await driver.update(receipt: receipt); XCTFail() } catch { }
        XCTAssertEqual(driver.journal?.phase, .registering)
        build = "2"
        try await driver.update(receipt: receipt)
        let applied = try await driver.updateApplied(receipt: receipt)
        XCTAssertTrue(applied)
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(system.registrations, 1)
    }
    func testFailedRegisterCanRetryAfterRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.failRegistration = true
        let receipt = OperationReceipt(createdAt: Date())
        let first = try make(system, url: url)
        do { try await first.register(receipt: receipt); XCTFail() } catch { }
        XCTAssertEqual(first.journal?.phase, .registerFailed)
        system.failRegistration = false
        let restarted = try make(system, url: url)
        guard case .absent = try await restarted.status() else { return XCTFail() }
        try await restarted.register(receipt: receipt)
        XCTAssertEqual(system.registrations, 2)
    }

    func testFailedUnregisterCanRetryAfterRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled; system.failRemoval = true
        let receipt = OperationReceipt(createdAt: Date())
        let first = try make(system, url: url)
        do { try await first.unregister(receipt: receipt); XCTFail() } catch { }
        system.failRemoval = false
        let restarted = try make(system, url: url)
        try await restarted.unregister(receipt: receipt)
        XCTAssertEqual(system.removals, 2)
        XCTAssertEqual(restarted.journal?.phase, .complete)
    }

    func testFailedUpdateRegistrationRetriesWithoutRepeatingUnregister() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled; system.failRegistration = true
        let receipt = OperationReceipt(createdAt: Date())
        let first = try make(system, url: url)
        do { try await first.update(receipt: receipt); XCTFail() } catch { }
        system.failRegistration = false
        let restarted = try make(system, url: url)
        XCTAssertEqual(restarted.updateReceipt(), receipt)
        try await restarted.update(receipt: receipt)
        XCTAssertEqual(system.removals, 1)
        XCTAssertEqual(system.registrations, 2)
    }

    func testDelayedNativeCallbackBlocksReplacementEvenAfterOSAbsence() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled; system.timeoutWithPendingCallback = true
        let receipt = OperationReceipt(createdAt: Date())
        let driver = try make(system, url: url)
        do { try await driver.update(receipt: receipt); XCTFail() } catch { }
        guard case .unknown = try await driver.status() else { return XCTFail() }
        do { try await driver.update(receipt: receipt); XCTFail() } catch { }
        XCTAssertEqual(system.registrations, 0)
        system.unregisterInFlight = false; system.timeoutWithPendingCallback = false
        try await driver.update(receipt: receipt)
        XCTAssertEqual(system.registrations, 1)
    }

    func testAbsenceAlwaysRequiresProcessCessationWithoutJournal() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let system = System()
        let driver = try make(system, url: url, absent: { false })
        guard case .unknown = try await driver.status() else { return XCTFail() }
        let adapter = HelperLifecycleAdapter(driver: driver, transport: DisconnectedTransport(),
            expectedPeer: HelperPeer(identifier: "helper", team: "TEAM", protocolVersion: 1))
        let result = await adapter.remove(receipt: OperationReceipt(createdAt: Date()))
        XCTAssertNotEqual(result, .verifiedAbsent)
    }

    func testCompletedRemovalReceiptCannotHideRemainingProcess() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled
        var absent = true
        let driver = try make(system, url: url, absent: { absent })
        let receipt = OperationReceipt(createdAt: Date())
        try await driver.unregister(receipt: receipt)
        absent = false
        guard case .unknown = try await driver.status() else { return XCTFail() }
        do { try await driver.unregister(receipt: receipt); XCTFail() } catch { }
    }

    final class DisconnectedTransport: HelperIPCTransport {
        func connect() async throws -> HelperPeer { throw ServiceFailure.disconnected }
        func send(_ request: HelperMessage) async throws -> HelperMessage { throw ServiceFailure.disconnected }
        func invalidate() { }
    }
    func testDisconnectedOwnedRegistrationRemainsRemovableWithoutIPC() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let system = System(); system.registrationStatus = .enabled
        let driver = try make(system, url: url)
        let adapter = HelperLifecycleAdapter(driver: driver, transport: DisconnectedTransport(),
            expectedPeer: HelperPeer(identifier: "helper", team: "TEAM", protocolVersion: 1))
        let setup = SettingsHelperSetup(service: adapter)
        await setup.refreshStatus()
        XCTAssertFalse(setup.helperOn)
        XCTAssertTrue(setup.canRemoveHelper)
        let result = await adapter.remove(receipt: OperationReceipt(createdAt: Date()))
        XCTAssertEqual(result, .verifiedAbsent)
        XCTAssertEqual(system.removals, 1)
        XCTAssertFalse(adapter.registrationPresent)
    }

    func testProductionCompositionIsAfterFixtureReturnAndBeforeNormalStores() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        let fixture = try XCTUnwrap(source.range(of: "if J125FixtureLaunch.requested ||"))
        let stores = try XCTUnwrap(source.range(of: "let appPowerStore = PowerReadingStore"))
        XCTAssertLessThan(fixture.lowerBound, stores.lowerBound)
        let wiring = try XCTUnwrap(source.range(of: "private enum LaunchWiring"))
        XCTAssertGreaterThan(wiring.lowerBound, stores.lowerBound, "File composition stays out of the synchronous init")
        XCTAssertTrue(source.contains("if Self.isHarnessLaunch {"))
        XCTAssertTrue(source.contains("scheduleFallbackStatusItem"))
        XCTAssertTrue(source.contains("ProductionHelperComposition.configuredOffMain"))
        XCTAssertTrue(source.contains("settingsHelperSetup.service = helper.service"))
        XCTAssertTrue(source.contains("await helper.service.remove(receipt: receipt)"))
        XCTAssertTrue(source.contains("ProductionUpdateComposition.configured(bundle:"))
        XCTAssertFalse(source.contains("ProductionUpdateComposition.configured()"),
                       "The synchronous updater factory must not run on the main thread during init")
        let synchronousInit = String(source[fixture.upperBound..<stores.upperBound])
        XCTAssertFalse(synchronousInit.contains("HeldLock.acquire"))
        XCTAssertFalse(synchronousInit.contains("FileManager.default.fileExists"))
        XCTAssertFalse(synchronousInit.contains("Data(contentsOf:"))
    }

    func testReadOnlyProcessInventoryCannotClaimCurrentExecutableAbsent() throws {
        var bytes = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        let length = bytes.withUnsafeMutableBytes { proc_pidpath(getpid(), $0.baseAddress, UInt32($0.count)) }
        XCTAssertGreaterThan(length, 0)
        XCTAssertFalse(HelperProcessInventory.absent(helperPath: try XCTUnwrap(HelperProcessInventory.terminatedUTF8(bytes))))
    }

    func testUnreadableUnrelatedExecutableNameDoesNotBlockInventory() {
        let helperPath = "/Applications/Watt.app/Contents/MacOS/WattHelper"
        XCTAssertTrue(HelperProcessInventory.unrelatedName("node", helperPath: helperPath))
        XCTAssertTrue(HelperProcessInventory.unrelatedName("codex", helperPath: helperPath))
        for name in [nil, "", "WattHelper", "powermetrics", "unknown/path"] as [String?] {
            XCTAssertFalse(HelperProcessInventory.unrelatedName(name, helperPath: helperPath))
        }
    }

    func testProcessStringsRejectMalformedOrUnterminatedUTF8() {
        XCTAssertEqual(HelperProcessInventory.terminatedUTF8([110, 111, 100, 101, 0]), "node")
        XCTAssertNil(HelperProcessInventory.terminatedUTF8([110, 111]))
        XCTAssertNil(HelperProcessInventory.terminatedUTF8([-1, 0]))
        XCTAssertNil(HelperProcessInventory.terminatedUTF8([0]))
    }

}
