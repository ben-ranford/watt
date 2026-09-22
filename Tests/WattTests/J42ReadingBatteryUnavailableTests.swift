import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
@testable import WattFixtures
#endif
@testable import Watt

@MainActor
final class J42ReadingBatteryUnavailableTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactCopyOptionsAndCapabilities() throws {
        let reading = J42FixtureLaunch.reading
        try reading.validate()
        XCTAssertEqual(ChooseMenuReadingView.title, "Pick one number for the menu bar")
        XCTAssertEqual(ChooseMenuReadingView.Variant(reading: reading).message,
                       "No battery here, so it’s Draw or Components.")
        let options = ChooseMenuReadingView.options(reading: reading)
        XCTAssertEqual(options.map(\.mode), [.draw, .components, .delta, .charger])
        XCTAssertEqual(options.map(\.description), [
            "What your Mac uses right now. 38.2 W",
            "CPU, GPU and the rest. Needs the helper — next step.",
            "Needs a battery. This Mac doesn’t have one.",
            "Needs a battery. This Mac doesn’t have one."
        ])
        XCTAssertEqual(ChooseMenuReadingView.unavailableModes(reading: reading), [.components, .delta, .charger])
        XCTAssertNil(reading.value(for: .delta))
        XCTAssertNil(reading.value(for: .charger))
        XCTAssertTrue(reading.components.isEmpty)
        XCTAssertEqual(reading.capabilities.components, .permissionRequired)
        XCTAssertEqual(ChooseMenuReadingView.Variant(reading: .unavailable), .standard)
        XCTAssertEqual(ChooseMenuReadingView.options(reading: .sampleCharging).first?.mode, .delta)
    }

    func testSelectionGuardsAndHelperGate() {
        var selection = WattDisplayMode.draw
        let picker = ReadingPicker(selection: Binding(get: { selection }, set: { selection = $0 }),
                                   unavailableModes: ChooseMenuReadingView.unavailableModes(reading: J42FixtureLaunch.reading),
                                   options: ChooseMenuReadingView.options(reading: J42FixtureLaunch.reading))
        for mode in [WattDisplayMode.delta, .charger, .components, .iconOnly] {
            picker.availableSelection.wrappedValue = mode
            XCTAssertEqual(selection, .draw)
        }
        let connected = PowerReading(mode: .systemDraw, watts: nil, batteryState: .noBattery,
                                     capabilities: .init(battery: .unsupported, charger: .unsupported,
                                                         systemDraw: .available, components: .available),
                                     source: .helper, systemWatts: 38.2)
        XCTAssertEqual(ChooseMenuReadingView.unavailableModes(reading: connected), [.delta, .charger])
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        preferences.displayMode = .components
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: connected)
        XCTAssertEqual(preferences.displayMode, .components)
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: J42FixtureLaunch.reading)
        XCTAssertEqual(preferences.displayMode, .draw)
    }

    func testBackContinueAndReloadPreservePreferences() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.onboarding.checkpoint = .picker
        preferences.onboarding.helperOptIn = false
        preferences.openAtLogin = false
        preferences.showSymbol = false
        ChooseMenuReadingView.prepareSelection(preferences: preferences, reading: J42FixtureLaunch.reading)
        XCTAssertEqual(PreferencesStore(storage: storage).displayMode, .draw)
        ChooseMenuReadingView.back(preferences: preferences)
        XCTAssertEqual(PreferencesStore(storage: storage).onboarding.checkpoint, .welcome)
        OnboardingFlowView.continueWelcome(preferences: preferences)
        ChooseMenuReadingView.advance(preferences: preferences)
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.onboarding.checkpoint, .helperOffer)
        XCTAssertEqual(restored.displayMode, .draw)
        XCTAssertFalse(restored.onboarding.helperOptIn)
        XCTAssertFalse(restored.onboarding.completed)
        XCTAssertFalse(restored.openAtLogin)
        XCTAssertFalse(restored.showSymbol)
        ChooseMenuReadingView.back(preferences: preferences)
        ChooseMenuReadingView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding, restored.onboarding)
    }

    func testFixtureIsolationAndNativeWindow() throws {
        let selection = try ScenarioRegistry.resolve("J4.2", variant: "base")
        XCTAssertEqual(selection.story.node, "30:2576")
        XCTAssertNoThrow(try selection.story.requireRenderTarget())
        XCTAssertEqual(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J4.2/base"])?
            .smokeLaunchArguments(), ["--watt-fixture", "J4.2/base"])
        let invalid = FixtureSelection(story: selection.story, variant: "unknown")
        XCTAssertThrowsError(try FixtureLaunchSelection.story(invalid).smokeLaunchArguments())
        XCTAssertThrowsError(try ScenarioRegistry.resolve("J4.2", variant: "unknown"))
        XCTAssertNil(try FixtureLaunchSelection.parse(["Watt"]))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J42FixtureLaunch.requested)
        #endif
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let unrelated = PreferencesStore(storage: InMemoryStorage())
        let window = J42FixtureLaunch.makeWindow(preferences: preferences)
        XCTAssertEqual(preferences.displayMode, .draw)
        XCTAssertEqual(unrelated.displayMode, .delta)
        XCTAssertEqual(unrelated.onboarding.checkpoint, .welcome)
        XCTAssertEqual(window.appearance?.name, .darkAqua)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertNotNil(window.standardWindowButton(.closeButton))
        window.close()
        XCTAssertEqual(preferences.onboarding.checkpoint, .picker)
    }
    #endif

    func testNativeStylingContract() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let picker = try String(contentsOf: root.appendingPathComponent("DesignSystem/Components/ReadingPicker.swift"))
        XCTAssertTrue(picker.contains(".pickerStyle(.radioGroup)"))
        XCTAssertTrue(picker.contains(".disabled(unavailableModes.contains(mode))"))
        let flow = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"))
        let screen = flow.components(separatedBy: "struct ChooseMenuReadingView")[1].components(separatedBy: "/// J1.3")[0]
        for token in [".font(WattTypography.title)", "ReadingPicker(", "WattActionButton(title: \"Back\")",
                      "WattActionButton(title: \"Continue\", style: .prominent)", ".keyboardShortcut(.defaultAction)"] {
            XCTAssertTrue(screen.contains(token), token)
        }
        for token in ["Circle(", "RoundedRectangle", ".background(", ".tint(", "Font.custom"] {
            XCTAssertFalse(screen.contains(token), token)
        }
    }
}
