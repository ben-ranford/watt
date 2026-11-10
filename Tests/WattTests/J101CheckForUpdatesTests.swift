import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J101CheckForUpdatesTests: XCTestCase {
    private func menu(_ router: AppRouter) -> NSMenu {
        _ = NSApplication.shared
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.completed = true
        return StatusItemContextMenu.makeMenu(router: router, preferences: preferences)
    }
    private func invoke(_ menu: NSMenu) {
        menu.performActionForItem(at: menu.items.firstIndex { $0.title == "Check for Updates…" }!)
    }
    private func settle() async { for _ in 0..<20 { await Task.yield() } }

    func testExactNativeMenuOrderShortcutsAndUnavailableService() {
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let menu = menu(router)
        XCTAssertEqual(menu.items.map { $0.isSeparatorItem ? "separator" : $0.title }, [
            "Show in Menu Bar", "separator", "Open Watt?", "Settings…", "separator",
            "About Watt?", "Check for Updates…", "separator", "Quit Watt?"
        ])
        XCTAssertTrue(menu.items.allSatisfy { $0.view == nil })
        XCTAssertEqual(menu.items[3].keyEquivalent, ",")
        XCTAssertEqual(menu.items[3].keyEquivalentModifierMask, .command)
        XCTAssertEqual(menu.items[8].keyEquivalent, "q")
        XCTAssertEqual(menu.items[8].keyEquivalentModifierMask, .command)
        XCTAssertEqual(menu.items[6].keyEquivalent, "")
        XCTAssertEqual(menu.items[6].keyEquivalentModifierMask, [])
        menu.update()
        XCTAssertFalse(menu.items[6].isEnabled)
        invoke(menu)
        XCTAssertEqual(router.updates.state, .idle)
        XCTAssertTrue(routes.isEmpty)
    }

    func testNativeActionChecksOnceAndDoesNotOpenHelperPrompt() async {
        let service = SuspendedCheckService()
        let router = AppRouter(updateService: service)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let menu = menu(router)
        XCTAssertTrue(menu.items[6].isEnabled)
        invoke(menu)
        invoke(menu)
        XCTAssertEqual(router.updates.state, .checking)
        menu.update()
        XCTAssertFalse(menu.items[6].isEnabled)
        await settle()
        XCTAssertEqual(service.calls, 1)
        service.finish(.success("42"))
        await settle()
        XCTAssertEqual(router.updates.state, .available(version: "42"))
        XCTAssertFalse(router.canCheckForUpdates)
        XCTAssertFalse(router.helperUpdate.presented)
        XCTAssertEqual(routes, [.softwareUpdate])
    }

    func testClosedReplacedAndConsumedMenusCannotCheck() async {
        let service = SuspendedCheckService()
        let router = AppRouter(updateService: service)
        let closed = menu(router)
        StatusItemContextMenu.endPresentation(closed)
        invoke(closed)
        let replaced = menu(router)
        let current = menu(router)
        invoke(replaced)
        XCTAssertEqual(router.updates.state, .idle)
        invoke(current)
        await settle()
        service.finish(.success(nil))
        await settle()
        XCTAssertEqual(router.updates.state, .idle)
        invoke(current)
        await settle()
        XCTAssertEqual(service.calls, 1)
        router.dismissUpToDate() // J10.6 OK returns to the status item before a fresh check.
        let fresh = menu(router)
        invoke(fresh)
        await settle()
        XCTAssertEqual(service.calls, 2)
        service.finish(.failure(.network))
        await settle()
        XCTAssertEqual(router.updates.state, .failed(.network, nil))
        XCTAssertTrue(router.canCheckForUpdates)
    }

    func testStaleAsyncResultCannotOverwriteCancelledGeneration() async {
        let service = SuspendedCheckService()
        let router = AppRouter(updateService: service)
        invoke(menu(router))
        await settle()
        XCTAssertTrue(router.updates.cancel())
        XCTAssertFalse(router.canCheckForUpdates) // service must finish before another check
        service.finish(.success("stale"))
        await settle()
        XCTAssertEqual(router.updates.state, .failed(.cancelled, nil))
        XCTAssertTrue(router.canCheckForUpdates)
    }

    func testPersistenceFailureDoesNotCallServiceOrReuseMenu() async {
        let storage = InMemoryStorage()
        let store = UpdateStore(storage: storage)
        let service = SuspendedCheckService()
        let router = AppRouter(updateService: service, updates: store)
        let original = menu(router)
        storage.failWrites = true
        invoke(original)
        await settle()
        XCTAssertEqual(store.state, .idle)
        XCTAssertEqual(store.persistenceFailure, .persistence)
        XCTAssertEqual(service.calls, 0)
        storage.failWrites = false
        invoke(original)
        XCTAssertEqual(store.state, .idle)
        invoke(menu(router))
        await settle()
        XCTAssertEqual(service.calls, 1)
        service.finish(.failure(.network))
        await settle()
    }

    func testRetainedTransactionDisablesCheck() {
        let store = UpdateStore()
        let receipt = OperationReceipt(createdAt: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(store.accept(.checking, generation: store.generation))
        XCTAssertTrue(store.accept(.available(version: "42"), generation: store.generation))
        XCTAssertTrue(store.accept(.downloading(progress: 0), generation: store.generation))
        XCTAssertTrue(store.accept(.staged(receipt), generation: store.generation))
        let router = AppRouter(updateService: SuspendedCheckService(), updates: store)
        XCTAssertFalse(router.canCheckForUpdates)
        invoke(menu(router))
        XCTAssertEqual(store.state, .staged(receipt))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testExactReferenceAndFixtureRemainFailClosedWithoutProductionComposition() throws {
        let fixture = try ScenarioRegistry.resolve("J10.1")
        XCTAssertEqual(fixture.story.node, "J10.1")
        XCTAssertEqual(fixture.story.expectedScene, "contextMenu")
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J10.1"]))
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(["--watt-fixture", "J10.1/base"]))
        XCTAssertThrowsError(try selection.smokeLaunchArguments())
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: ["--watt-fixture", "J10.1/base"]))
    }
    #endif
}

@MainActor
private final class SuspendedCheckService: UpdateService {
    var calls = 0
    private var continuation: CheckedContinuation<ServiceOutcome<String?>, Never>?
    func check() async -> ServiceOutcome<String?> {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ outcome: ServiceOutcome<String?>) {
        continuation?.resume(returning: outcome)
        continuation = nil
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
