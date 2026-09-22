#if DEBUG || SWIFT_PACKAGE
import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J112SettingsTests: XCTestCase {
    func testRegistryAndLaunchContractAreExactBaseOnly() throws {
        let fixture = try ScenarioRegistry.resolve("J11.2")
        XCTAssertEqual(fixture.story.node, "36:5186")
        XCTAssertEqual(fixture.story.frame, "11.2 Settings — control labels & keyboard")
        XCTAssertEqual(fixture.story.expectedScene, "settings")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J11.2/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["Watt", "--watt-fixture", "J11.2/other"]))

        #if !SWIFT_PACKAGE
        XCTAssertTrue(J112FixtureLaunch.matches(arguments: ["Watt", "--watt-fixture", "J11.2/base"]))
        #endif
    }

    func testFixtureValuesMatchEveryDisplayedControl() {
        let preferences = J112FixtureLaunch.makePreferences()
        XCTAssertEqual(preferences.displayMode, .delta)
        XCTAssertTrue(preferences.showSymbol)
        XCTAssertEqual(preferences.precision, .decimal)
        XCTAssertEqual(preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(preferences.updateInterval, "Every 2 seconds")
        XCTAssertTrue(preferences.smoothReadings)
        XCTAssertTrue(preferences.componentReadings)
        XCTAssertTrue(preferences.chargerNotification)
        XCTAssertFalse(preferences.fullyChargedNotification)
        XCTAssertTrue(preferences.openAtLogin)
        XCTAssertTrue(preferences.checkForUpdatesAutomatically)
    }

    func testNativeRowsExposeExactLabelsValuesAndHelpText() throws {
        XCTAssertEqual(SettingsRootView.fullSettingsComponentSubtitle,
                       "In Components mode. Two fit; more crowd the menu bar.")
        let source = try source("Features/Settings/Views/SettingsRootView.swift")
        for text in [
            "Text(\"Menu Bar\")", "Picker(\"Show\"", "Toggle(\"Show symbol\"",
            "Picker(\"Precision\"", "Text(\"Components\")", "Section(\"Readings\")",
            "Picker(\"Update\"", "Text(\"Faster uses a little more energy.\")",
            "Text(\"Smooth readings\")",
            "On — averages the last 5 seconds, so the number doesn’t jump.",
            "Text(\"Component Readings\")", "Text(Self.statusTitle)", "Text(Self.helperTitle)",
            "Reads power sensors only. No network, nothing leaves this Mac.",
            "Section(\"Notifications\")", "Text(\"Charger can’t keep up\")",
            "When your Mac draws more than the charger gives for 5 minutes.",
            "Toggle(\"Fully charged\"", "Section(\"General\")", "Toggle(\"Open at login\"",
            "Toggle(\"Check for updates automatically\"", "Text(\"Uninstall Watt?\")",
            "Removes the helper and your settings, then moves Watt? to the Trash.",
            "LabeledContent(\"Version\", value: version)"
        ] {
            XCTAssertTrue(source.contains(text), text)
        }

        XCTAssertEqual(SettingsHelperRows.statusTitle, "Status")
        XCTAssertEqual(SettingsHelperRows.helperTitle, "Helper")
        let fullMenu = try XCTUnwrap(source.range(of: "} else {\n                Section {"))
        let menu = String(source[fullMenu.lowerBound...])
        XCTAssertLessThan(try XCTUnwrap(menu.range(of: "Picker(\"Show\"")).lowerBound,
                          try XCTUnwrap(menu.range(of: "Toggle(\"Show symbol\"")).lowerBound)
        XCTAssertLessThan(try XCTUnwrap(menu.range(of: "Toggle(\"Show symbol\"")).lowerBound,
                          try XCTUnwrap(menu.range(of: "Picker(\"Precision\"")).lowerBound)
        XCTAssertLessThan(try XCTUnwrap(menu.range(of: "Picker(\"Precision\"")).lowerBound,
                          try XCTUnwrap(menu.range(of: "if !menuBarExcerpt && (!helperExcerpt || componentsExcerpt)")).lowerBound)
    }

    func testPickerToggleAndAccessibilitySemanticsStayNative() throws {
        let source = try source("Features/Settings/Views/SettingsRootView.swift")
        for token in [
            ".formStyle(.grouped)", ".pickerStyle(.menu)", ".toggleStyle(.switch)",
            ".accessibilityIdentifier(\"settings.show\")",
            ".accessibilityIdentifier(\"settings.showSymbol\")",
            ".accessibilityIdentifier(\"settings.precision\")",
            ".accessibilityIdentifier(\"settings.update\")",
            ".accessibilityValue(preferences.updateInterval)",
            ".accessibilityHint(\"Faster uses a little more energy.\")",
            ".accessibilityIdentifier(\"settings.smoothReadings\")",
            ".defaultFocus($focusedControl, .show)",
            ".focused($focusedControl, equals: .show)"
        ] {
            XCTAssertTrue(source.contains(token), token)
        }
        for forbidden in [
            "RoundedRectangle", "LinearGradient", "RadialGradient", "NSVisualEffectView",
            ".preferredColorScheme(", ".tint(", ".font(.system(size:"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testDestructiveConfirmationIsNativeAndNeverDefault() throws {
        XCTAssertEqual(SettingsRootView.uninstallMessage,
                       "Removes the helper, your settings and the login item, then moves Watt? to the Trash. Nothing is left behind.")
        let source = try source("Features/Settings/Views/SettingsRootView.swift")
        let alert = try XCTUnwrap(source.range(of: ".alert("))
        let body = String(source[alert.lowerBound...])
        XCTAssertTrue(body.contains("Button(\"Cancel\", role: .cancel)"))
        XCTAssertTrue(body.contains("role: .destructive"))
        XCTAssertLessThan(try XCTUnwrap(body.range(of: "Button(\"Cancel\", role: .cancel)")).lowerBound,
                          try XCTUnwrap(body.range(of: "role: .destructive")).lowerBound)
        XCTAssertTrue(body.contains("Button(\"Uninstall…\", role: .destructive)"))
    }

    func testSettingsSceneUsesNativeCloseAndNonResizableContentSize() throws {
        let root = try source("App/WattApp.swift")
        let settings = try XCTUnwrap(root.range(of: "Settings {"))
        let end = try XCTUnwrap(root.range(of: ".windowResizability(.contentSize)", range: settings.upperBound..<root.endIndex))
        let scene = String(root[settings.lowerBound..<end.upperBound])
        XCTAssertTrue(scene.contains(".windowResizability(.contentSize)"))
        XCTAssertFalse(scene.contains("NSWindow("))
        XCTAssertTrue(scene.contains("SettingsRootView("))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
#endif
