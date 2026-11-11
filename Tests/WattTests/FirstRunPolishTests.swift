import IOKit.ps
import XCTest
@testable import Watt

@MainActor
final class FirstRunPolishTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_700_000_000)

    func testNewInstallDefaultsToSystemDrawAndLeavesLoginOff() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        XCTAssertEqual(preferences.displayMode, .draw)
        XCTAssertEqual(preferences.displayMode.title, "System Draw")
        XCTAssertFalse(preferences.openAtLogin)
        XCTAssertTrue(preferences.checkForUpdatesAutomatically)
        let restored = PreferencesStore(storage: InMemoryStorage())
        XCTAssertEqual(restored.displayMode, .draw)
        XCTAssertFalse(restored.openAtLogin)
    }

    func testIdleAcBatteryFlowRendersAsZeroRatherThanAMissingReading() throws {
        let reading = try idleAcReading(batteryMilliwatts: 0)
        XCTAssertEqual(reading.batteryState, .unknown)
        XCTAssertEqual(try XCTUnwrap(reading.watts), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .delta)), 0, accuracy: 0.001)
        XCTAssertEqual(PowerFormatter.watts(reading.value(for: .delta)), "0.0 W")
        XCTAssertNotEqual(PowerFormatter.watts(reading.value(for: .delta)), "—")

        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .delta
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(label.text, "0.0 W")
        XCTAssertEqual(label.accessibilityReading, "0.0 watts")
        XCTAssertNotEqual(label.accessibilityReading, "No reading yet")

        preferences.displayMode = .draw
        let draw = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(draw.text, "19.7 W")
        XCTAssertNotEqual(draw.accessibilityReading, "No reading yet")

        let panel = StatusPanelModel(reading: reading)
        XCTAssertEqual(panel.title, "Not charging")
        XCTAssertEqual(panel.headlineValue, "0.0 W")
        XCTAssertEqual(panel.battery, "0.0 W")
        XCTAssertEqual(panel.charger, "19.7 W")
        XCTAssertEqual(panel.system, "19.7 W")
        XCTAssertTrue(panel.showsUnavailableComponents)
        XCTAssertNil(panel.panelHeight)
        XCTAssertNotEqual(panel.headlineValue, "—")
        XCTAssertNotEqual(panel.battery, "—")
    }

    func testUnclassifiedNonZeroBatteryFlowStaysUnavailable() throws {
        let reading = try idleAcReading(batteryMilliwatts: 4_200)
        XCTAssertEqual(reading.batteryState, .unknown)
        XCTAssertNil(reading.watts)
        XCTAssertNil(reading.value(for: .delta))
        XCTAssertEqual(PowerFormatter.watts(reading.value(for: .delta)), "—")
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .draw)), 19.7, accuracy: 0.001)
    }

    func testWholePrecisionIdleFlowIsStillANumber() throws {
        let reading = try idleAcReading(batteryMilliwatts: 0)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .delta
        preferences.precision = .whole
        XCTAssertEqual(MenuBarStatusLabel(reading: reading, preferences: preferences).text, "0 W")
    }

    func testHelperNotInstalledCopyIsSingularAndOffersInstall() throws {
        let setup = SettingsHelperSetup()
        setup.unavailableReason = .installationRequired
        XCTAssertEqual(setup.statusTitle, "Not installed")
        XCTAssertEqual(setup.statusSubtitle, "Watt? Helper isn’t installed.")
        XCTAssertNil(setup.message)
        XCTAssertFalse(setup.statusSubtitle.contains("unavailable in this build"))
        XCTAssertFalse(setup.canInstallHelper)

        setup.installHelper = { nil }
        XCTAssertTrue(setup.canInstallHelper)
        XCTAssertEqual(setup.statusSubtitle, HelperUnavailableReason.installationRequired.message)
        XCTAssertNil(setup.message)

        let offered = ChooseMenuReadingView.options(reading: .sampleCharging, helperAvailable: false, installOffered: true)
        XCTAssertEqual(offered.last?.mode, .components)
        let description = try XCTUnwrap(offered.last?.description)
        XCTAssertEqual(description, "The helper isn’t installed. Install it on the next step.")
        XCTAssertFalse(description.contains("unavailable in this build"))
        XCTAssertEqual(OfferComponentReadingsView.installMessage.contains("isn’t installed"), true)

        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.advance(preferences: preferences, helperAvailable: false, installOffered: true)
        XCTAssertEqual(preferences.onboarding.checkpoint, .helperOffer)
    }

    func testReviewedInstallCommandUsesThePreflightDigest() async {
        let installer = URL(fileURLWithPath: "/Applications/Watt.app/Contents/MacOS/WattHelperInstaller")
        let source = URL(fileURLWithPath: "/Applications/Watt.app")
        let digest = String(repeating: "ab", count: 32)
        var commands: [HelperBundleInstall.Command] = []
        let failure = await HelperBundleInstall.install(installer: installer, source: source, rotate: false) { command in
            commands.append(command)
            if command.arguments.first == "--preflight" {
                return .success("hashes\nApproval: \(digest)\n")
            }
            return .success("installed\n")
        }
        XCTAssertNil(failure)
        XCTAssertEqual(commands.map(\.privileged), [false, true])
        XCTAssertEqual(commands[0].arguments, ["--preflight", "--source", source.path])
        XCTAssertEqual(commands[1].arguments, ["--bootstrap-reviewed", "--source", source.path, "--approval", digest])
        XCTAssertNil(HelperBundleInstall.approvalDigest(in: "Approval: NOPE\n"))
        XCTAssertEqual(HelperBundleInstall.reviewed(installer: installer, source: source, approval: digest, rotate: true).arguments.first, "--rotate-reviewed")
    }

    func testCheckForUpdatesNowReportsUpToDateAndErrors() async {
        XCTAssertFalse(AppRouter().checkForUpdatesNow())

        let upToDate = FakeUpdateService()
        upToDate.availableVersion = .success(nil)
        let current = AppRouter(updateService: upToDate, updates: UpdateStore(storage: InMemoryStorage()))
        var destinations: [AppDestination] = []
        current.present = { destinations.append($0) }
        XCTAssertTrue(current.checkForUpdatesNow())
        XCTAssertEqual(destinations, [.softwareUpdate])
        XCTAssertFalse(current.checkForUpdatesFromMenu(presentationID: UUID()))
        for _ in 0..<40 { await Task.yield() }
        XCTAssertTrue(current.upToDatePresented)
        XCTAssertTrue(current.upToDateMessage.contains("is the latest."))

        let failing = FakeUpdateService()
        failing.availableVersion = .failure(.network)
        let router = AppRouter(updateService: failing, updates: UpdateStore(storage: InMemoryStorage()))
        XCTAssertTrue(router.checkForUpdatesNow())
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(router.checkFailurePresentation?.reason, .network)
        XCTAssertFalse(router.upToDatePresented)
    }

    private func idleAcReading(batteryMilliwatts: Int) throws -> PowerReading {
        let battery: [String: Any] = [
            kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
            kIOPSIsChargingKey: false, kIOPSIsChargedKey: false,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSCurrentCapacityKey: 90, kIOPSMaxCapacityKey: 100
        ]
        return try SystemPowerSourceParser.parse(.init(
            descriptions: [battery], providingSource: kIOPSACPowerValue, timestamp: time,
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": batteryMilliwatts,
                "SystemPowerIn": 19_700,
                "SystemLoad": 19_700
            ]]))
    }
}
