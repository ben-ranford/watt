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
    func testExactCopyAndFixture() throws {
        XCTAssertEqual(OfferComponentReadingsView.title, "CPU and GPU readings")
        XCTAssertEqual(OfferComponentReadingsView.message, "The helper is optional. It adds CPU and GPU readings.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableTitle, "CPU and GPU readings aren’t available")
        XCTAssertEqual(OfferComponentReadingsView.installMessage, "The helper isn’t installed. Installing it asks for your password.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableMessage(for: .missingBundle),
                       "This copy of Watt? doesn’t include the helper. Everything else still works.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableMessage(for: .signingRequired),
                       "This copy of Watt? can’t turn the helper on. Everything else still works.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableMessage(for: .verificationFailed),
                       "Watt? couldn’t check the helper. Reinstall Watt? and try again.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableMessage(for: .configurationFailed),
                       "Watt? couldn’t set up the helper. Quit and open it again.")
        XCTAssertEqual(OfferComponentReadingsView.unavailableMessage(for: .installationRequired),
                       "The helper isn’t installed. Everything else still works.")
        XCTAssertEqual(OfferComponentReadingsView.Action.allCases.count, 2)
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
        for token in ["Image(\"WattAppIcon\")", ".buttonStyle(.bordered)", ".buttonStyle(.borderedProminent)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["Form {", "LabeledContent", "What it reads", "RoundedRectangle",
                      ".background(", ".overlay(", ".position(", ".offset("] {
            XCTAssertFalse(source.contains(token), token)
        }
        let lines = source
            .replacingOccurrences(of: #"(?s)/\*.*?\*/|//[^\n]*"#, with: "",
                                  options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.filter { !$0.isWhitespace } }
        let layout = lines.joined()
        for forbidden in [".padding(-", ",-", ".frame(height:", ".frame(minHeight:",
                          ".frame(maxHeight:", ".frame(idealHeight:", ".listRowInsets(",
                          ".contentMargins("] {
            XCTAssertFalse(layout.contains(forbidden), forbidden)
        }
        let insets = lines.indices.filter { lines[$0] == ".padding(.horizontal,32)" }
        XCTAssertEqual(insets.count, 2, "Only the header and actions receive a 32pt inset")
        var depth = 0
        let depths = lines.map { line in
            let current = depth
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            return current
        }
        XCTAssertEqual(depths[insets[0]], depths[insets[1]],
                       "Header and actions share the same inset depth")
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
            XCTAssertEqual(restored.onboarding.checkpoint, action == .notNow ? .picker : .approval)
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

    func testMissingHelperCannotEnterApprovalAndSkipStillReachesTheReading() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        preferences.displayMode = .components
        XCTAssertEqual(ChooseMenuReadingView.unavailableModes(reading: .sampleCharging,
                                                                 helperAvailable: false), [.components])
        XCTAssertEqual(ChooseMenuReadingView.options(reading: .sampleCharging,
                                                      helperAvailable: false).last?.description,
                       "CPU and GPU readings aren’t available in this copy.")
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: .sampleCharging,
                                               helperAvailable: false)
        XCTAssertEqual(preferences.displayMode, .draw)
        ChooseMenuReadingView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertFalse(preferences.onboarding.helperOptIn)

        for checkpoint: OnboardingCheckpoint in [.helperOffer, .approval, .preview] {
            preferences.onboarding.checkpoint = checkpoint // Existing persisted helper checkpoints.
            preferences.onboarding.helperOptIn = true
            OfferComponentReadingsView.perform(.turnOn, preferences: preferences, helperAvailable: false)
            XCTAssertEqual(preferences.onboarding.checkpoint, checkpoint)
            OfferComponentReadingsView.perform(.notNow, preferences: preferences, helperAvailable: false)
            XCTAssertEqual(preferences.onboarding.checkpoint, checkpoint == .helperOffer ? .picker : .allSet)
            XCTAssertFalse(preferences.onboarding.helperOptIn)
        }
    }

    func testSkipLeavesComponentsUnavailableWithAWayBackToInstall() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .helperOffer
        preferences.displayMode = .components
        OfferComponentReadingsView.perform(.notNow, preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertFalse(preferences.onboarding.helperOptIn)
        XCTAssertEqual(ChooseMenuReadingView.unavailableModes(reading: .sampleCharging, helperAvailable: false), [.components])
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: .sampleCharging, helperAvailable: false)
        XCTAssertEqual(preferences.displayMode, .draw)
        ChooseMenuReadingView.back(preferences: preferences, returnToInstall: true)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .helperOffer)
        OfferComponentReadingsView.perform(.notNow, preferences: preferences)
        ChooseMenuReadingView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertFalse(preferences.onboarding.completed)
    }

    func testInstalledHelperMakesComponentsSelectableThenContinues() {
        let connected = PreferencesStore(storage: InMemoryStorage())
        connected.onboarding.checkpoint = .helperOffer
        OfferComponentReadingsView.finishInstall(preferences: connected, helperOn: true, requiresApproval: false)
        XCTAssertEqual(connected.onboarding.checkpoint, .picker)
        XCTAssertTrue(connected.onboarding.helperOptIn)
        XCTAssertFalse(connected.onboarding.completed)
        XCTAssertTrue(ChooseMenuReadingView.unavailableModes(reading: .sampleCharging, helperAvailable: true).isEmpty)
        connected.displayMode = .components
        ChooseMenuReadingView.prepareSelection(preferences: connected, reading: .sampleCharging, helperAvailable: true)
        XCTAssertEqual(connected.displayMode, .components)
        ChooseMenuReadingView.advance(preferences: connected, helperOn: true)
        XCTAssertEqual(connected.onboarding.checkpoint, .preview)

        let pending = PreferencesStore(storage: InMemoryStorage())
        pending.onboarding.checkpoint = .helperOffer
        OfferComponentReadingsView.finishInstall(preferences: pending, helperOn: false, requiresApproval: true)
        XCTAssertEqual(pending.onboarding.checkpoint, .picker)
        XCTAssertTrue(ChooseMenuReadingView.unavailableModes(reading: .sampleCharging, helperAvailable: true).isEmpty)
        ChooseMenuReadingView.advance(preferences: pending, requiresApproval: true)
        XCTAssertEqual(pending.onboarding.checkpoint, .approval)
        XCTAssertFalse(pending.onboarding.completed)

        let unchanged = PreferencesStore(storage: InMemoryStorage())
        unchanged.onboarding.checkpoint = .helperOffer
        OfferComponentReadingsView.finishInstall(preferences: unchanged, helperOn: false, requiresApproval: false)
        XCTAssertEqual(unchanged.onboarding.checkpoint, .helperOffer)
        XCTAssertTrue(unchanged.onboarding.helperOptIn)
        unchanged.onboarding.checkpoint = .picker
        OfferComponentReadingsView.finishInstall(preferences: unchanged, helperOn: true, requiresApproval: false)
        XCTAssertEqual(unchanged.onboarding.checkpoint, .picker)
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
        // Text length can shift the fitted height a little. Don't pin a row height.
        XCTAssertLessThanOrEqual(window.contentView!.fittingSize.height, 424)
        window.close()
        XCTAssertEqual(preferences.onboarding, initial)
    }
    #endif
}
