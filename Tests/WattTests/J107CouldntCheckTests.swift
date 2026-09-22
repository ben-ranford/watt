import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J107CouldntCheckTests: XCTestCase {
    private func settle() async { for _ in 0..<40 { await Task.yield() } }
    private func start(_ router: AppRouter) -> Bool {
        router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
    }
    func testNativeCopyButtonsAndOSOwnership() {
        _ = NSApplication.shared
        let alert = CouldntCheckAlert.make()
        XCTAssertEqual(alert.messageText, "Couldn’t check for updates")
        XCTAssertEqual(alert.informativeText, "No connection right now. Watt? checks again later on its own.")
        XCTAssertEqual(alert.buttons.map(\.title), ["Try Again", "OK"])
        XCTAssertEqual(alert.buttons.first?.keyEquivalent, "\r")
        XCTAssertNotNil(alert.icon)
        XCTAssertNil(alert.accessoryView)
        XCTAssertNil(alert.window.appearance)
        XCTAssertEqual(alert.alertStyle, .informational)
    }
    func testFailureRetryAndOKArePresentationScoped() async throws {
        let service = J107Service()
        let storage = InMemoryStorage()
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        XCTAssertTrue(start(router)); await settle()
        service.finish(.failure(.network)); await settle()
        XCTAssertTrue(router.couldntCheckPresented)
        let old = try XCTUnwrap(router.checkFailurePresentation)
        XCTAssertFalse(AppRouter(updates: UpdateStore(storage: storage)).couldntCheckPresented)
        XCTAssertTrue(router.retryCouldntCheck(old)); await settle()
        XCTAssertFalse(router.retryCouldntCheck(old))
        service.finish(.failure(.network)); await settle()
        let fresh = try XCTUnwrap(router.checkFailurePresentation)
        XCTAssertNotEqual(old, fresh)
        XCTAssertFalse(router.dismissCouldntCheck(old))
        XCTAssertFalse(router.retryCouldntCheck(old))
        XCTAssertTrue(router.dismissCouldntCheck(fresh))
        XCTAssertFalse(router.dismissCouldntCheck(fresh))
        XCTAssertFalse(router.couldntCheckPresented)
        XCTAssertEqual(service.checks, 2)
        XCTAssertEqual(destinations, [.softwareUpdate, .softwareUpdate])
    }
    func testClosedAndStaleChecksNeverPresent() async {
        for close in [true, false] {
            let service = J107Service()
            let router = AppRouter(updateService: service)
            XCTAssertTrue(start(router)); await settle()
            if close { router.closeUpdatePresentation() } else { router.updates.renewGeneration() }
            service.finish(.failure(.network)); await settle()
            XCTAssertFalse(router.couldntCheckPresented)
        }
    }
    func testPersistenceFailuresDoNotPresentAndRetryRemainsUsable() async throws {
        let service = J107Service()
        let storage = InMemoryStorage()
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        XCTAssertTrue(start(router)); await settle()
        storage.failWrites = true
        service.finish(.failure(.network)); await settle()
        XCTAssertFalse(router.couldntCheckPresented)
        XCTAssertEqual(router.updates.state, .checking)
        storage.failWrites = false
        XCTAssertTrue(router.cancelUpdateCheck())
        XCTAssertTrue(start(router)); await settle()
        service.finish(.failure(.network)); await settle()
        let token = try XCTUnwrap(router.checkFailurePresentation)
        storage.failWrites = true
        XCTAssertFalse(router.retryCouldntCheck(token))
        XCTAssertTrue(router.couldntCheckPresented)
        XCTAssertEqual(service.checks, 2)
        storage.failWrites = false
        XCTAssertTrue(router.retryCouldntCheck(token)); await settle()
        service.finish(.success(nil)); await settle()
        XCTAssertFalse(router.couldntCheckPresented)
        XCTAssertTrue(router.upToDatePresented)
    }
    func testReceiptStateAndClosedAlertRejectActions() async throws {
        let service = J107Service()
        let router = AppRouter(updateService: service)
        XCTAssertTrue(start(router)); await settle()
        service.finish(.failure(.network)); await settle()
        let token = try XCTUnwrap(router.checkFailurePresentation)
        let receipt = OperationReceipt(createdAt: Date())
        XCTAssertTrue(router.updates.accept(.checking, generation: router.updates.generation))
        XCTAssertTrue(router.updates.accept(.available(version: "1.1"), generation: router.updates.generation))
        XCTAssertTrue(router.updates.beginDownload(version: "1.1", receipt: receipt, generation: router.updates.generation))
        XCTAssertTrue(router.updates.accept(.failed(.network, receipt), generation: router.updates.generation))
        XCTAssertFalse(router.couldntCheckPresented)
        XCTAssertFalse(router.retryCouldntCheck(token))
        XCTAssertFalse(router.dismissCouldntCheck(token))
        router.closeUpdatePresentation()
        XCTAssertNil(router.checkFailurePresentation)
    }
    func testClosingPresentedFailureRejectsRetainedButtons() async throws {
        let service = J107Service()
        let router = AppRouter(updateService: service)
        XCTAssertTrue(start(router)); await settle()
        service.finish(.failure(.network)); await settle()
        let token = try XCTUnwrap(router.checkFailurePresentation)
        router.closeUpdatePresentation()
        XCTAssertFalse(router.couldntCheckPresented)
        XCTAssertFalse(router.retryCouldntCheck(token))
        XCTAssertFalse(router.dismissCouldntCheck(token))
        XCTAssertEqual(service.checks, 1)
    }
    func testCancellationAndOfferDoNotShowError() async {
        for outcome: ServiceOutcome<String?> in [.failure(.cancelled), .success("1.1"), .success(nil)] {
            let service = J107Service()
            let router = AppRouter(updateService: service)
            XCTAssertTrue(start(router)); await settle()
            service.finish(outcome); await settle()
            XCTAssertFalse(router.couldntCheckPresented)
        }
    }
    #if DEBUG || SWIFT_PACKAGE
    func testFixtureRegistryAndReleaseBoundary() throws {
        XCTAssertEqual(try ScenarioRegistry.resolve("J10.7").story.node, "34:6003")
        XCTAssertEqual(try ScenarioRegistry.resolve("J10.7").story.status, "implemented")
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.7/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.7/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.7"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.7/other"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J107FixtureLaunch.requested)
        #endif
    }
    #endif
}

@MainActor
private final class J107Service: UpdateService {
    private var continuation: CheckedContinuation<ServiceOutcome<String?>, Never>?
    private(set) var checks = 0
    func check() async -> ServiceOutcome<String?> {
        checks += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ result: ServiceOutcome<String?>) { continuation?.resume(returning: result); continuation = nil }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
