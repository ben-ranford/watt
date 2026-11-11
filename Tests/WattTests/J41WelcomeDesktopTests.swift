import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J41WelcomeDesktopTests: XCTestCase {
    func testExactCopyAssetAndDefaultVariant() {
        XCTAssertEqual(WelcomeView.title, "Know your watts")
        XCTAssertEqual(WelcomeView.Variant.desktop.message,
                       "Watt? sits in your menu bar and shows what your Mac draws. Nothing more.")
        XCTAssertEqual(WelcomeView.Variant.standard.message,
                       "Watt? sits in your menu bar and shows what your Mac draws and what it’s charging with. Nothing more.")
        XCTAssertEqual(OnboardingFlowView().welcomeVariant, .standard)
        XCTAssertEqual(WelcomeView.desktopIconAsset, "WattAppIcon")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(NSImage(contentsOf: root.appendingPathComponent(
            "Resources/Assets.xcassets/WattAppIcon.imageset/watt-app-icon.png"))?.size,
                       NSSize(width: 1024, height: 1024))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixtureRegistryAndIsolation() throws {
        let selection = try ScenarioRegistry.resolve("J4.1", variant: "base")
        XCTAssertEqual(selection.story.node, "J4.1")
        XCTAssertNoThrow(try selection.story.requireRenderTarget())
        XCTAssertEqual(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J4.1/base"])?
            .smokeLaunchArguments(), ["--watt-fixture", "J4.1/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J4.1", variant: "unknown"))
        XCTAssertNil(try FixtureLaunchSelection.parse(["Watt"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J41FixtureLaunch.requested)
        #endif
    }
    #endif

    func testContinuePersistsPickerWithoutChangingOtherPreferences() {
        for _ in WelcomeView.Variant.allCases {
            let storage = InMemoryStorage()
            let preferences = PreferencesStore(storage: storage)
            preferences.displayMode = .draw
            preferences.onboarding.helperOptIn = true
            OnboardingFlowView.continueWelcome(preferences: preferences)
            let restored = PreferencesStore(storage: storage)
            XCTAssertEqual(restored.onboarding.checkpoint, .picker)
            XCTAssertFalse(restored.onboarding.completed)
            XCTAssertTrue(restored.onboarding.helperOptIn)
            XCTAssertEqual(restored.displayMode, .draw)
            ChooseMenuReadingView.back(preferences: preferences)
            XCTAssertEqual(preferences.onboarding.checkpoint, .welcome)
        }
    }

    func testStaleContinueDoesNotResetProgress() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .allSet
        let before = preferences.onboarding
        OnboardingFlowView.continueWelcome(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, before)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testNativeWelcomeCloseDefersSetup() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let window = J41FixtureLaunch.makeWindow(preferences: preferences)
        _ = window.contentView?.fittingSize
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        XCTAssertTrue(window.styleMask.contains(.titled))
        window.performClose(nil)
        XCTAssertEqual(preferences.onboarding.checkpoint, .welcomeClosed)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertNotNil(preferences.onboarding.deferredSetupID)
    }
    #endif

    func testNativeDefaultActionAndEscapeWiring() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(
            "Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains(".onExitCommand { close() }"))
        XCTAssertTrue(source.contains("if let closeAction { closeAction() } else { dismiss() }"))
        let welcome = source.components(separatedBy: "struct WelcomeView")[1]
            .components(separatedBy: "struct ChooseMenuReadingView")[0]
        for token in ["Button(\"Continue\"", ".buttonStyle(.borderedProminent)",
                      ".keyboardShortcut(.defaultAction)", "Image(Self.desktopIconAsset)"] {
            XCTAssertTrue(welcome.contains(token), token)
        }
        for token in ["RoundedRectangle", ".background(", ".preferredColorScheme", ".tint("] {
            XCTAssertFalse(welcome.contains(token), token)
        }
    }
}
