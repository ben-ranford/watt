import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J108HelperUpdateTests: XCTestCase {
    func testNativeAlertAndFixture() throws {
        let alert = HelperChangedAlert.make()
        XCTAssertEqual(alert.alertStyle, .informational)
        XCTAssertEqual(alert.messageText, "The helper changed")
        XCTAssertEqual(alert.informativeText, "Watt? 1.1 comes with a new helper. macOS asks you to approve it once more.")
        XCTAssertEqual(alert.buttons.map(\.title), ["Update Helper", "Later"])
        XCTAssertEqual(alert.buttons.map(\.keyEquivalent), ["\r", "\u{1b}"])
        XCTAssertNil(alert.window.appearance)
        let fixture = try ScenarioRegistry.resolve("J10.8")
        XCTAssertEqual(fixture.story.node, "34:6183")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J10.8/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J10.8/other"]))
    }
    func testStalePresentationCannotUpdateOrDismissNewPrompt() async {
        let prompt = HelperUpdatePrompt()
        var calls = 0
        prompt.verifyRelaunch = { calls += 1; return true }
        prompt.presented = true
        let old = prompt.presentationID
        prompt.close()
        prompt.presented = true
        await prompt.update(presentation: old)
        prompt.later(presentation: old)
        XCTAssertTrue(prompt.presented)
        XCTAssertEqual(calls, 0)
        prompt.later(presentation: prompt.presentationID)
        XCTAssertFalse(prompt.presented)
    }
    func testCloseDuringVerificationPreventsHelperMutation() async {
        let prompt = HelperUpdatePrompt()
        var pending: CheckedContinuation<Bool, Never>?
        var calls = 0
        prompt.verifyRelaunch = { await withCheckedContinuation { pending = $0 } }
        prompt.updateHelper = { _ in calls += 1; return .success(.connected) }
        let task = Task { await prompt.update() }
        while pending == nil { await Task.yield() }
        prompt.close()
        pending?.resume(returning: true)
        await task.value
        XCTAssertEqual(calls, 0)
        XCTAssertNil(prompt.outcome)
        XCTAssertFalse(prompt.busy)
    }
    func testLateGenerationCannotClearNewBusyOrOutcome() async {
        let prompt = HelperUpdatePrompt()
        var pending: [CheckedContinuation<Bool, Never>] = []
        prompt.verifyRelaunch = { await withCheckedContinuation { pending.append($0) } }
        prompt.updateHelper = { _ in .success(.awaitingApproval) }
        let old = Task { await prompt.update() }
        while pending.count < 1 { await Task.yield() }
        prompt.close()
        let current = Task { await prompt.update() }
        while pending.count < 2 { await Task.yield() }
        pending[0].resume(returning: false)
        await old.value
        XCTAssertTrue(prompt.busy)
        XCTAssertNil(prompt.outcome)
        pending[1].resume(returning: true)
        await current.value
        XCTAssertFalse(prompt.busy)
        guard case .success(.awaitingApproval) = prompt.outcome else { return XCTFail() }
    }
    func testRetryReusesReceiptAndLaterDoesNotInvokeBoundaries() async {
        let prompt = HelperUpdatePrompt()
        prompt.verifyRelaunch = { true }
        var receipts: [OperationReceipt] = []
        prompt.updateHelper = { receipts.append($0); return .failure(.cancelled) }
        for _ in 0..<2 {
            prompt.presented = true
            await prompt.update(presentation: prompt.presentationID)
        }
        XCTAssertEqual(receipts.count, 2)
        XCTAssertEqual(receipts.first, receipts.last)
        prompt.presented = true
        prompt.later(presentation: prompt.presentationID)
        XCTAssertEqual(receipts.count, 2)
    }
}
