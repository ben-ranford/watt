import XCTest
import AppKit
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J124LeftoverHelperTests: XCTestCase {
    func testNativeAlertAndExactRegistry() throws {
        let alert = LeftoverHelperAlert.make()
        XCTAssertEqual(alert.alertStyle, .informational)
        XCTAssertEqual(alert.messageText, "A helper from your last install")
        XCTAssertEqual(alert.informativeText, "Reconnect it and Components pick up where they left off. Or remove it.")
        XCTAssertEqual(alert.buttons.map(\.title), ["Reconnect", "Remove Helper"])
        XCTAssertEqual(alert.buttons[0].keyEquivalent, "\r")
        XCTAssertNotEqual(alert.buttons[1].keyEquivalent, "\u{1b}")
        XCTAssertNil(alert.accessoryView)
        let fixture = try ScenarioRegistry.resolve("J12.4")
        XCTAssertEqual(fixture.story.node, "35:5746")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J12.4/base"])
        for value in ["J12.4", "J12.4/dark", "J12.4/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
    }
    func testReconnectConsumesConsentAndPersistsCompletion() async throws {
        let storage = InMemoryStorage(), id = UUID()
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: id)
        prompt.detect = { true }
        var calls = 0
        prompt.reconnect = { calls += 1; return .connected }
        await prompt.discover()
        let intent = try XCTUnwrap(prompt.intent)
        await prompt.perform(.reconnect, intent: intent)
        await prompt.perform(.reconnect, intent: intent)
        XCTAssertEqual(calls, 1)
        XCTAssertNil(prompt.intent)
        let relaunched = LeftoverHelperPrompt(storage: storage, installationID: id)
        relaunched.detect = { true }
        await relaunched.discover()
        XCTAssertNil(relaunched.intent)
    }
    func testClosedAndStaleIntentsCannotMutate() async throws {
        let prompt = J124FixtureLaunch.makePrompt()
        var calls = 0
        prompt.remove = { _ in calls += 1; return .verifiedAbsent }
        await prompt.discover()
        let old = try XCTUnwrap(prompt.intent)
        prompt.close(old)
        await prompt.discover()
        await prompt.perform(.remove, intent: old)
        XCTAssertEqual(calls, 0)
        XCTAssertNotNil(prompt.intent)
    }
    func testRetryKeepsReceiptAndFailedPersistencePreventsRemoval() async throws {
        let storage = InMemoryStorage()
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: UUID())
        prompt.detect = { true }
        var receipts: [OperationReceipt] = []
        prompt.remove = { receipts.append($0); return .failed(.timedOut) }
        await prompt.discover()
        storage.failWrites = true
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        XCTAssertTrue(receipts.isEmpty)
        XCTAssertEqual(prompt.failure, .persistence)
        storage.failWrites = false
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts.first, receipts.last)
    }
    func testAcknowledgementRetryDoesNotRepeatEffect() async throws {
        let storage = InMemoryStorage()
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: UUID())
        prompt.detect = { true }
        var calls = 0
        prompt.remove = { _ in calls += 1; storage.failWrites = true; return .verifiedAbsent }
        await prompt.discover()
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(prompt.failure, .persistence)
        storage.failWrites = false
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(calls, 1)
        XCTAssertNil(prompt.failure)
    }
    func testCloseDuringReconnectIgnoresLateSuccessAndBlocksNewWork() async throws {
        let prompt = J124FixtureLaunch.makePrompt()
        var continuation: CheckedContinuation<HelperReconciliation, Never>?
        prompt.reconnect = { await withCheckedContinuation { continuation = $0 } }
        var completions = 0
        prompt.onCompleted = { _ in completions += 1 }
        await prompt.discover()
        let intent = try XCTUnwrap(prompt.intent)
        let task = Task { await prompt.perform(.reconnect, intent: intent) }
        while continuation == nil { await Task.yield() }
        prompt.close()
        await prompt.discover()
        XCTAssertNil(prompt.intent)
        continuation?.resume(returning: .connected)
        await task.value
        XCTAssertEqual(completions, 0)
        XCTAssertFalse(prompt.busy)
    }
    func testUnknownPendingAbsentAreNotReconnectSuccess() async throws {
        for status: HelperReconciliation in [.unknown, .pending, .absent, .failed(.untrustedIdentity)] {
            let prompt = J124FixtureLaunch.makePrompt()
            prompt.reconnect = { status }
            var completed = false
            prompt.onCompleted = { _ in completed = true }
            await prompt.discover()
            await prompt.perform(.reconnect, intent: try XCTUnwrap(prompt.intent))
            XCTAssertFalse(completed)
            XCTAssertNotNil(prompt.failure)
        }
    }
    func testInventoryDetectionAndHelperOnlyRemoval() async throws {
        let driver = J124Driver()
        let helper = FakeHelperService()
        helper.status = .connected
        let adapter = try ScopedRemovalAdapter(manifest: driver.manifest, driver: driver, helper: helper)
        let same = try await adapter.hasLeftoverHelper(currentInstallationID: driver.manifest.installationID)
        XCTAssertFalse(same)
        let reinstallID = UUID() // Distinct from the trusted previous-install manifest.
        let found = try await adapter.hasLeftoverHelper(currentInstallationID: reinstallID)
        XCTAssertTrue(found)
        let prompt = LeftoverHelperPrompt(storage: InMemoryStorage(), installationID: reinstallID)
        prompt.configure(adapter: adapter, installationID: reinstallID)
        await prompt.discover()
        await prompt.perform(.remove, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(driver.removed, [.helper])
        XCTAssertTrue(driver.paths.contains("/owned/config"))
        XCTAssertNil(prompt.failure)
    }
    func testReadFailureAndMissingHelperFailClosed() async {
        let storage = InMemoryStorage()
        storage.failReads = true
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: UUID())
        prompt.detect = { XCTFail("Must not detect after failed durable read"); return true }
        await prompt.discover()
        XCTAssertNil(prompt.intent)
        XCTAssertEqual(prompt.failure, .persistence)
    }
}

@MainActor
private final class J124Driver: OwnedRemovalDriver {
    let manifest = RemovalManifest(installationID: UUID(), resources: [
        .init(path: "/owned/helper", kind: .helper), .init(path: "/owned/config", kind: .configuration)])
    var paths: Set<String> = ["/owned/helper", "/owned/config"]
    var journal: RemovalTransaction?
    var removed: [RemovalManifest.Kind] = []
    func inventory(manifest: RemovalManifest) async throws -> RemovalInventory {
        .init(presentPaths: paths, helperRunning: paths.contains("/owned/helper"), appRunning: true)
    }
    func transaction() throws -> RemovalTransaction? { journal }
    func save(_ transaction: RemovalTransaction) throws { journal = transaction }
    func remove(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        removed.append(resource.kind); paths.remove(resource.path)
    }
    func restore(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws { paths.insert(resource.path) }
}
