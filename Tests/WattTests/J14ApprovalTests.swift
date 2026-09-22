import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J14ApprovalTests: XCTestCase {
    func testPendingActionsDelegateWithoutGrantingApproval() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .approval
        preferences.onboarding.helperOptIn = true
        let before = preferences.onboarding
        let router = AppRouter()
        var settings = 0
        var cancellations = 0
        router.openApprovalSettings = { settings += 1 }
        router.cancelOnboardingApproval = { cancellations += 1 }
        WaitingForApprovalView.openSettings(preferences: preferences, router: router)
        WaitingForApprovalView.cancel(preferences: preferences, router: router)
        XCTAssertEqual(settings, 1)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(preferences.onboarding, before)
        preferences.onboarding.checkpoint = .helperOffer
        WaitingForApprovalView.openSettings(preferences: preferences, router: router)
        WaitingForApprovalView.cancel(preferences: preferences, router: router)
        XCTAssertEqual(settings, 1)
        XCTAssertEqual(cancellations, 1)
    }

    func testNativePendingContractAndFixture() throws {
        XCTAssertEqual(WaitingForApprovalView.title, "One switch in System Settings")
        XCTAssertEqual(WaitingForApprovalView.message, "Turn on “Watt? Helper” in Login Items & Extensions. This window moves on by itself.")
        let fixture = try ScenarioRegistry.resolve("J1.4")
        XCTAssertEqual(fixture.story.node, "28:1206")
        XCTAssertNoThrow(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments())
        for variant in fixture.story.variants where variant != "base" {
            XCTAssertThrowsError(try FixtureLaunchSelection.story(ScenarioRegistry.resolve("J1.4", variant: variant)).smokeLaunchArguments())
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("checkpoint == .approval {\n                WaitingForApprovalView()"))
        let view = source.components(separatedBy: "struct WaitingForApprovalView")[1]
        for token in ["Text(Self.title)", "Text(Self.message)", "ProgressView()", ".buttonStyle(.bordered)", ".buttonStyle(.borderedProminent)", "Button(\"Cancel\")", "Button(\"Open System Settings\")"] {
            XCTAssertTrue(view.contains(token), token)
        }
        for token in ["ProgressView(value:", "UNUserNotification", "RoundedRectangle", "Timer", ".overlay("] {
            XCTAssertFalse(view.contains(token), token)
        }
        let window = J14FixtureLaunch.makeWindow()
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.contentView!.fittingSize.width, 480)
        XCTAssertEqual(window.contentView!.fittingSize.height, 224)
        XCTAssertEqual(window.frame.size, NSSize(width: 480, height: 224))
        window.close()
    }
}
