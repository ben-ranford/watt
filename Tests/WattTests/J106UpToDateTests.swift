import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J106UpToDateTests: XCTestCase {
    private func settle() async { for _ in 0..<40 { await Task.yield() } }
    private func start(_ router: AppRouter) -> Bool {
        router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
    }

    func testExactCopySuccessfulRoutingAndOKDismissal() async {
        let service = J106Service()
        let storage = InMemoryStorage()
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        XCTAssertEqual(UpToDateAlert.title, "You’re up to date")
        XCTAssertEqual(UpToDateAlert.primary, "OK")
        XCTAssertEqual(UpToDateAlert.message(version: "1.0"), "1.0 is the latest.")
        XCTAssertEqual(router.upToDateMessage, "\(router.currentAppVersion) is the latest.")
        XCTAssertFalse(router.upToDatePresented)
        XCTAssertTrue(start(router)); await settle()
        XCTAssertFalse(router.upToDatePresented)
        service.finish(.success(nil)); await settle()
        XCTAssertEqual(router.updates.state, .idle)
        XCTAssertTrue(router.upToDatePresented)
        XCTAssertFalse(router.canCheckForUpdates)
        XCTAssertEqual(destinations, [.softwareUpdate])
        XCTAssertFalse(AppRouter(updates: UpdateStore(storage: storage)).upToDatePresented)
        router.dismissUpToDate() // Native OK action: dismiss scene, no panel/window request.
        router.dismissUpToDate()
        XCTAssertFalse(router.upToDatePresented)
        XCTAssertEqual(destinations, [.softwareUpdate])
        XCTAssertTrue(router.canCheckForUpdates)
    }

    func testClosedPresentationRejectsNoncooperativeNilAndAllowsRetry() async {
        let service = J106Service()
        let router = AppRouter(updateService: service)
        XCTAssertTrue(start(router)); await settle()
        router.closeUpdatePresentation()
        service.finish(.success(nil)); await settle()
        XCTAssertFalse(router.upToDatePresented)
        XCTAssertEqual(router.updates.state, .failed(.cancelled, nil))
        XCTAssertTrue(start(router)); await settle()
        service.finish(.success(nil)); await settle()
        XCTAssertTrue(router.upToDatePresented)
        router.closeUpdatePresentation()
        XCTAssertFalse(router.upToDatePresented)
    }

    func testStaleGenerationCannotPresentNilResult() async {
        let service = J106Service()
        let router = AppRouter(updateService: service)
        XCTAssertTrue(start(router)); await settle()
        router.updates.renewGeneration()
        service.finish(.success(nil)); await settle()
        XCTAssertFalse(router.upToDatePresented)
        XCTAssertEqual(router.updates.state, .checking)
        XCTAssertTrue(router.cancelUpdateCheck())
        XCTAssertTrue(router.canCheckForUpdates)
    }

    func testPersistenceFailureNeverPresentsSuccessAndCancellationRetryRecovers() async {
        let storage = InMemoryStorage()
        let service = J106Service()
        let router = AppRouter(updateService: service, updates: UpdateStore(storage: storage))
        storage.failWrites = true
        XCTAssertFalse(start(router))
        XCTAssertEqual(service.checks, 0)
        storage.failWrites = false
        XCTAssertTrue(start(router)); await settle()
        storage.failWrites = true
        service.finish(.success(nil)); await settle()
        XCTAssertEqual(router.updates.persistenceFailure, .persistence)
        XCTAssertEqual(router.updates.state, .checking)
        XCTAssertFalse(router.upToDatePresented)
        XCTAssertFalse(router.cancelUpdateCheck())
        XCTAssertFalse(router.canCheckForUpdates)
        storage.failWrites = false
        XCTAssertTrue(router.cancelUpdateCheck())
        XCTAssertTrue(start(router)); await settle()
        service.finish(.success(nil)); await settle()
        XCTAssertTrue(router.upToDatePresented)
    }

    func testNetworkFailureAndOfferNeverShowUpToDate() async {
        for outcome: ServiceOutcome<String?> in [.failure(.network), .success("1.1")] {
            let service = J106Service()
            let router = AppRouter(updateService: service)
            XCTAssertTrue(start(router)); await settle()
            service.finish(outcome); await settle()
            XCTAssertFalse(router.upToDatePresented)
            if case .failure = outcome { XCTAssertTrue(router.canCheckForUpdates) }
        }
    }

    func testNativeAlertOwnsIconAndDefaultButton() {
        _ = NSApplication.shared
        let alert = UpToDateAlert.make(message: UpToDateAlert.message(version: "1.0"))
        XCTAssertEqual(alert.messageText, "You’re up to date")
        XCTAssertEqual(alert.informativeText, "1.0 is the latest.")
        XCTAssertEqual(alert.buttons.map(\.title), ["OK"])
        XCTAssertEqual(alert.buttons.first?.keyEquivalent, "\r")
        XCTAssertNotNil(alert.icon)
        XCTAssertNil(alert.accessoryView)
        XCTAssertEqual(alert.alertStyle, .informational)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixtureRegistryAndExactSelector() throws {
        let fixture = try ScenarioRegistry.resolve("J10.6")
        XCTAssertEqual(fixture.story.node, "J10.6")
        XCTAssertEqual(fixture.story.status, "implemented")
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.6/base"]))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J10.6/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.6"]))
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.6/other"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J106FixtureLaunch.requested)
        #endif
    }
    #endif
}

@MainActor
private final class J106Service: UpdateService {
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
