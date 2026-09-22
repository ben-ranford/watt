import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J105ReadyTests: XCTestCase {
    private func setup(_ storage: InMemoryStorage = InMemoryStorage()) async -> AppRouter {
        let store = UpdateStore(storage: storage)
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        XCTAssertTrue(router.startUpdateDownload(version: "1.1", generation: store.generation))
        for _ in 0..<30 { await Task.yield() }
        return router
    }
    func testExactStagedReadinessAndNativeContent() async throws {
        _ = NSApplication.shared
        let router = await setup()
        let receipt = try XCTUnwrap(router.readyReceipt)
        XCTAssertEqual(router.updates.state, .staged(receipt))
        XCTAssertEqual(UpdateReadyContent.progress, 1)
        XCTAssertEqual(UpdateReadyContent.title, "Ready to install")
        XCTAssertEqual(UpdateReadyContent.footnote, "Watt? quits, updates and comes back to the menu bar. About 5 seconds.")
        let host = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        XCTAssertEqual(host.fittingSize.width, 420, accuracy: 1)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, 146)
        router.updates.accept(.failed(.invalidData, receipt), generation: router.updates.generation)
        XCTAssertNil(router.readyReceipt)
        XCTAssertNil(router.beginReadyPresentation())
    }
    func testPercentageAloneIsNotReadyAndWrongReceiptRejected() {
        let store = UpdateStore()
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let receipt = OperationReceipt(createdAt: Date())
        XCTAssertTrue(store.beginDownload(version: "1.1", receipt: receipt, generation: store.generation))
        XCTAssertTrue(store.accept(.downloading(progress: 1), generation: store.generation))
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        XCTAssertNil(router.readyReceipt)
        XCTAssertFalse(store.accept(.staged(OperationReceipt(createdAt: Date())), generation: store.generation))
    }
    func testBothActionsAreScopedIntentsNotInstallation() async throws {
        for action in [AppRouter.ReadyIntent.Action.later, .installAndRelaunch] {
            let router = await setup()
            let receipt = try XCTUnwrap(router.readyReceipt)
            let generation = router.updates.generation
            let presentation = try XCTUnwrap(router.beginReadyPresentation())
            XCTAssertTrue(router.chooseReadyUpdate(action, version: "1.1", generation: generation, receipt: receipt, presentation: presentation))
            XCTAssertEqual(router.readyIntent, .init(action: action, version: "1.1", generation: generation, receipt: receipt))
            XCTAssertEqual(router.updates.state, .staged(receipt))
            XCTAssertEqual(router.updates.downloadReceipt, receipt)
            XCTAssertNotEqual(router.updates.generation, generation)
            XCTAssertFalse(router.chooseReadyUpdate(action, version: "1.1", generation: generation, receipt: receipt, presentation: presentation))
            XCTAssertFalse(router.canCheckForUpdates)
        }
    }
    func testStaleVersionGenerationReceiptAndClosedPresentation() async throws {
        let router = await setup()
        let receipt = try XCTUnwrap(router.readyReceipt)
        let generation = router.updates.generation
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertFalse(router.chooseReadyUpdate(.later, version: "other", generation: generation, receipt: receipt, presentation: presentation))
        XCTAssertFalse(router.chooseReadyUpdate(.later, version: "1.1", generation: UUID(), receipt: receipt, presentation: presentation))
        XCTAssertFalse(router.chooseReadyUpdate(.later, version: "1.1", generation: generation, receipt: OperationReceipt(createdAt: Date()), presentation: presentation))
        XCTAssertFalse(router.chooseReadyUpdate(.later, version: "1.1", generation: generation, receipt: OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1)), presentation: presentation))
        router.closeReadyPresentation(presentation)
        XCTAssertFalse(router.chooseReadyUpdate(.later, version: "1.1", generation: generation, receipt: receipt, presentation: presentation))
        let replacement = try XCTUnwrap(router.beginReadyPresentation())
        router.closeReadyPresentation(presentation)
        XCTAssertTrue(router.chooseReadyUpdate(.later, version: "1.1", generation: generation, receipt: receipt, presentation: replacement))
    }
    func testPersistenceFailureRetainsReceiptAndAllowsRetryWithoutRestoredConsent() async throws {
        let storage = InMemoryStorage()
        let router = await setup(storage)
        let receipt = try XCTUnwrap(router.readyReceipt)
        let generation = router.updates.generation
        let presentation = try XCTUnwrap(router.beginReadyPresentation())
        storage.failWrites = true
        XCTAssertFalse(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1", generation: generation, receipt: receipt, presentation: presentation))
        XCTAssertNil(router.readyIntent)
        XCTAssertEqual(router.readyReceipt, receipt)
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        storage.failWrites = false
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1", generation: generation, receipt: receipt, presentation: presentation))
        let restored = UpdateStore(storage: storage)
        XCTAssertEqual(restored.state, .failed(.interruptedUpdate, receipt))
        let freshRouter = AppRouter(updateService: FakeUpdateService(), updates: restored)
        XCTAssertNil(freshRouter.readyReceipt)
        XCTAssertNil(freshRouter.readyIntent)
    }
    func testLaterRetainsStagingAndReopenedPresentationNeedsFreshIntent() async throws {
        let router = await setup()
        let receipt = try XCTUnwrap(router.readyReceipt)
        let oldGeneration = router.updates.generation
        let old = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertTrue(router.chooseReadyUpdate(.later, version: "1.1", generation: oldGeneration, receipt: receipt, presentation: old))
        let fresh = try XCTUnwrap(router.beginReadyPresentation())
        XCTAssertNil(router.readyIntent)
        XCTAssertFalse(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1", generation: oldGeneration, receipt: receipt, presentation: fresh))
        XCTAssertTrue(router.chooseReadyUpdate(.installAndRelaunch, version: "1.1", generation: router.updates.generation, receipt: receipt, presentation: fresh))
        XCTAssertNil(router.beginReadyPresentation())
    }
    #if DEBUG || SWIFT_PACKAGE
    func testFixture() throws {
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.5/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.5/base"])
        XCTAssertEqual(try ScenarioRegistry.resolve("J10.5").story.node, "34:5608")
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.5"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.5/other"]))
    }
    #endif
}
