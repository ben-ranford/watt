#if DEBUG || SWIFT_PACKAGE
import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
@testable import Watt
#else
@testable import Watt
#endif

@MainActor
final class J111VoiceOverOrderTests: XCTestCase {
    func testRegistryAndLaunchContractAreExactBaseOnly() throws {
        let fixture = try ScenarioRegistry.resolve("J11.1")
        XCTAssertEqual(fixture.story.node, "36:5057")
        XCTAssertEqual(fixture.story.frame, "11.1 Status item + panel — VoiceOver order")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J11.1/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J11.1/other"]))

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let launch = try String(contentsOf: root.appendingPathComponent("App/J111FixtureLaunch.swift"), encoding: .utf8)
        XCTAssertTrue(launch.contains("selection.stableID == \"J11.1/base\""))
        XCTAssertTrue(launch.contains("componentReadings = true"))
        XCTAssertTrue(launch.contains("NSAppearance.Name.darkAqua"))
        for forbidden in ["NSWindow(", "NSVisualEffectView(", ".cacheDisplay(", "addSubview(", "UserDefaults"] {
            XCTAssertFalse(launch.contains(forbidden), forbidden)
        }
    }

    func testStatusItemLabelContainsStateReadingAndHintWithoutNestedValue() {
        let preferences = J111FixtureLaunch.makePreferences()
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences)
        XCTAssertEqual(label.accessibilityAnnouncement, "Watt?, charging, plus 42.1 watts, menu extra.")
        XCTAssertEqual(MenuBarStatusLabel.accessibilityHint, "Click for details. VO-Shift-M for options.")
        XCTAssertEqual(label.accessibilityStateKey, "charging|charging|fresh|available|available")
    }

    func testCombinedPanelSummaryUsesDesignedVoiceOverPhrase() {
        let model = StatusPanelModel(reading: .sampleCharging, chargerDescription: "96 W USB-C charger")
        XCTAssertEqual(model.voiceOverSummary, "Charging, +42.1 W, Into battery · 64% · full in 38 min")
        XCTAssertEqual(model.accessibilitySummary, "Charging, +42.1 W, 64% · full in about 38 min")
    }

    func testPowerAndComponentRowsPreserveLabelValueOrderAndSubtitles() {
        let model = StatusPanelModel(reading: .sampleCharging, chargerDescription: "96 W USB-C charger")
        XCTAssertEqual(model.accessibilityRows.map(\.label), ["Charger input", "System draw", "Battery", "CPU", "GPU", "Display", "Other"])
        XCTAssertEqual(model.accessibilityRows.map(\.spokenValue), [
            "65.0 W, 96 W USB-C charger", "22.9 W", "+42.1 W", "9.8 W", "4.1 W", "5.2 W", "3.8 W"
        ])
    }

    func testNativeHeadingsButtonsAndStylingContracts() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"), encoding: .utf8)
        for token in ["Form {", "LabeledContent", "Text(\"Components\")", ".accessibilityAddTraits(.isHeader)",
                      ".keyboardShortcut(\",\", modifiers: .command)", ".keyboardShortcut(\"q\", modifiers: .command)",
                      ".monospacedDigit()"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for forbidden in ["RoundedRectangle", "NSVisualEffectView", ".tint(", ".shadow(", "preferredColorScheme"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testAnnouncementGateChangesOnlyForStateOrThirtySeconds() {
        var gate = MenuBarAccessibilityAnnouncementGate()
        let initial = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(gate.shouldAnnounce(stateKey: "charging", now: initial))
        XCTAssertFalse(gate.shouldAnnounce(stateKey: "charging", now: initial.addingTimeInterval(1)))
        XCTAssertTrue(gate.shouldAnnounce(stateKey: "full", now: initial.addingTimeInterval(2)))
        XCTAssertFalse(gate.shouldAnnounce(stateKey: "full", now: initial.addingTimeInterval(3)))
        XCTAssertTrue(gate.shouldAnnounce(stateKey: "full", now: initial.addingTimeInterval(33)))
    }

    func testAppKitBridgeKeepsOneNativeAccessibilityLabel() {
        let preferences = J111FixtureLaunch.makePreferences()
        let button = NSStatusBarButton(frame: NSRect(x: 0, y: 0, width: 96, height: 24))
        MenuBarStatusAccessibility.apply(to: button, label: MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences))
        XCTAssertEqual(button.accessibilityLabel(), "Watt?, charging, plus 42.1 watts, menu extra.")
        XCTAssertEqual(button.accessibilityHelp(), "Click for details. VO-Shift-M for options.")
        XCTAssertNil(button.accessibilityValue())
    }
}
#endif
