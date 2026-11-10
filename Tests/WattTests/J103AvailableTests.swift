import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J103AvailableTests: XCTestCase {
    private func offered(storage: InMemoryStorage = InMemoryStorage()) async -> (AppRouter, FakeUpdateService) {
        let service = FakeUpdateService()
        service.availableVersion = .success("1.1")
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        XCTAssertTrue(router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation()))
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        return (router, service)
    }

    func testInstallPersistsBothCheckboxChoicesBeforeDownload() async throws {
        for enabled in [true, false] {
            let storage = InMemoryStorage()
            let (router, service) = await offered(storage: storage)
            XCTAssertTrue(router.updates.saveAutomaticInstallChoice(!enabled))
            let generation = router.updates.generation
            XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: enabled))
            XCTAssertEqual(router.updates.state, .downloading(progress: 0))
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, enabled)
            XCTAssertEqual(UpdateStore(storage: storage).installFutureUpdatesAutomatically, enabled)
            XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: !enabled))
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, enabled)
            for _ in 0..<30 { await Task.yield() }
            XCTAssertFalse(service.transactions.isEmpty)
        }
    }

    func testInstallChoiceFailureIsVisibleAndRetryableWithoutDownloadEffects() async {
        let storage = InMemoryStorage()
        let (router, service) = await offered(storage: storage)
        let generation = router.updates.generation
        storage.failWrites = true
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: true))
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertFalse(router.updates.installFutureUpdatesAutomatically)
        XCTAssertNil(router.updates.downloadReceipt)
        XCTAssertNil(router.updateOfferIntent)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertTrue(service.transactions.isEmpty)
        storage.failWrites = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: true))
        XCTAssertNil(router.updates.persistenceFailure)
        XCTAssertTrue(UpdateStore(storage: storage).installFutureUpdatesAutomatically)
        for _ in 0..<30 { await Task.yield() }
    }

    func testChoiceIsSavedBeforeDownloadJournalAndJournalFailureCanRetry() async {
        let storage = AutomaticInstallOrderingStorage()
        let store = UpdateStore(storage: storage)
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "1.1"), generation: store.generation))
        let service = FakeUpdateService()
        let router = AppRouter(updateService: service, updates: store)
        storage.rejectDownloadJournal = true
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: store.generation, automaticUpdates: true))
        XCTAssertEqual(storage.choiceAtDownloadJournal, true)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(store.state, .available(version: "1.1"))
        XCTAssertNil(store.downloadReceipt)
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertTrue(service.transactions.isEmpty)
        storage.rejectDownloadJournal = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: store.generation, automaticUpdates: false))
        XCTAssertEqual(storage.choiceAtDownloadJournal, false)
        for _ in 0..<30 { await Task.yield() }
    }

    func testInvalidInstallOfferCannotChangeSavedChoice() async {
        let storage = InMemoryStorage()
        let (router, service) = await offered(storage: storage)
        XCTAssertFalse(router.installOfferedUpdate(version: "wrong", generation: router.updates.generation, automaticUpdates: true))
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: UUID(), automaticUpdates: true))
        XCTAssertFalse(router.updates.installFutureUpdatesAutomatically)
        XCTAssertNil(storage.values["update.automatic-install.v1"])
        XCTAssertTrue(service.transactions.isEmpty)
    }

    func testAutomaticInstallPreferenceDefaultsOffAndNeverRestoresConsent() {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        XCTAssertFalse(store.installFutureUpdatesAutomatically)
        XCTAssertTrue(store.saveAutomaticInstallChoice(true))
        let restored = UpdateStore(storage: storage)
        XCTAssertTrue(restored.installFutureUpdatesAutomatically)
        XCTAssertEqual(restored.state, .idle)
        XCTAssertNil(restored.downloadReceipt)
    }

    func testEveryActionHandsOffWithoutInstallationOrHelperEffects() async {
        for action: UpdateOfferAction in [.skip, .remindLater, .install] {
            let (router, service) = await offered()
            let generation = router.updates.generation
            XCTAssertTrue(router.chooseUpdateOffer(action, version: "1.1", generation: generation, automaticUpdates: true))
            XCTAssertEqual(router.updateOfferIntent, UpdateOfferIntent(action: action, version: "1.1", automaticUpdates: true))
            XCTAssertEqual(router.updates.state, action == .install ? .available(version: "1.1") : .idle)
            XCTAssertFalse(router.chooseUpdateOffer(action, version: "1.1", generation: generation, automaticUpdates: true))
            XCTAssertTrue(service.transactions.isEmpty)
            XCTAssertFalse(router.helperUpdate.presented)
        }
    }

    func testStaleWrongVersionAndUnconfiguredActionsFailClosed() async {
        let (router, _) = await offered()
        XCTAssertFalse(router.chooseUpdateOffer(.install, version: "1.2", generation: router.updates.generation, automaticUpdates: false))
        XCTAssertFalse(router.chooseUpdateOffer(.skip, version: "1.1", generation: UUID(), automaticUpdates: false))
        let closed = AppRouter()
        XCTAssertFalse(closed.chooseUpdateOffer(.install, version: "1.1", generation: closed.updates.generation, automaticUpdates: false))
        XCTAssertNil(router.updateOfferIntent)
    }

    func testFailedDismissPersistenceRetainsOfferAndCanRetry() async {
        let storage = InMemoryStorage()
        let (router, _) = await offered(storage: storage)
        let generation = router.updates.generation
        storage.failWrites = true
        XCTAssertFalse(router.chooseUpdateOffer(.remindLater, version: "1.1", generation: generation, automaticUpdates: false))
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        storage.failWrites = false
        XCTAssertTrue(router.chooseUpdateOffer(.remindLater, version: "1.1", generation: generation, automaticUpdates: false))
    }

    func testRestoredOfferRequiresFreshTrustedCheck() async {
        let storage = InMemoryStorage()
        _ = await offered(storage: storage)
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, nil))
    }

    func testRetainedReceiptCannotBeOverwrittenByOfferOrActions() throws {
        let storage = InMemoryStorage()
        let receipt = OperationReceipt(createdAt: Date())
        try storage.write(JSONEncoder().encode(UpdateState.staged(receipt)), key: "update.v1")
        let store = UpdateStore(storage: storage)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        XCTAssertEqual(store.state, .failed(.interruptedUpdate, receipt))
        XCTAssertFalse(store.accept(.available(version: "1.1"), generation: store.generation))
        XCTAssertFalse(store.accept(.idle, generation: store.generation))
        XCTAssertFalse(router.chooseUpdateOffer(.skip, version: "1.1", generation: store.generation, automaticUpdates: false))
        XCTAssertFalse(router.canCheckForUpdates)
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, receipt))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testExactFixtureAndPackageIsolation() throws {
        let fixture = try ScenarioRegistry.resolve("J10.3")
        XCTAssertEqual(fixture.story.node, "J10.3")
        XCTAssertEqual(fixture.story.status, "implemented")
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.3/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.3/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.3"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.3/other"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J103FixtureLaunch.requested)
        #endif
    }
    #endif

    func testAvailableNativeLayout() async {
        _ = NSApplication.shared
        let (router, _) = await offered()
        let host = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        XCTAssertEqual(host.fittingSize.width, 520, accuracy: 1)
        XCTAssertGreaterThanOrEqual(host.fittingSize.height, 334)
        XCTAssertLessThan(host.fittingSize.height, 500)
    }
}

@MainActor
private final class AutomaticInstallOrderingStorage: PreferenceStorage {
    let memory = InMemoryStorage()
    var rejectDownloadJournal = false
    var choiceAtDownloadJournal: Bool?
    func read(key: String) throws -> Data? { try memory.read(key: key) }
    func write(_ data: Data, key: String) throws {
        if key == "update.v1",
           case .failed(.interruptedUpdate, .some) = try JSONDecoder().decode(UpdateState.self, from: data) {
            choiceAtDownloadJournal = try memory.read(key: "update.automatic-install.v1").map {
                try JSONDecoder().decode(Bool.self, from: $0)
            }
            if rejectDownloadJournal { throw ServiceFailure.persistence }
        }
        try memory.write(data, key: key)
    }
}
