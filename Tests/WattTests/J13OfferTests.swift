import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J13OfferTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactFactsAndFixture() throws {
        XCTAssertEqual(OfferComponentReadingsView.title, "See where the power goes")
        XCTAssertEqual(OfferComponentReadingsView.message, "Watt? needs a small helper to read CPU, GPU and display power. macOS asks you to approve it once.")
        XCTAssertEqual(OfferComponentReadingsView.Action.allCases.count, 2)
        XCTAssertEqual(OfferComponentReadingsView.facts.map(\.label), ["What it reads", "Network", "Remove it"])
        XCTAssertEqual(OfferComponentReadingsView.facts.map(\.value), ["Power sensors only", "Never", "Any time, in Settings"])
        let selection = try ScenarioRegistry.resolve("J1.3", variant: "base")
        XCTAssertEqual(selection.stableID, "J1.3/base")
        XCTAssertEqual(selection.story.node, "27:1584")
        XCTAssertNoThrow(try selection.story.requireRenderTarget())
    }
    #endif

    func testOfferUsesProvidedAssetAndNativeControls() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let flow = try String(contentsOf: root.appendingPathComponent(
            "Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        let start = try XCTUnwrap(flow.range(of: "struct OfferComponentReadingsView: View"))
        let end = try XCTUnwrap(flow.range(of: "struct WaitingForApprovalView: View",
                                           range: start.upperBound..<flow.endIndex))
        let source = flow[start.lowerBound..<end.lowerBound]
        for token in ["Image(\"WattAppIcon\")", "Form {", "LabeledContent", ".formStyle(.grouped)",
                      ".buttonStyle(.bordered)", ".buttonStyle(.borderedProminent)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", ".background(", ".overlay(", ".position(", ".offset("] {
            XCTAssertFalse(source.contains(token), token)
        }
        let icon = NSImage(contentsOf: root.appendingPathComponent(
            "Resources/Assets.xcassets/WattAppIcon.imageset/watt-app-icon.png"))
        XCTAssertEqual(icon?.size, NSSize(width: 256, height: 256))
    }

    func testActionsPersistIntentNotApprovalOrCompletion() {
        for action in OfferComponentReadingsView.Action.allCases {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.displayMode = .components
            preferences.onboarding.helperOptIn = true
            preferences.onboarding.checkpoint = .helperOffer
            OfferComponentReadingsView.perform(action, preferences: preferences)
            let restored = PreferencesStore(storage: storage)
            XCTAssertEqual(restored.onboarding.checkpoint, action == .notNow ? .allSet : .approval)
            XCTAssertEqual(restored.onboarding.helperOptIn, action == .turnOn)
            XCTAssertFalse(restored.onboarding.completed)
            XCTAssertEqual(restored.displayMode, .components)
        }
    }

    func testStaleActionsDoNotChangeOtherRoutes() {
        for checkpoint: OnboardingCheckpoint in [.welcome, .picker, .approval, .preview, .allSet, .coachMark] {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.onboarding.checkpoint = checkpoint
            let initial = preferences.onboarding
            for action in OfferComponentReadingsView.Action.allCases {
                OfferComponentReadingsView.perform(action, preferences: preferences)
                XCTAssertEqual(preferences.onboarding, initial)
            }
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testClosingNativeWindowPreservesOfferForReopen() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .helperOffer
        let initial = preferences.onboarding
        let window = J13FixtureLaunch.makeWindow()
        window.contentView = NSHostingView(rootView: OnboardingFlowView()
            .environmentObject(preferences).environmentObject(AppRouter()))
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        XCTAssertEqual(window.frame.size, NSSize(width: 480, height: 412))
        // DESIGN.md leaves grouped Form intrinsic metrics to macOS; allow narrow
        // OS-owned fitting-size variation without forcing row/form heights.
        XCTAssertLessThanOrEqual(window.contentView!.fittingSize.height, 424)
        window.close()
        XCTAssertEqual(preferences.onboarding, initial)
    }
    #endif
}
