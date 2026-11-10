import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J32HelperSwitchedOffTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testVerifiedDisconnectRetainsPowerAndUsesDeltaWithoutChangingSavedSelection() async throws {
        let session = J25FixtureSession()
        await session.connect()
        session.helper.disconnect()
        let setup = session.router.settingsHelperSetup
        XCTAssertTrue(setup.helperSwitchedOff)
        XCTAssertFalse(setup.helperOn)
        XCTAssertFalse(session.router.helperNotApprovedPresented)
        let reading = PowerReading.sampleCharging
        let panel = StatusPanelModel(reading: reading, helperSwitchedOff: setup.helperSwitchedOff)
        XCTAssertEqual(panel.charger, "65.0 W")
        XCTAssertEqual(panel.system, "22.9 W")
        XCTAssertEqual(panel.battery, "+42.1 W")
        XCTAssertTrue(panel.components.isEmpty)
        XCTAssertEqual(panel.panelHeight, 347)
        let label = MenuBarStatusLabel(reading: reading, preferences: session.preferences, helperSwitchedOff: true)
        XCTAssertEqual(label.text, "+42.1 W")
        XCTAssertEqual(label.symbolName, "battery.100percent.bolt")
        XCTAssertEqual(session.preferences.displayMode, .components)
        let menu = StatusItemContextMenu.makeMenu(router: session.router, preferences: session.preferences,
                                                  componentsAvailable: { true })
        let readings = try XCTUnwrap(menu.items.first?.submenu)
        XCTAssertEqual(readings.items.filter { $0.state == .on }.map(\.title), ["Delta"])
        XCTAssertFalse(readings.items[3].isEnabled)
        await session.connect()
        XCTAssertTrue(setup.helperSwitchedOff) // Authentication alone is insufficient.
        XCTAssertTrue(setup.helperOn)
        setup.confirmRecoveredComponents(recoveredReading())
        XCTAssertFalse(setup.helperSwitchedOff)
    }

    func testRevocationAndPendingApprovalDoNotPresentInitialApprovalFailure() async {
        for status: HelperRegistrationStatus in [.disabled, .requiresApproval, .absent] {
            let session = J25FixtureSession()
            await session.connect()
            session.driver.statusValue = status
            await session.router.settingsHelperSetup.refreshStatus()
            XCTAssertTrue(session.router.settingsHelperSetup.helperSwitchedOff)
            XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
            XCTAssertFalse(session.router.helperNotApprovedPresented)
        }
        let session = J25FixtureSession()
        session.driver.statusValue = .disabled
        await session.connect()
        XCTAssertFalse(session.router.settingsHelperSetup.helperSwitchedOff)
    }

    func testLateAuthenticatedReplyDoesNotClearHelperOff() async {
        let session = J25FixtureSession()
        await session.connect()
        session.helper.disconnect()
        session.transport.onSend = { session.helper.disconnect() }
        await session.router.settingsHelperSetup.refreshStatus()
        XCTAssertTrue(session.router.settingsHelperSetup.helperSwitchedOff)
        XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
    }
    #endif

    func testExactCopyNativeSymbolAndCallbacks() throws {
        XCTAssertEqual(HelperOffPresentation.title, "Helper is off")
        XCTAssertEqual(HelperOffPresentation.subtitle, "Showing Delta until it’s back.")
        XCTAssertEqual(HelperOffPresentation.action, "Fix…")
        XCTAssertEqual(HelperOffPresentation.symbol, "exclamationmark.triangle.fill")
        XCTAssertNotNil(NSImage(systemSymbolName: HelperOffPresentation.symbol, accessibilityDescription: nil))
        let router = AppRouter()
        var destinations: [AppDestination] = []
        var quits = 0
        router.present = { destinations.append($0) }
        let view = StatusPanelView(reading: .sampleCharging, helperSwitchedOff: true,
                                   onSettings: router.showSettings, onQuit: { quits += 1 })
        view.onSettings()
        view.onQuit()
        XCTAssertEqual(destinations, [.settings])
        XCTAssertEqual(quits, 1)
        XCTAssertFalse(router.settingsHelperSetup.helperOn)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testStaleUnavailableAndComponentsAreNeverFabricated() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        for freshness: ReadingFreshness in [.fresh, .stale, .unavailable] {
            let reading = PowerReading(mode: .perComponent, watts: nil,
                components: PowerReading.samplePerComponent.components,
                capabilities: .init(components: .available), freshness: freshness, source: .fixture)
            XCTAssertTrue(StatusPanelModel(reading: reading, helperSwitchedOff: true).components.isEmpty)
            XCTAssertEqual(MenuBarStatusLabel(reading: reading, preferences: preferences, helperSwitchedOff: true).text, "—")
        }
        XCTAssertEqual(StatusPanelModel(reading: .unavailable, helperSwitchedOff: true).charger, "—")
    }

    func testExternalReenablePreservesIntentAndWaitsForFreshAuthenticatedTelemetry() async {
        let session = J25FixtureSession()
        await session.connect()
        let setup = session.router.settingsHelperSetup
        let old = recoveredReading()
        session.driver.statusValue = .disabled
        await setup.refreshStatus()
        XCTAssertTrue(setup.helperSwitchedOff)
        XCTAssertTrue(session.preferences.componentReadings)
        XCTAssertEqual(session.preferences.displayMode, .components)
        XCTAssertEqual(session.preferences.selectedComponents, ["CPU", "GPU"])
        setup.confirmRecoveredComponents(recoveredReading()) // Still unauthenticated.
        XCTAssertTrue(setup.helperSwitchedOff)
        session.driver.statusValue = .enabled
        await setup.refreshStatus()
        XCTAssertTrue(setup.helperOn)
        for reading in [old, .samplePerComponent, .unavailable,
                        recoveredReading(freshness: .stale), recoveredReading(freshness: .unavailable)] {
            setup.confirmRecoveredComponents(reading)
            XCTAssertTrue(setup.helperSwitchedOff)
        }
        setup.confirmRecoveredComponents(recoveredReading())
        XCTAssertFalse(setup.helperSwitchedOff)
        XCTAssertTrue(session.preferences.componentReadings)
        XCTAssertEqual(session.preferences.displayMode, .components)
    }
    #endif

    func testProductionStartupDoesNotUsePreviewTelemetry() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("let appPowerStore = PowerReadingStore(currentReading: .unavailable,"))
        XCTAssertTrue(source.contains("_powerStore = StateObject(wrappedValue: appPowerStore)"))
        XCTAssertTrue(source.contains("telemetry: SystemPowerSourceTelemetryService()"))
        XCTAssertFalse(source.contains("_powerStore = StateObject(wrappedValue: PowerReadingStore.preview)"))
    }

    #if DEBUG || SWIFT_PACKAGE
    private func recoveredReading(freshness: ReadingFreshness = .fresh) -> PowerReading {
        PowerReading(mode: .perComponent, watts: nil,
                     components: PowerReading.samplePerComponent.components,
                     timestamp: Date(), capabilities: .init(components: .available),
                     freshness: freshness, source: .helper)
    }

    func testRegistryExactNodeAndDarkNativeScene() throws {
        let fixture = try ScenarioRegistry.resolve("J3.2")
        XCTAssertEqual(fixture.story.node, "J3.2")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(),
                       ["--watt-fixture", "J3.2/base"])
        XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J3.2/live"]))
    }
    #endif
}
