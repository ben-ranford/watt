import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J104DownloadingTests: XCTestCase {
    private func setup(_ storage: InMemoryStorage = InMemoryStorage()) -> (AppRouter, DownloadService) {
        let store = UpdateStore(storage: storage)
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let service = DownloadService()
        return (AppRouter(updateService: service, updates: store), service)
    }
    private func drain() async { for _ in 0..<30 { await Task.yield() } }
    func testAdmissionRenderingAndDurableReceipt() async {
        _ = NSApplication.shared
        let storage = InMemoryStorage()
        let (router, service) = setup(storage)
        XCTAssertFalse(router.startUpdateDownload(version: "wrong", generation: router.updates.generation))
        XCTAssertFalse(router.startUpdateDownload(version: "1.1", generation: UUID()))
        XCTAssertTrue(router.startUpdateDownload(version: "1.1", generation: router.updates.generation))
        XCTAssertEqual(router.updates.state, .downloading(progress: 0))
        XCTAssertFalse(router.startUpdateDownload(version: "1.1", generation: router.updates.generation))
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, router.updates.downloadReceipt))
        let host = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        XCTAssertEqual(host.fittingSize.width, 420, accuracy: 1)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, 146)
        await drain()
        service.finish()
        await drain()
        XCTAssertEqual(router.updates.state, .staged(service.receipt!))
        XCTAssertEqual(service.installs, 0)
    }
    func testProgressFormattingAndMonotonicAdmission() async {
        let (router, service) = setup()
        router.startUpdateDownload(version: "1.1", generation: router.updates.generation)
        await drain()
        service.progress?(.init(received: 2_100_000, total: 4_200_000))
        XCTAssertEqual(router.downloadProgress?.label, "2.1 MB of 4.2 MB")
        XCTAssertEqual(router.updates.state, .downloading(progress: 0.5))
        for value in [UpdateDownloadProgress(received: -1, total: 1), .init(received: 2, total: 1), .init(received: 0, total: 0), .init(received: 1, total: 4_200_000), .init(received: 3_000_000, total: 5_000_000)] {
            service.progress?(value)
        }
        XCTAssertEqual(router.updates.state, .downloading(progress: 0.5))
        service.finish(wrongReceipt: true)
        await drain()
        XCTAssertEqual(router.updates.state, .failed(.invalidData, service.receipt))
    }
    func testCancelInvalidatesBeforeServiceAndIgnoresLateRepliesThenRetry() async {
        let (router, service) = setup()
        router.startUpdateDownload(version: "1.1", generation: router.updates.generation)
        await drain()
        let old = router.updates.generation
        let oldReceipt = service.receipt
        service.onCancel = {
            XCTAssertNotEqual(router.updates.generation, old)
            service.progress?(.init(received: 4_200_000, total: 4_200_000))
            service.finish()
        }
        let cancelled = await router.cancelUpdateDownload()
        XCTAssertTrue(cancelled)
        XCTAssertEqual(router.updates.state, .idle)
        service.progress?(.init(received: 1, total: 1))
        XCTAssertEqual(router.updates.state, .idle)
        router.updates.accept(.checking, generation: router.updates.generation)
        router.updates.accept(.available(version: "1.1"), generation: router.updates.generation)
        XCTAssertTrue(router.startUpdateDownload(version: "1.1", generation: router.updates.generation))
        await drain()
        XCTAssertNotEqual(service.receipt, oldReceipt)
        service.finish()
        await drain()
    }
    func testPersistenceFailureBeforeAdmissionAndDuringCancel() async {
        let storage = InMemoryStorage()
        let (router, service) = setup(storage)
        storage.failWrites = true
        XCTAssertFalse(router.startUpdateDownload(version: "1.1", generation: router.updates.generation))
        XCTAssertNil(service.receipt)
        storage.failWrites = false
        XCTAssertTrue(router.startUpdateDownload(version: "1.1", generation: router.updates.generation))
        await drain()
        let old = router.updates.generation
        storage.failWrites = true
        let cancelled = await router.cancelUpdateDownload()
        XCTAssertFalse(cancelled)
        XCTAssertNotEqual(router.updates.generation, old)
        XCTAssertEqual(service.cancels, 0)
        service.finish()
        await drain()
        XCTAssertEqual(router.updates.state, .downloading(progress: 0))
        storage.failWrites = false
        let retried = await router.cancelUpdateDownload()
        XCTAssertTrue(retried)
        XCTAssertEqual(router.updates.state, .idle)
    }
    func testFailedDiscardRetainsReceiptAndBlocksFreshCheck() async {
        let (router, service) = setup()
        router.startUpdateDownload(version: "1.1", generation: router.updates.generation)
        await drain()
        service.finish()
        await drain()
        service.discardFailure = true
        let cancelled = await router.cancelUpdateDownload()
        XCTAssertFalse(cancelled)
        XCTAssertEqual(router.updates.state, .failed(.cancelled, service.receipt))
        XCTAssertFalse(router.canCheckForUpdates)
        service.discardFailure = false
        let retried = await router.cancelUpdateDownload()
        XCTAssertTrue(retried)
    }
    func testDiscardAcknowledgementPersistenceRetryDoesNotCancelDiscardedReceipt() async {
        let storage = InMemoryStorage()
        let (router, service) = setup(storage)
        router.startUpdateDownload(version: "1.1", generation: router.updates.generation)
        await drain()
        service.finish()
        await drain()
        service.onDiscard = { storage.failWrites = true }
        let first = await router.cancelUpdateDownload()
        XCTAssertFalse(first)
        XCTAssertFalse(router.canCheckForUpdates)
        let cancels = service.cancels
        storage.failWrites = false
        let second = await router.cancelUpdateDownload()
        XCTAssertTrue(second)
        XCTAssertEqual(service.cancels, cancels)
        XCTAssertEqual(router.updates.state, .idle)
    }

    func testFixtureSelection() throws {
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.4/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.4/base"])
        XCTAssertEqual(try ScenarioRegistry.resolve("J10.4").story.node, "34:5339")
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.4"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.4/other"]))
    }
}

@MainActor
private final class DownloadService: UpdateService {
    var progress: (@MainActor (UpdateDownloadProgress) -> Void)?
    var reply: CheckedContinuation<ServiceOutcome<UpdateState>, Never>?
    var receipt: OperationReceipt?
    var onCancel: (() -> Void)?
    var onDiscard: (() -> Void)?
    var cancels = 0
    var installs = 0
    var discardFailure = false
    func check() async -> ServiceOutcome<String?> { .success("1.1") }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func download(version: String, receipt: OperationReceipt, progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        self.receipt = receipt; self.progress = progress
        return await withCheckedContinuation { reply = $0 }
    }
    func finish(wrongReceipt: Bool = false) {
        reply?.resume(returning: .success(.staged(wrongReceipt ? OperationReceipt(createdAt: Date()) : receipt!)))
        reply = nil
    }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        cancels += 1; onCancel?()
        return .success(.failed(.cancelled, receipt))
    }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> {
        onDiscard?()
        return discardFailure ? .failure(.persistence) : .success(receipt)
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { installs += 1; return .failure(.denied) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
}
