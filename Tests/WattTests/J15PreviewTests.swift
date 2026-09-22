import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J15PreviewTests: XCTestCase {
    func testExactSuccessCopy() {
        XCTAssertEqual(ComponentPreviewView.title, "Helper’s on")
        XCTAssertEqual(ComponentPreviewView.message, "Here’s where the power is going right now.")
    }

    func testExactFixtureReadingsAndUnavailableValues() throws {
        XCTAssertEqual(ComponentPreviewView.componentNames.map {
            ComponentPreviewView.value(for: $0, reading: .sampleCharging)
        }, ["9.8 W", "4.1 W", "5.2 W"])
        XCTAssertEqual(ComponentPreviewView.value(for: "CPU", reading: .unavailable), "—")
        XCTAssertEqual(ComponentPreviewView.value(for: "Missing", reading: .sampleCharging), "—")
        let fixture = try ScenarioRegistry.resolve("J1.5")
        XCTAssertEqual(fixture.story.node, "28:1598")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J1.5/base"])
        XCTAssertEqual(ComponentPreviewView.componentNames, ["CPU", "GPU", "Display"])
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J1.5", variant: "unavailable"))
    }

    func testUnavailableTelemetryNeverShowsSampleValues() {
        for capability in [Capability.unsupported, .permissionRequired, .disconnected, .unknown] {
            let reading = PowerReading(mode: .perComponent, watts: nil,
                components: PowerReading.sampleCharging.components,
                capabilities: .init(components: capability), source: .helper)
            XCTAssertEqual(ComponentPreviewView.value(for: "CPU", reading: reading), "—")
        }
        for freshness in [ReadingFreshness.stale, .unavailable] {
            let reading = PowerReading(mode: .perComponent, watts: nil,
                components: PowerReading.sampleCharging.components,
                capabilities: .init(components: .available), freshness: freshness, source: .helper)
            XCTAssertEqual(ComponentPreviewView.value(for: "CPU", reading: reading), "—")
        }
    }

    func testContinueOnlyChangesPreviewCheckpoint() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let initial = preferences.onboarding
        ComponentPreviewView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, initial)
        preferences.onboarding.checkpoint = .preview
        var expected = preferences.onboarding
        expected.checkpoint = .allSet
        ComponentPreviewView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, expected)
        XCTAssertFalse(preferences.onboarding.completed)
        XCTAssertFalse(preferences.onboarding.helperOptIn)
        ComponentPreviewView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, expected)
    }

    func testNativeWindowAndControls() throws {
        let window = J15FixtureLaunch.makeWindow()
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.appearance?.name, .aqua)
        XCTAssertEqual(window.contentView!.fittingSize.width, 480)
        XCTAssertGreaterThan(window.contentView!.fittingSize.height, 0)
        window.close()
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("checkpoint == .preview {\n                ComponentPreviewView()"))
        let view = source.components(separatedBy: "struct ComponentPreviewView")[1]
        for token in ["Form {", "Section {", "LabeledContent(", "Image(systemName: \"checkmark.circle.fill\")", ".foregroundStyle(.green)", "Text(Self.title)", "Text(Self.message)", ".accessibilityAddTraits(.isHeader)", ".buttonStyle(.borderedProminent)"] {
            XCTAssertTrue(view.contains(token), token)
        }
        for token in ["Image(\"WattAppIcon\")", "Canvas", "Path {", "RoundedRectangle", ".overlay(", "helperOptIn =", "completed ="] {
            XCTAssertFalse(view.contains(token), token)
        }
    }
}
