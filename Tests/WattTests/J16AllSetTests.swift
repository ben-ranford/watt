import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J16AllSetTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactCopyAndFixture() throws {
        XCTAssertEqual(AllSetView.title, "That’s it")
        XCTAssertEqual(AllSetView.message, "Watt? lives in your menu bar. Click it for the detail. Right-click to change the number.")
        let fixture = try ScenarioRegistry.resolve("J1.6")
        XCTAssertEqual(fixture.story.node, "J1.6")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J1.6/base"])
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J1.6", variant: "unavailable"))
    }
    #endif

    func testDonePersistsAndDismissesBeforeOpeningCoachMarkOnce() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding = .init(checkpoint: .allSet, helperOptIn: true)
        preferences.displayMode = .charger
        preferences.openAtLogin = false
        let router = AppRouter()
        var events: [String] = []
        router.present = { destination in
            XCTAssertEqual(destination, .coachMark)
            events.append("coachMark")
        }
        AllSetView.finish(preferences: preferences, router: router) { events.append("dismiss") }
        AllSetView.finish(preferences: preferences, router: router) { events.append("duplicate") }
        XCTAssertEqual(events, ["dismiss", "coachMark"])
        let restored = PreferencesStore(storage: storage)
        XCTAssertTrue(restored.onboarding.completed)
        XCTAssertEqual(restored.onboarding.checkpoint, .coachMark)
        XCTAssertTrue(restored.onboarding.helperOptIn)
        XCTAssertEqual(restored.displayMode, .charger)
        XCTAssertFalse(restored.openAtLogin)
    }

    func testInvalidCheckpointsCannotFinish() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        router.present = { _ in XCTFail("Must not route") }
        for checkpoint in [OnboardingCheckpoint.welcome, .picker, .helperOffer, .approval, .preview, .coachMark] {
            preferences.onboarding.checkpoint = checkpoint
            let previous = preferences.onboarding
            AllSetView.finish(preferences: preferences, router: router) { XCTFail("Must not dismiss") }
            XCTAssertEqual(preferences.onboarding, previous)
        }
    }

    func testFailedPersistenceStaysOnAllSetAndCanRetry() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .allSet
        let router = AppRouter()
        var routed = false
        router.present = { _ in routed = true }
        storage.failWrites = true
        AllSetView.finish(preferences: preferences, router: router) { XCTFail("Must not dismiss") }
        XCTAssertFalse(routed)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertEqual(preferences.persistenceFailure, .persistence)
        storage.failWrites = false
        AllSetView.finish(preferences: preferences, router: router) {}
        XCTAssertTrue(routed)
        XCTAssertNil(preferences.persistenceFailure)
    }

    func testLoginPreferenceAndPriorNavigationRemainIndependent() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        XCTAssertFalse(preferences.openAtLogin)
        preferences.openAtLogin = false
        preferences.onboarding.checkpoint = .preview
        ComponentPreviewView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertFalse(PreferencesStore(storage: storage).openAtLogin)
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.back(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .welcome)
        XCTAssertFalse(preferences.openAtLogin)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testNativeWindowAndControlContract() throws {
        let window = J16FixtureLaunch.makeWindow()
        defer { window.close() }
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.contentView!.fittingSize.width, WattSpacing.onboardingWidth)
        XCTAssertGreaterThan(window.contentView!.fittingSize.height, 0)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains(".onExitCommand { close() }"))
        let view = source.components(separatedBy: "struct AllSetView")[1].components(separatedBy: "/// J1.5")[0]
        for token in ["Form {", "Section {", "Toggle(\"Open at login\", isOn: $preferences.openAtLogin)", ".toggleStyle(.switch)", ".buttonStyle(.borderedProminent)", ".keyboardShortcut(.defaultAction)"] {
            XCTAssertTrue(view.contains(token), token)
        }
        for token in ["Canvas", "RoundedRectangle", "Path {", ".overlay(", ".background("] {
            XCTAssertFalse(view.contains(token), token)
        }
    }
    #endif
}
