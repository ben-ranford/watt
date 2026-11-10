import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J123UninstalledTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactEmptyFixture() throws {
        let fixture = try ScenarioRegistry.resolve("J12.3")
        XCTAssertEqual(fixture.story.node, "J12.3")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J12.3/base"])
        for value in ["J12.3", "J12.3/", "J12.3/dark", "J12.3/base/extra", "J12.3/partial-cleanup"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
        #if SWIFT_PACKAGE
        XCTAssertFalse(J123FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.3/base"]))
        #else
        XCTAssertTrue(J123FixtureLaunch.matches(arguments: ["--watt-fixture", "J12.3/base"]))
        #endif
    }
    #endif

    private func confirm(_ router: AppRouter) async throws -> RemovalOutcome? {
        let token = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: token, removing: false))
        return await router.confirmUninstall(try XCTUnwrap(router.uninstallIntent))
    }

    func testScopedCompletionClosesOnlyAfterAllOwnedResourcesVerified() async throws {
        let driver = J123Driver()
        let helper = FakeHelperService()
        helper.status = .connected
        let adapter = try ScopedRemovalAdapter(manifest: driver.manifest, driver: driver, helper: helper)
        let router = AppRouter()
        router.configureUninstall(adapter: adapter)
        var exits = 0
        router.onUninstalled = {
            XCTAssertTrue(driver.paths.isEmpty)
            XCTAssertFalse(driver.appRunning)
            XCTAssertFalse(driver.helperRunning)
            XCTAssertEqual(adapter.report?.remainingPaths, [])
            exits += 1
        }
        router.statusPanelPresented = true
        let outcome = try await confirm(router)
        XCTAssertEqual(outcome, .verifiedAbsent)
        XCTAssertEqual(driver.calls, [.login, .helper, .configuration, .application])
        XCTAssertEqual(driver.unrelated, "untouched desktop data")
        XCTAssertTrue(router.uninstallCompleted)
        XCTAssertFalse(router.statusPanelPresented)
        XCTAssertEqual(exits, 1)
        let reopened = router.beginUninstallPresentation()
        XCTAssertFalse(router.requestUninstall(presentation: reopened, removing: false))
    }

    func testIncompleteInventoryCannotExitAndRetryRetainsReceipt() async throws {
        let driver = J123Driver()
        driver.retainApplication = true
        let helper = FakeHelperService()
        helper.status = .connected
        let adapter = try ScopedRemovalAdapter(manifest: driver.manifest, driver: driver, helper: helper)
        let router = AppRouter()
        router.configureUninstall(adapter: adapter)
        var exits = 0
        router.onUninstalled = { exits += 1 }
        let first = try await confirm(router)
        XCTAssertNotEqual(first, .verifiedAbsent)
        XCTAssertEqual(exits, 0)
        XCTAssertFalse(router.uninstallCompleted)
        let receipt = driver.saved?.receipt
        driver.retainApplication = false
        let retry = try await confirm(router)
        XCTAssertEqual(retry, .verifiedAbsent)
        XCTAssertEqual(driver.saved?.receipt, receipt)
        XCTAssertEqual(exits, 1)
    }

    func testCancelFailureUnknownAndInterruptionKeepPresentation() async throws {
        for outcome: RemovalOutcome in [.cancelled, .failed(.unknownStatus), .failed(.persistence),
                                         .interrupted(OperationReceipt(createdAt: Date()))] {
            let router = AppRouter()
            var exits = 0
            router.onUninstalled = { exits += 1 }
            router.removeFromSettings = { _ in outcome }
            let result = try await confirm(router)
            XCTAssertEqual(result, outcome)
            XCTAssertEqual(exits, 0)
            XCTAssertFalse(router.uninstallCompleted)
        }
    }

    func testMissingOwnedCategoryFailsClosedBeforeEffects() async throws {
        let driver = J123Driver()
        let manifest = RemovalManifest(installationID: UUID(), resources: [
            .init(path: "/fixture/app", kind: .application)
        ])
        let adapter = try ScopedRemovalAdapter(manifest: manifest, driver: driver, helper: FakeHelperService())
        let router = AppRouter()
        router.configureUninstall(adapter: adapter)
        let result = try await confirm(router)
        XCTAssertEqual(result, .failed(.invalidData))
        XCTAssertTrue(driver.calls.isEmpty)
        XCTAssertNil(driver.saved)
    }
}

@MainActor
private final class J123Driver: OwnedRemovalDriver {
    let manifest = RemovalManifest(installationID: UUID(), resources: [
        .init(path: "/fixture/login", kind: .login),
        .init(path: "/fixture/helper", kind: .helper),
        .init(path: "/fixture/settings", kind: .configuration),
        .init(path: "/fixture/app", kind: .application)
    ])
    lazy var paths = Set(manifest.resources.map(\.path))
    let unrelated = "untouched desktop data"
    var helperRunning = true
    var appRunning = true
    var retainApplication = false
    var saved: RemovalTransaction?
    var calls: [RemovalManifest.Kind] = []
    func inventory(manifest: RemovalManifest) async throws -> RemovalInventory {
        guard manifest == self.manifest else { throw ServiceFailure.untrustedIdentity }
        return RemovalInventory(presentPaths: paths, helperRunning: helperRunning, appRunning: appRunning)
    }
    func transaction() throws -> RemovalTransaction? { saved }
    func save(_ transaction: RemovalTransaction) throws { saved = transaction }
    func remove(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        guard transaction == saved, manifest.resources.contains(resource) else { throw ServiceFailure.untrustedIdentity }
        calls.append(resource.kind)
        if resource.kind == .application && retainApplication { return }
        paths.remove(resource.path)
        if resource.kind == .helper { helperRunning = false }
        if resource.kind == .application { appRunning = false }
    }
    func restore(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        XCTFail("No automatic restoration during uninstall")
    }
}
