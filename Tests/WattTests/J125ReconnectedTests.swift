import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J125ReconnectedTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactRegistryAndCopy() throws {
        let fixture = try ScenarioRegistry.resolve("J12.5")
        XCTAssertEqual(fixture.story.node, "J12.5")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J12.5/base"])
        XCTAssertEqual(SettingsHelperRows.reconnectNote, "Reconnected from your last install.")
        XCTAssertEqual(SettingsHelperRows.statusSubtitle, "CPU/GPU estimates appear only when both are available. Display, SSD and Other are unavailable.")
        for value in ["J12.5", "J12.5/dark", "J12.5/base/extra"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", value]))
        }
    }
    #endif

    func testDurableSuccessRoutesAllSetAndReflectsConnectionOnce() async throws {
        let storage = InMemoryStorage(), id = UUID()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        var destinations: [AppDestination] = []
        router.present = { destinations.append($0) }
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: id)
        prompt.detect = { true }
        var calls = 0
        prompt.reconnect = { calls += 1; return .connected }
        prompt.onCompleted = { _ in try router.completeLeftoverReconnect(preferences: preferences) }
        await prompt.discover()
        let intent = try XCTUnwrap(prompt.intent)
        await prompt.perform(.reconnect, intent: intent)
        await prompt.perform(.reconnect, intent: intent)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(destinations, [.onboarding])
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertTrue(router.settingsHelperSetup.reconnectedFromLastInstall)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.onboarding.checkpoint, .allSet)
        XCTAssertTrue(restored.onboarding.helperOptIn)
        XCTAssertFalse(restored.onboarding.completed)
        let relaunched = LeftoverHelperPrompt(storage: storage, installationID: id)
        relaunched.detect = { XCTFail("Completed receipt must suppress rediscovery"); return true }
        await relaunched.discover()
        XCTAssertNil(relaunched.intent)
    }

    func testFailedReceiptPreventsReconnectAndRetryDoesNotReplayAcknowledgedEffect() async throws {
        let storage = InMemoryStorage()
        let prompt = LeftoverHelperPrompt(storage: storage, installationID: UUID())
        prompt.detect = { true }
        var calls = 0, completions = 0
        prompt.reconnect = { calls += 1; storage.failWrites = true; return .connected }
        prompt.onCompleted = { _ in completions += 1 }
        await prompt.discover()
        storage.failWrites = true
        await prompt.perform(.reconnect, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(calls, 0)
        storage.failWrites = false
        await prompt.perform(.reconnect, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(prompt.failure, .persistence)
        XCTAssertEqual(completions, 0)
        storage.failWrites = false
        await prompt.perform(.reconnect, intent: try XCTUnwrap(prompt.intent))
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(completions, 1)
    }

    func testOnboardingPersistenceFailureDoesNotPublishOrRouteAndCanRetry() throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        var routes = 0
        router.present = { _ in routes += 1 }
        storage.failWrites = true
        XCTAssertThrowsError(try router.completeLeftoverReconnect(preferences: preferences))
        XCTAssertEqual(routes, 0)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
        storage.failWrites = false
        try router.completeLeftoverReconnect(preferences: preferences)
        XCTAssertEqual(routes, 1)
    }

    func testClosedPresentationDropsLateReconnectSuccess() async throws {
        let prompt = LeftoverHelperPrompt(storage: InMemoryStorage(), installationID: UUID())
        prompt.detect = { true }
        var reply: CheckedContinuation<HelperReconciliation, Never>?
        prompt.reconnect = { await withCheckedContinuation { reply = $0 } }
        prompt.onCompleted = { _ in XCTFail("Closed presentation must not navigate") }
        await prompt.discover()
        let old = try XCTUnwrap(prompt.intent)
        let task = Task { await prompt.perform(.reconnect, intent: old) }
        for _ in 0..<1000 {
            if reply != nil { break }
            await Task.yield()
        }
        let pending = try XCTUnwrap(reply)
        prompt.close(old)
        pending.resume(returning: .connected)
        await task.value
        await prompt.perform(.reconnect, intent: old)
        XCTAssertNil(prompt.intent)
        XCTAssertFalse(prompt.busy)
    }

    func testUndeliveredContinuationSurvivesRelaunchWithoutRepeatingReconnect() async throws {
        let storage = InMemoryStorage(), id = UUID()
        let first = LeftoverHelperPrompt(storage: storage, installationID: id)
        first.detect = { true }
        first.reconnect = { .connected }
        first.onCompleted = { _ in throw ServiceFailure.persistence }
        await first.discover()
        await first.perform(.reconnect, intent: try XCTUnwrap(first.intent))
        XCTAssertEqual(first.failure, .persistence)
        let retry = LeftoverHelperPrompt(storage: storage, installationID: id)
        retry.detect = { true }
        retry.reconnect = { XCTFail("Durably completed reconnect must not replay"); return .unknown }
        var delivered = false
        retry.onCompleted = { _ in delivered = true }
        await retry.discover()
        await retry.perform(.reconnect, intent: try XCTUnwrap(retry.intent))
        XCTAssertTrue(delivered)
        XCTAssertNil(retry.failure)
    }

    func testVerifiedReconnectSurvivesPresentationCloseButRemovalClearsIt() {
        let setup = SettingsHelperSetup()
        XCTAssertFalse(setup.helperOn)
        setup.acceptVerifiedReconnect()
        XCTAssertTrue(setup.helperOn)
        XCTAssertTrue(setup.reconnectedFromLastInstall)
        setup.close()
        XCTAssertTrue(setup.helperOn)
        XCTAssertTrue(setup.reconnectedFromLastInstall)
        setup.resetAfterVerifiedRemoval()
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(setup.reconnectedFromLastInstall)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixtureUsesInMemoryConnectionAndAllSetState() async {
        let router = AppRouter()
        let preferences = J125FixtureLaunch.makePreferences()
        await J125FixtureLaunch.prepare(router: router, preferences: preferences)
        XCTAssertTrue(router.settingsHelperSetup.helperOn)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertTrue(preferences.onboarding.helperOptIn)
    }
    #endif
}
