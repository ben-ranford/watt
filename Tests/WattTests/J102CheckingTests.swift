import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J102CheckingTests: XCTestCase {
    private func settle() async { for _ in 0..<30 { await Task.yield() } }
    private func start(_ router: AppRouter) -> Bool {
        router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
    }

    func testUnconfiguredProductionRemainsIdle() {
        let router = AppRouter()
        XCTAssertFalse(start(router))
        XCTAssertEqual(router.updates.state, .idle)
        XCTAssertFalse(router.cancelUpdateCheck())
    }

    func testCancelInvalidatesGenerationAndRejectsNoncooperativeLateResult() async {
        let service = J102Service()
        let router = AppRouter(updateService: service)
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        XCTAssertTrue(start(router))
        await settle()
        let generation = router.updates.generation
        XCTAssertEqual(router.updates.state, .checking)
        XCTAssertEqual(destinations, [.softwareUpdate])
        XCTAssertFalse(router.helperUpdate.presented)
        XCTAssertTrue(router.cancelUpdateCheck())
        XCTAssertNotEqual(router.updates.generation, generation)
        XCTAssertFalse(router.cancelUpdateCheck())
        XCTAssertFalse(router.canCheckForUpdates)
        service.finish(.success("stale"))
        await settle()
        XCTAssertTrue(service.sawCancellation)
        XCTAssertEqual(router.updates.state, .failed(.cancelled, nil))
        XCTAssertTrue(router.canCheckForUpdates)
    }

    func testPersistenceFailureStillCancelsTaskAndAllowsCancellationRetry() async {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        let service = J102Service()
        let router = AppRouter(updateService: service, updates: store)
        XCTAssertTrue(start(router))
        await settle()
        let generation = store.generation
        storage.failWrites = true
        XCTAssertFalse(router.cancelUpdateCheck())
        XCTAssertNotEqual(store.generation, generation)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        service.finish(.success("stale"))
        await settle()
        XCTAssertTrue(service.sawCancellation)
        XCTAssertEqual(store.state, .checking)
        storage.failWrites = false
        XCTAssertTrue(router.cancelUpdateCheck())
        XCTAssertEqual(store.state, .failed(.cancelled, nil))
        XCTAssertNil(store.persistenceFailure)
    }

    func testServiceOutcomesAreNotFabricated() async {
        for outcome: ServiceOutcome<String?> in [.success(nil), .success("42"), .failure(.network)] {
            let service = J102Service()
            let router = AppRouter(updateService: service)
            XCTAssertTrue(start(router))
            await settle()
            XCTAssertEqual(router.updates.state, .checking)
            service.finish(outcome)
            await settle()
            switch outcome {
            case .success(.none): XCTAssertEqual(router.updates.state, .idle)
            case .success(.some(let version)): XCTAssertEqual(router.updates.state, .available(version: version))
            case .failure(let failure): XCTAssertEqual(router.updates.state, .failed(failure, nil))
            }
            XCTAssertFalse(router.cancelUpdateCheck())
        }
    }

    func testExactFixtureSelectionAndPackageIsolation() throws {
        let fixture = try ScenarioRegistry.resolve("J10.2")
        XCTAssertEqual(fixture.story.node, "34:4482")
        XCTAssertEqual(fixture.story.status, "implemented")
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.2/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.2/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.2"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.2/other"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J102FixtureLaunch.requested)
        #endif
    }

    func testNativeContentHasFiniteIntrinsicLayout() {
        _ = NSApplication.shared
        let router = AppRouter()
        let host = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        XCTAssertEqual(host.fittingSize.width, 420, accuracy: 1)
        XCTAssertGreaterThan(host.fittingSize.height, 100)
        XCTAssertLessThan(host.fittingSize.height, 200)
    }
}

@MainActor
private final class J102Service: UpdateService {
    var sawCancellation = false
    private var continuation: CheckedContinuation<ServiceOutcome<String?>, Never>?
    func check() async -> ServiceOutcome<String?> {
        let result = await withCheckedContinuation { continuation = $0 }
        sawCancellation = Task.isCancelled
        return result
    }
    func finish(_ result: ServiceOutcome<String?>) {
        continuation?.resume(returning: result)
        continuation = nil
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
