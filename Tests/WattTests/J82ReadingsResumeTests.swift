import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J82ReadingsResumeTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactStoryMetadataAndSelector() throws {
        let fixture = try ScenarioRegistry.resolve("J8.2")
        XCTAssertEqual(fixture.story.node, "J8.2")
        XCTAssertEqual(fixture.story.frame, "8.2 Readings resume automatically (no alert)")
        XCTAssertNil(fixture.story.appearance)
        XCTAssertEqual(fixture.story.expectedScene, "statusItem")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        XCTAssertNoThrow(try fixture.story.requireRenderTarget())

        let args = ["Watt", "--watt-fixture", "J8.2/base"]
        let selection = try XCTUnwrap(FixtureLaunchSelection.parse(args))
        XCTAssertEqual(try selection.smokeLaunchArguments(), ["--watt-fixture", "J8.2/base"])
        #if SWIFT_PACKAGE
        XCTAssertFalse(J82FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J82FixtureLaunch.matches(arguments: args))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        #endif
        for selector in ["J8.2", "J8.2/stale", "J8.2/", "J8.2//base", "J8.2/base/extra", "j8.2/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J82FixtureLaunch.matches(arguments: invalid))
        }
    }

    func testRecoveryPublishesNormalStatusWithoutAlertOrNavigation() async {
        let store = J82FixtureLaunch.makeStore()
        let preferences = J82FixtureLaunch.makePreferences()
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }

        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertFalse(router.statusPanelPresented)
        await J82FixtureLaunch.prepare(router: router, store: store)

        XCTAssertEqual(store.statusReading, .sampleCharging)
        XCTAssertNil(store.failure)
        XCTAssertFalse(router.statusPanelPresented)
        XCTAssertTrue(routes.isEmpty, "Recovery updates telemetry only; it must not navigate or present an alert")

        let label = MenuBarStatusLabel(reading: store.statusReading, preferences: preferences)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(label.accessibilityReading, "+42.1 watts")
    }

    func testRecoveryPreservesEverySelectedDisplayMode() async {
        for mode in WattDisplayMode.allCases {
            let store = J82FixtureLaunch.makeStore()
            let preferences = J82FixtureLaunch.makePreferences()
            preferences.displayMode = mode
            await store.refresh()
            XCTAssertEqual(preferences.displayMode, mode)
            XCTAssertEqual(store.statusReading, .sampleCharging)
        }
    }
    #endif

    func testRecoveredStateUsesNativeStatusBridgeAndNoCustomChrome() throws {
        let app = try source("App/WattApp.swift")
        for token in ["MenuBarExtra(isInserted:", ".menuBarExtraStyle(.window)",
                      "J82FixtureLaunch.prepare(router: router, store: powerStore)",
                      "view.observeJ82StatusFixture"] {
            XCTAssertTrue(app.contains(token), token)
        }
        let fixture = try source("App/J82FixtureLaunch.swift")
        for token in ["NSStatusBarButton", "MenuBarStatusLabel", "sampleCharging", "J8.2/base",
                      "visualPass", "score", "pixel_diff"] {
            XCTAssertTrue(fixture.contains(token), token)
        }
        for forbidden in ["NSPopover", "NSHostingView", "NSImage", "NSAlert", "RoundedRectangle",
                          "Gradient", ".background(", ".shadow(", "CGRequestScreenCaptureAccess",
                          "AXIsProcessTrustedWithOptions"] {
            XCTAssertFalse(fixture.contains(forbidden), forbidden)
        }
        XCTAssertFalse(app.contains("J82FixtureLaunch.requested { router.showStatusPanel()"))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testNativeSFRenderingAndExactRecoveredCopy() throws {
        let preferences = J82FixtureLaunch.makePreferences()
        let label = MenuBarStatusLabel(reading: .sampleCharging, preferences: preferences)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertTrue(label.showsSymbol)
        let image = try XCTUnwrap(NSImage(systemSymbolName: label.symbolName, accessibilityDescription: nil))
        XCTAssertTrue(image.isTemplate)
    }
    #endif

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}
