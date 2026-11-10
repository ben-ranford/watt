import AppKit
import SwiftUI
import XCTest
@testable import Watt

@MainActor
final class NativeStylingTests: XCTestCase {
    func testOnboardingUsesIntrinsicNativeControlsAndSemanticType() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let flow = try String(contentsOf: root.appendingPathComponent("Features/Onboarding/Views/OnboardingFlowView.swift"))
        for forbidden in ["formRowHeight", ".padding(.horizontal, -", ".padding(.top, -",
                          ".padding(.bottom, -", "height: 296", "height: 332"] {
            XCTAssertFalse(flow.contains(forbidden), forbidden)
        }
        for (view, nextView, style) in [
            ("OfferComponentReadingsView", "WaitingForApprovalView", "grouped"),
            ("AllSetView", "ComponentPreviewView", "grouped"),
            ("ComponentPreviewView", "CoachMarkView", "columns")
        ] {
            let start = try XCTUnwrap(flow.range(of: "struct \(view): View"))
            let end = try XCTUnwrap(flow.range(of: "struct \(nextView): View",
                                               range: start.upperBound..<flow.endIndex))
            let source = flow[start.lowerBound..<end.lowerBound]
            XCTAssertTrue(source.contains(".formStyle(.\(style))"), view)
        }
        let typography = try String(contentsOf: root.appendingPathComponent("DesignSystem/Theme/WattTypography.swift"))
        XCTAssertFalse(typography.contains("Font.system(size:"))
        XCTAssertEqual(WattTypography.title, Font.title2.weight(.bold))
        XCTAssertEqual(WattTypography.footnote, Font.footnote)
        XCTAssertTrue(flow.contains("NSSize(width: WattSpacing.coachMarkWidth, height: WattSpacing.coachMarkHeight)"))
        let panel = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"))
        XCTAssertTrue(panel.contains(".frame(width: WattSpacing.panelWidth, height: model.panelHeight)"))
    }

    func testOnboardingHelperActionsUseNativeHorizontalSpacing() throws {
        let flow = try source("Features/Onboarding/Views/OnboardingFlowView.swift")
        for action in ["notNow", "turnOn"] {
            let start = try XCTUnwrap(flow.range(of: "Button { Self.perform(.\(action),"))
            let end = try XCTUnwrap(flow.range(
                of: ".accessibilityIdentifier(\"onboarding.helper.\(action)\")",
                range: start.lowerBound..<flow.endIndex
            ))
            let control = flow[start.lowerBound..<end.upperBound]
                .filter { !$0.isWhitespace }
            XCTAssertFalse(control.contains(".padding(.horizontal"),
                           "\(action) must use native button horizontal spacing")
        }
    }

    func testProductionAppearanceAndMetricsAreNative() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }
        for path in ["Features/Settings/Views/SettingsRootView.swift", "Features/Onboarding/Views/OnboardingFlowView.swift"] {
            let text = try source(path)
            XCTAssertFalse(text.contains(".preferredColorScheme("), path)
            // J5.1 alone explicitly requests a light native coach mark. J1.7 still inherits appearance.
            XCTAssertEqual(text.components(separatedBy: "appearance = NSAppearance").count - 1,
                           path.contains("OnboardingFlowView") ? 1 : 0, path)
            XCTAssertFalse(text.contains(".frame(width: 580)"), path)
            XCTAssertFalse(text.contains(".frame(width: 480)"), path)
        }
        XCTAssertTrue(try source("Features/Settings/Views/SettingsRootView.swift").contains("WattSpacing.settingsWidth"))
        XCTAssertTrue(try source("Features/Onboarding/Views/OnboardingFlowView.swift").contains("WattSpacing.onboardingWidth"))
        XCTAssertTrue(try source("Features/MenuBar/Components/MenuBarStatusLabel.swift").contains("HStack(spacing: WattSpacing.xs)"))
        let panel = try source("Features/MenuBar/Views/StatusPanelView.swift")
        XCTAssertTrue(panel.contains("Button(\"Quit Watt?\", action: onQuit)"))
        XCTAssertFalse(panel.contains("role: .destructive"))
    }

    func testButtonsPreserveLayoutWithNativeAccessibilityAppearances() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            for style in [WattActionButton.Style.bordered, .prominent, .destructive] {
                let button = WattActionButton(title: "Continue", style: style) {}
                let enabled = fittingSize(button, appearance: appearance)
                XCTAssertGreaterThan(enabled.height, 0)
                XCTAssertEqual(enabled, fittingSize(button.disabled(true), appearance: appearance))
            }
        }
    }

    func testSharedControlsDoNotPaintSystemChrome() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let contracts = [
            "DesignSystem/Components/ComponentSelectionMenu.swift": ["NSPopUpButton(", "NSMenu(title:", "NSMenuItem(title:", "menu.showsStateColumn = true", "item.isEnabled =", "item.state ="],
            "DesignSystem/Components/WattActionButton.swift": [".buttonStyle(.bordered)", ".buttonStyle(.borderedProminent)", "role: .destructive"],
            "DesignSystem/Components/WattFormRow.swift": ["LabeledContent"],
            "DesignSystem/Verification/WattComponentGallery.swift": ["Form {", "Section", ".formStyle(.grouped)", "role: .cancel", "role: .destructive"],
            "DesignSystem/Components/ReadingPicker.swift": [".pickerStyle(.radioGroup)", ".disabled(unavailableModes.contains(mode))", "NSViewRepresentable", "setButtonType(.radio)", "button.isEnabled = !unavailableModes.contains(option.mode)"],
            "Features/MenuBar/Views/StatusPanelView.swift": ["Form {", "Section", ".formStyle(.grouped)", "LabeledContent"],
            "Features/Onboarding/Views/OnboardingFlowView.swift": [".keyboardShortcut(.cancelAction)", "LabeledContent"]
        ]
        for (path, tokens) in contracts {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for token in tokens { XCTAssertTrue(source.contains(token), "\(path): \(token)") }
            for forbidden in ["LinearGradient", "RoundedRectangle", ".strokeBorder(", ".tint(", "Rectangle()"] {
                XCTAssertFalse(source.contains(forbidden), "\(path): custom chrome \(forbidden)")
            }
        }
        let scaffold = try String(contentsOf: root.appendingPathComponent("DesignSystem/Components/WattWindowScaffold.swift"), encoding: .utf8)
        XCTAssertFalse(scaffold.contains(".clipShape"))
        XCTAssertFalse(scaffold.contains(".background"))
        let gallery = try String(contentsOf: root.appendingPathComponent("DesignSystem/Verification/WattComponentGallery.swift"), encoding: .utf8)
        XCTAssertFalse(gallery.contains(".background"))
        XCTAssertFalse(gallery.contains(".foregroundStyle(WattColors.primaryLabel)"))
        let actions = try String(contentsOf: root.appendingPathComponent("DesignSystem/Components/WattActionButton.swift"), encoding: .utf8)
        XCTAssertFalse(actions.contains(".foregroundStyle"))
    }

    func testFocusSpecimenUsesOneNativeFieldLabel() throws {
        let source = try source("DesignSystem/Verification/WattComponentGallery.swift")
        XCTAssertEqual(source.components(separatedBy: "TextField(\"Focused field\"").count - 1, 1)
        XCTAssertFalse(source.contains("Text(\"Focused field\")"))
        XCTAssertTrue(source.contains(".focused($fieldFocused)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(\"gallery.focus\")"))
    }

    func testSettingsNotesUseSectionFootersWithoutExtraChromeOrSpacing() throws {
        let gallery = try source("DesignSystem/Verification/WattComponentGallery.swift")
        let normalized = gallery.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(normalized.contains("} footer: { Text(\"Menu bar full? Choose Icon and Watt? stays put.\")"))
        let settings = try source("Features/Settings/Views/SettingsRootView.swift")
        for token in ["Form {", "Section {", "} footer: {", ".formStyle(.grouped)", "Text(\"Menu Bar\")", "Section(\"General\")"] {
            XCTAssertTrue(settings.contains(token), token)
        }
        for text in [gallery, settings] {
            for forbidden in [".background", ".clipShape", "RoundedRectangle", "LinearGradient", ".listSectionSpacing", "referenceSettingsSectionSpacing"] {
                XCTAssertFalse(text.contains(forbidden), forbidden)
            }
        }
        XCTAssertFalse(settings.contains("VStack"))
        XCTAssertFalse(settings.contains(".padding"))
    }

    func testContextMenuUsesNativeColumnsWithoutSpacerImages() throws {
        let menu = try source("Features/MenuBar/Views/StatusItemContextMenu.swift")
        for forbidden in ["NSImage(", ".image =", "preferredImageVisibility", "spacerWidth", ".font =",
                          "RoundedRectangle", "Gradient", ".background", ".shadow", ".tint",
                          ".view =", "NSHostingView", ".highlightedItem ="] {
            XCTAssertFalse(menu.contains(forbidden), "Menu geometry must remain native: \(forbidden)")
        }
        XCTAssertTrue(menu.contains("menu.minimumWidth = referenceMenuWidth"))
        XCTAssertTrue(menu.contains("readings.minimumWidth = referenceReadingsMenuWidth"))
        for required in ["menu.showsStateColumn = true", "readings.showsStateColumn = true",
                         "readings.items.last?.state = effectiveMode == mode ? .on : .off"] {
            XCTAssertTrue(menu.contains(required), "Preserve native selection semantics: \(required)")
        }
    }

    func testComponentPopupPreservesSystemChromeAndIntrinsicMetrics() throws {
        let menu = try source("DesignSystem/Components/ComponentSelectionMenu.swift")
        for forbidden in [".view =", "NSHostingView", "RoundedRectangle", "Gradient", ".background", ".shadow",
                          ".overlay", ".position(", ".offset(", ".font =", "Font.custom", "NSFont(",
                          ".frame =", ".minimumWidth =", ".image =", ".tint(", "draw(", ".appearance ="] {
            XCTAssertFalse(menu.contains(forbidden), forbidden)
        }
        XCTAssertTrue(menu.contains("cell?.usesItemFromMenu = false"))
        XCTAssertTrue(menu.contains("cell?.altersStateOfSelectedItem = false"))
        XCTAssertTrue(menu.contains("setAccessibilityLabel(\"Components\")"))
        XCTAssertTrue(menu.contains("func menuNeedsUpdate"))
    }

    func testSoftwareUpdateUsesNativeAppearanceAndIntrinsicControls() throws {
        let text = try source("App/RootSceneView.swift").components(separatedBy: "#if DEBUG")[0]
        for forbidden in [".preferredColorScheme(", ".tint(", ".system(size:", "RoundedRectangle",
                          "NSVisualEffectView", "LinearGradient", ".frame(height:", ".controlSize(", ".cornerRadius("] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
        for required in ["ProgressView(value:", ".buttonStyle(.bordered)", "WattTypography.bodyEmphasized", "WattTypography.footnote"] {
            XCTAssertTrue(text.contains(required), required)
        }
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testWindowScaffoldRetainsContentInNativeAppearances() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let scaffold = WattWindowScaffold(title: "Settings") {
                Text("Reading").frame(width: 240, height: 100)
            }
            let size = fittingSize(scaffold, appearance: appearance)
            XCTAssertGreaterThanOrEqual(size.width, 240)
            XCTAssertGreaterThanOrEqual(size.height, 100)
        }
    }

    private func fittingSize<V: View>(_ view: V, appearance: NSAppearance.Name) -> NSSize {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(x: 0, y: 0, width: 320, height: 160)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }
}
