import AppKit
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J25SettingsConnectedTests: XCTestCase {
    #if DEBUG || SWIFT_PACKAGE
    func testExactConnectedCopySelectionStatusAndNativeWindow() async throws {
        let storage = InMemoryStorage()
        let session = J25FixtureSession(storage: storage)
        XCTAssertEqual(session.router.settingsHelperSetup.statusTitle, "Off")
        XCTAssertEqual(label(session), "—")
        await session.connect()
        XCTAssertTrue(session.componentsAvailable)
        XCTAssertEqual(session.router.settingsHelperSetup.statusTitle, "On")
        XCTAssertEqual(session.router.settingsHelperSetup.statusSubtitle, "CPU/GPU estimates appear only when both are available. Display, SSD and Other are unavailable.")
        XCTAssertNil(session.router.settingsHelperSetup.message)
        XCTAssertEqual(SettingsRootView.componentsSubtitle, "Two fit.")
        XCTAssertEqual(session.preferences.displayMode.rawValue, "Components")
        XCTAssertEqual(session.preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertEqual(label(session), "CPU 9.8 · GPU 4.1 W")
        let restored = PreferencesStore(storage: storage)
        XCTAssertEqual(restored.displayMode, .components)
        XCTAssertEqual(restored.selectedComponents, ["CPU", "GPU"])
        let submenu = try XCTUnwrap(menu(session).items.first?.submenu)
        XCTAssertEqual(submenu.items.filter { $0.state == .on }.map(\.title), ["Components"])
        XCTAssertTrue(submenu.items[3].isEnabled)
        session.preferences.selectedComponents = ["GPU"]
        XCTAssertEqual(label(session), "GPU 4.1 W")
        XCTAssertEqual(PreferencesStore(storage: storage).selectedComponents, ["GPU"])
        let window = session.makeWindow()
        XCTAssertEqual(window.title, "Watt? Settings")
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertNil(window.appearance)
        window.close()
    }

    func testRemovalVerifiedAbsenceTurnsOffAllSurfacesWithoutErasingSelection() async throws {
        let session = J25FixtureSession()
        await session.connect()
        let result = await session.router.removeVerifiedHelper(preferences: session.preferences)
        XCTAssertEqual(result, .verifiedAbsent)
        XCTAssertEqual(session.router.settingsHelperSetup.statusTitle, "Off")
        XCTAssertFalse(session.preferences.componentReadings)
        XCTAssertFalse(session.componentsAvailable)
        XCTAssertEqual(label(session), "− − W") // J9.1 switches to Delta after verified absence.
        XCTAssertTrue(panel(session).components.isEmpty)
        XCTAssertEqual(session.preferences.displayMode, .delta)
        XCTAssertEqual(session.preferences.selectedComponents, ["CPU", "GPU"])
        XCTAssertFalse(try XCTUnwrap(menu(session).items.first?.submenu).items[3].isEnabled)
    }

    func testFailureDoesNotClaimRemovalAndUnknownCannotRemove() async {
        let session = J25FixtureSession()
        await session.connect()
        session.driver.removalFailure = .denied
        let result = await session.router.removeVerifiedHelper(preferences: session.preferences)
        XCTAssertEqual(result, .failed(.denied))
        XCTAssertTrue(session.preferences.componentReadings)
        session.driver.statusValue = .unknown
        let unknown = await session.router.removeVerifiedHelper(preferences: session.preferences)
        XCTAssertEqual(unknown, .failed(.unknownStatus))
        XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
        XCTAssertEqual(label(session), "—")
    }

    func testPendingUnknownRevokedAndNoServiceFailClosedDespiteSavedIntent() async {
        for status: HelperRegistrationStatus in [.requiresApproval, .unknown, .disabled, .absent] {
            let session = J25FixtureSession()
            await session.connect()
            session.driver.statusValue = status
            await session.router.settingsHelperSetup.refreshStatus()
            XCTAssertFalse(session.componentsAvailable)
            XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
            XCTAssertEqual(label(session), "—")
            XCTAssertTrue(panel(session).components.isEmpty)
        }
        let session = J25FixtureSession()
        await session.connect()
        session.router.settingsHelperSetup.service = nil
        await session.router.settingsHelperSetup.refreshStatus()
        XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
        XCTAssertEqual(label(session), "—")
        XCTAssertTrue(session.preferences.componentReadings) // Saved intent is not authority.
    }

    func testAuthenticatedDisconnectAndLateReplyCannotResurrectReadings() async {
        let session = J25FixtureSession()
        session.transport.onSend = { session.helper.disconnect() }
        await session.connect()
        XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
        XCTAssertFalse(session.preferences.componentReadings)
        XCTAssertEqual(label(session), "—")
        session.transport.onSend = nil
        await session.connect()
        XCTAssertTrue(session.componentsAvailable)
        session.helper.disconnect()
        XCTAssertFalse(session.componentsAvailable)
        XCTAssertEqual(label(session), "—")
    }

    func testUntrustedPeerCannotEnableFixture() async {
        let session = J25FixtureSession()
        session.transport.peer = HelperPeer(identifier: "impostor", team: "FIXTURE", protocolVersion: 1)
        await session.connect()
        XCTAssertFalse(session.router.settingsHelperSetup.helperOn)
        XCTAssertFalse(session.preferences.componentReadings)
        XCTAssertEqual(label(session), "—")
    }

    func testDisabledPreferenceAndStaleUnavailableReadingsGatePresentation() async throws {
        let session = J25FixtureSession()
        await session.connect()
        session.preferences.componentReadings = false
        XCTAssertEqual(label(session), "—")
        XCTAssertTrue(panel(session).components.isEmpty)
        XCTAssertFalse(try XCTUnwrap(menu(session).items.first?.submenu).items[3].isEnabled)
        session.preferences.componentReadings = true
        for freshness: ReadingFreshness in [.stale, .unavailable] {
            let reading = PowerReading(mode: .perComponent, watts: nil, components: PowerReading.samplePerComponent.components,
                capabilities: .init(components: .available), freshness: freshness, source: .fixture)
            XCTAssertEqual(MenuBarStatusLabel(reading: reading, preferences: session.preferences).text, "—")
            XCTAssertTrue(StatusPanelModel(reading: reading).components.isEmpty)
        }
        let reading = PowerReading(mode: .perComponent, watts: nil, components: PowerReading.samplePerComponent.components,
            capabilities: .init(components: .available), source: .unavailable)
        XCTAssertEqual(MenuBarStatusLabel(reading: reading, preferences: session.preferences).text, "—")
        XCTAssertTrue(StatusPanelModel(reading: reading).components.isEmpty)
    }

    func testSettingsPanelAndContextNavigationPreserveConnection() async throws {
        let session = J25FixtureSession()
        await session.connect()
        var destinations: [AppDestination] = []
        session.router.present = { destinations.append($0) }
        let menu = menu(session)
        for title in ["Open Watt?", "Settings…"] {
            let item = try XCTUnwrap(menu.items.first { $0.title == title })
            _ = (item.target as? NSObject)?.perform(try XCTUnwrap(item.action), with: item)
        }
        XCTAssertEqual(destinations, [.statusPanel, .settings])
        XCTAssertTrue(session.componentsAvailable)
        XCTAssertFalse(panel(session).components.isEmpty)
    }

    func testRegistryPinsExactNodeAndRejectsUnsupportedVariants() throws {
        let fixture = try ScenarioRegistry.resolve("J2.5")
        XCTAssertEqual(fixture.story.node, "J2.5")
        XCTAssertEqual(try FixtureLaunchSelection.story(fixture).smokeLaunchArguments(), ["--watt-fixture", "J2.5/base"])
        for variant in ["dark", "unknown", "live", "revoked"] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(["--watt-fixture", "J2.5/" + variant]))
        }
    }

    private func label(_ session: J25FixtureSession) -> String? {
        MenuBarStatusLabel(reading: session.store.currentReading, preferences: session.preferences).text
    }
    private func panel(_ session: J25FixtureSession) -> StatusPanelModel {
        StatusPanelModel(reading: session.store.currentReading, componentReadingsEnabled: session.preferences.componentReadings)
    }
    private func menu(_ session: J25FixtureSession) -> NSMenu {
        StatusItemContextMenu.makeMenu(router: session.router, preferences: session.preferences,
                                      componentsAvailable: { session.componentsAvailable })
    }
    #endif
}
