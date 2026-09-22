import XCTest
@testable import Watt

@MainActor
final class UpdateOfferInstallTests: XCTestCase {
    private func offered(_ storage: OfferStorage = OfferStorage()) -> (AppRouter, OfferDownloadService) {
        let store = UpdateStore(storage: storage)
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "1.1"), generation: store.generation))
        let service = OfferDownloadService()
        return (AppRouter(updateService: service, updates: store), service)
    }

    func testBothCheckboxChoicesAreSavedBeforeDownloadAdmission() async {
        for automaticUpdates in [false, true] {
            let storage = OfferStorage()
            let (router, service) = offered(storage)
            var observedAdmission = false
            storage.beforeWrite = { key in
                guard key == "update.v1" else { return }
                XCTAssertEqual(UpdateStore(storage: storage).installFutureUpdatesAutomatically, automaticUpdates)
                XCTAssertNil(router.downloadVersion)
                observedAdmission = true
            }
            XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: router.updates.generation,
                                                      automaticUpdates: automaticUpdates))
            storage.beforeWrite = nil
            XCTAssertTrue(observedAdmission)
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, automaticUpdates)
            XCTAssertEqual(router.updates.state, .downloading(progress: 0))
            XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: router.updates.generation,
                                                       automaticUpdates: !automaticUpdates))
            XCTAssertEqual(router.updates.installFutureUpdatesAutomatically, automaticUpdates)
            for _ in 0..<30 { await Task.yield() }
            service.finish()
            for _ in 0..<30 { await Task.yield() }
            XCTAssertEqual(service.installs, 0)
        }
    }

    func testPersistenceFailureRetainsOfferAndAllowsChangedChoiceOnRetry() async {
        let storage = OfferStorage()
        let (router, service) = offered(storage)
        let generation = router.updates.generation
        storage.backing.failWrites = true
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: true))
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertNil(router.downloadVersion)
        XCTAssertNil(router.updates.downloadReceipt)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertNil(service.receipt)
        storage.backing.failWrites = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: generation, automaticUpdates: false))
        XCTAssertNil(router.updates.persistenceFailure)
        XCTAssertFalse(router.updates.installFutureUpdatesAutomatically)
        for _ in 0..<30 { await Task.yield() }
        service.finish()
        for _ in 0..<30 { await Task.yield() }
    }

    func testReceiptWriteFailureAfterChoiceSaveDoesNotStartService() async {
        let storage = OfferStorage()
        let (router, service) = offered(storage)
        storage.beforeWrite = { key in
            if key == "update.v1" { storage.backing.failWrites = true }
        }
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: router.updates.generation,
                                                   automaticUpdates: true))
        storage.beforeWrite = nil
        XCTAssertTrue(UpdateStore(storage: storage).installFutureUpdatesAutomatically)
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertNil(router.downloadVersion)
        XCTAssertNil(router.updates.downloadReceipt)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertNil(service.receipt)
        storage.backing.failWrites = false
        XCTAssertTrue(router.installOfferedUpdate(version: "1.1", generation: router.updates.generation,
                                                  automaticUpdates: true))
        for _ in 0..<30 { await Task.yield() }
        service.finish()
        for _ in 0..<30 { await Task.yield() }
    }

    func testStaleWrongVersionAndUnconfiguredOfferCannotStartDownload() {
        let (router, service) = offered()
        XCTAssertFalse(router.installOfferedUpdate(version: "1.1", generation: UUID(), automaticUpdates: true))
        XCTAssertFalse(router.installOfferedUpdate(version: "wrong", generation: router.updates.generation,
                                                   automaticUpdates: true))
        XCTAssertNil(router.updateOfferIntent)
        XCTAssertNil(service.receipt)
        let unconfigured = AppRouter()
        XCTAssertFalse(unconfigured.installOfferedUpdate(version: "1.1", generation: unconfigured.updates.generation,
                                                         automaticUpdates: true))
    }
}

@MainActor
private final class OfferStorage: PreferenceStorage {
    let backing = InMemoryStorage()
    var beforeWrite: ((String) -> Void)?
    func read(key: String) throws -> Data? { try backing.read(key: key) }
    func write(_ data: Data, key: String) throws {
        beforeWrite?(key)
        try backing.write(data, key: key)
    }
}

@MainActor
private final class OfferDownloadService: UpdateService {
    var receipt: OperationReceipt?
    var installs = 0
    private var reply: CheckedContinuation<ServiceOutcome<UpdateState>, Never>?
    func check() async -> ServiceOutcome<String?> { .success("1.1") }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        self.receipt = receipt
        return await withCheckedContinuation { reply = $0 }
    }
    func finish() {
        guard let receipt else { return }
        reply?.resume(returning: .success(.staged(receipt)))
        reply = nil
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        installs += 1
        return .failure(.denied)
    }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .success(.failed(.cancelled, receipt)) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .success(receipt) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
}
