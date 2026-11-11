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
        XCTAssertEqual(OfferComponentReadingsView.message, "Watt? uses a helper to read Apple’s CPU/GPU power estimates. macOS requires administrator approval. Both estimates appear only when both are available. Display, SSD and Other are unavailable.")
        XCTAssertEqual(OfferComponentReadingsView.Action.allCases.count, 2)
        XCTAssertEqual(OfferComponentReadingsView.facts.map(\.label), ["What it reads", "Network", "Remove it"])
        XCTAssertEqual(OfferComponentReadingsView.facts.map(\.value), ["CPU/GPU power estimates", "Never", "Any time, in Settings"])
        let selection = try ScenarioRegistry.resolve("J1.3", variant: "base")
        XCTAssertEqual(selection.stableID, "J1.3/base")
        XCTAssertEqual(selection.story.node, "J1.3")
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
        let lines = source
            .replacingOccurrences(of: #"(?s)/\*.*?\*/|//[^\n]*"#, with: "",
                                  options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.filter { !$0.isWhitespace } }
        let formStart = try XCTUnwrap(lines.firstIndex(of: "Form{"))
        let actionsStart = try XCTUnwrap(lines.indices.first {
            $0 > formStart && lines[$0] == "HStack{"
        })
        let form = lines[formStart..<actionsStart].joined()
        XCTAssertGreaterThan(WattSpacing.md, 0)
        XCTAssertTrue(form.contains(".formStyle(.grouped)"))
        XCTAssertTrue(form.contains(".padding(.horizontal,WattSpacing.md)"))
        XCTAssertFalse(form.contains(".frame("), "Form and rows retain intrinsic native sizing")
        let layout = lines.joined()
        for forbidden in [".padding(-", ",-", ".frame(height:", ".frame(minHeight:",
                          ".frame(maxHeight:", ".frame(idealHeight:", ".listRowInsets(",
                          ".contentMargins("] {
            XCTAssertFalse(layout.contains(forbidden), forbidden)
        }
        let insets = lines.indices.filter { lines[$0] == ".padding(.horizontal,32)" }
        XCTAssertEqual(insets.count, 2, "Only the header and actions receive a 32pt inset")
        XCTAssertEqual(insets.filter { $0 < formStart }.count, 1,
                       "Header inset must not constrain the sibling Form")
        XCTAssertEqual(insets.filter { $0 > actionsStart }.count, 1,
                       "Inset the action row, not the whole surface")
        var depth = 0
        let depths = lines.map { line in
            let current = depth
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            return current
        }
        XCTAssertEqual(depths[formStart], depths[actionsStart])
        for inset in insets {
            XCTAssertEqual(depths[inset], depths[formStart],
                           "32pt insets belong to Form siblings, not the shared outer container")
        }
        let icon = NSImage(contentsOf: root.appendingPathComponent(
            "Resources/Assets.xcassets/WattAppIcon.imageset/watt-app-icon.png"))
        XCTAssertEqual(icon?.size, NSSize(width: 1024, height: 1024))
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

    func testMissingHelperCannotEnterApprovalAndPickerSkipsOffer() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        preferences.displayMode = .components
        XCTAssertEqual(ChooseMenuReadingView.unavailableModes(reading: .sampleCharging,
                                                                 helperAvailable: false), [.components])
        XCTAssertEqual(ChooseMenuReadingView.options(reading: .sampleCharging,
                                                      helperAvailable: false).last?.description,
                       "Component readings are unavailable in this build.")
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: .sampleCharging,
                                               helperAvailable: false)
        XCTAssertEqual(preferences.displayMode, .draw)
        ChooseMenuReadingView.advance(preferences: preferences, helperAvailable: false)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertFalse(preferences.onboarding.helperOptIn)

        for checkpoint: OnboardingCheckpoint in [.helperOffer, .approval, .preview] {
            preferences.onboarding.checkpoint = checkpoint // Existing persisted helper checkpoints.
            preferences.onboarding.helperOptIn = true
            OfferComponentReadingsView.perform(.turnOn, preferences: preferences, helperAvailable: false)
            XCTAssertEqual(preferences.onboarding.checkpoint, checkpoint)
            OfferComponentReadingsView.perform(.notNow, preferences: preferences, helperAvailable: false)
            XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
            XCTAssertFalse(preferences.onboarding.helperOptIn)
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
        // The grouped form must report its rows. A short fitting size is what
        // clipped the facts behind the buttons in the production setup window.
        let fittedHeight = window.contentView!.fittingSize.height
        XCTAssertGreaterThan(fittedHeight, 400)
        XCTAssertLessThan(fittedHeight, 720)
        window.close()
        XCTAssertEqual(preferences.onboarding, initial)
    }
    #endif
}
