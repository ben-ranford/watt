import IOKit.ps
import XCTest
@testable import Watt
#if SWIFT_PACKAGE
import WattHelperShared
#endif

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
        XCTAssertEqual(description, "The helper isn’t installed. Go back to install it.")
        XCTAssertFalse(description.contains("unavailable in this build"))
        XCTAssertTrue(OfferComponentReadingsView.installMessage.hasPrefix(HelperPurpose.explanation))

        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.advance(preferences: preferences)
        XCTAssertEqual(preferences.onboarding.checkpoint, .allSet)
        preferences.onboarding.checkpoint = .picker
        ChooseMenuReadingView.back(preferences: preferences, returnToInstall: true)
        XCTAssertEqual(preferences.onboarding.checkpoint, .helperOffer)
    }

    func testInstallActionDoesNotAlsoOfferUnavailable() {
        let setup = SettingsHelperSetup()
        setup.unavailableReason = .installationRequired
        setup.installHelper = { nil }
        XCTAssertTrue(setup.canInstallHelper)
        XCTAssertFalse(setup.helperServiceAvailable)
        XCTAssertEqual(setup.actionTitle, "Unavailable")
        let panel = StatusPanelModel(reading: .sampleChargedOnAdapter, componentsNeedInstall: true)
        XCTAssertEqual(panel.unavailableComponentsSubtitle, "Helper not installed")
        XCTAssertEqual(panel.accessibilityRows.last?.subtitle, nil)
        XCTAssertEqual(panel.accessibilityRows.last?.value, "Helper not installed")
        let plain = StatusPanelModel(reading: .sampleChargedOnAdapter)
        XCTAssertEqual(plain.unavailableComponentsSubtitle, "Unavailable")
    }

    func testUnconfiguredUpdaterExplainsTheDisabledCheck() {
        let missing = AppRouter()
        XCTAssertFalse(missing.canCheckForUpdates)
        XCTAssertEqual(missing.updateUnavailableReason, "Updates aren’t configured in this build.")
        let configured = AppRouter(updateService: FakeUpdateService(), updates: UpdateStore(storage: InMemoryStorage()))
        XCTAssertNil(configured.updateUnavailableReason)
        XCTAssertTrue(configured.canCheckForUpdates)
    }

    func testUpdateReasonNamesTheCopyTheHelperUsesInsteadOfAMissingConfiguration() {
        let applications = URL(fileURLWithPath: "/Applications/Watt.app")
        let managed = URL(fileURLWithPath: "/Library/Application Support/Watt/generations/11111111-2222-4333-8444-555555555555-2/Watt.app")
        let elsewhere = ManagedCopyPolicy.placement(running: applications, managed: managed,
                                                    runningMatchesPins: true, managedMatchesPins: true)
        XCTAssertEqual(elsewhere, .sameBuildElsewhere(managed: managed))
        let router = AppRouter(updateConfigurationFailure: .untrustedIdentity)
        router.updateUnavailableCause = ManagedCopyPolicy.updateCause(for: elsewhere)
        XCTAssertFalse(router.canCheckForUpdates)
        XCTAssertEqual(router.updateUnavailableReason,
                       "Updates run from the copy the helper uses. Quit Watt? and open it again to switch to that copy.")

        let differs = ManagedCopyPolicy.placement(running: applications, managed: managed,
                                                  runningMatchesPins: false, managedMatchesPins: true)
        XCTAssertEqual(differs, .differentBuildElsewhere(managed: managed))
        router.updateUnavailableCause = ManagedCopyPolicy.updateCause(for: differs)
        XCTAssertEqual(router.updateUnavailableReason,
                       "This copy of Watt? doesn’t match the copy the helper uses. Turn on the helper in Settings to switch to this copy.")

        router.updateUnavailableCause = .privacyProtectedFolder
        XCTAssertEqual(router.updateUnavailableReason, "Move Watt? to Applications to get updates.")

        for reason in UpdateUnavailableCause.allCases.map(\.message) {
            XCTAssertFalse(reason.contains("\u{2014}"), "no em dashes in update copy")
        }
    }

    func testOnlyAnExactPinnedCopyElsewhereHandsLaunchToTheHelperCopy() {
        let managed = URL(fileURLWithPath: "/Library/Application Support/Watt/generations/11111111-2222-4333-8444-555555555555-2/Watt.app")
        let applications = URL(fileURLWithPath: "/Applications/Watt.app")
        XCTAssertEqual(ManagedCopyPolicy.placement(running: applications, managed: nil,
                                                   runningMatchesPins: false, managedMatchesPins: false),
                       .noProtectedInstallation)
        XCTAssertEqual(ManagedCopyPolicy.placement(running: URL(fileURLWithPath: managed.path + "/"), managed: managed,
                                                   runningMatchesPins: true, managedMatchesPins: true),
                       .managed)
        XCTAssertEqual(ManagedCopyPolicy.placement(running: applications, managed: managed,
                                                   runningMatchesPins: true, managedMatchesPins: false),
                       .differentBuildElsewhere(managed: managed),
                       "a protected copy that fails its own pins is never opened")
        XCTAssertEqual(ManagedCopyPolicy.updateCause(for: .managed), .notConfigured)
        XCTAssertEqual(ManagedCopyPolicy.updateCause(for: .noProtectedInstallation), .notConfigured)
    }

    func testProtectedHelperRemovalRunsTheProtectedInstallerAsAdministrator() async throws {
        let installation = try XCTUnwrap(UUID(uuidString: "11111111-2222-4333-8444-555555555555"))
        let record = try ProtectedHelperRecord(installationID: installation, generation: 2, build: 1_003_001,
                                               appHashes: [Data(repeating: 1, count: 20)],
                                               helperHashes: [Data(repeating: 2, count: 20)],
                                               maintenanceHashes: [Data(repeating: 3, count: 20)])
        var commands: [HelperBundleInstall.Command] = []
        let lifecycle = ProtectedHelperLifecycle(record: record, candidate: { throw ServiceFailure.untrustedIdentity },
                                                 recordPresent: { true }, helperAbsent: { false },
                                                 administrator: { commands.append($0); return .success("") })
        try await lifecycle.unregister(receipt: OperationReceipt(createdAt: time))
        XCTAssertEqual(commands, [HelperBundleInstall.Command(
            executable: "/Library/Application Support/Watt/generations/11111111-2222-4333-8444-555555555555-2/Watt.app/Contents/MacOS/WattHelperInstaller",
            arguments: ["--remove-helper", "--installation", "11111111-2222-4333-8444-555555555555", "--generation", "2"],
            privileged: true)])

        let cancelled = ProtectedHelperLifecycle(record: record, candidate: { throw ServiceFailure.untrustedIdentity },
                                                 recordPresent: { true }, helperAbsent: { false },
                                                 administrator: { _ in .failure(.cancelled) })
        do {
            try await cancelled.unregister(receipt: OperationReceipt(createdAt: time))
            XCTFail("a cancelled password prompt is not a removal")
        } catch { XCTAssertEqual(error as? ServiceFailure, .cancelled) }
    }

    func testProtectedHelperIsAbsentOnlyWhenPinsFilesAndProcessAreGone() async throws {
        let record = try ProtectedHelperRecord(installationID: UUID(), generation: 1, build: 1_003_001,
                                               appHashes: [Data(repeating: 1, count: 20)],
                                               helperHashes: [Data(repeating: 2, count: 20)],
                                               maintenanceHashes: [Data(repeating: 3, count: 20)])
        let gone = ProtectedHelperLifecycle(record: record, candidate: { throw ServiceFailure.untrustedIdentity },
                                            recordPresent: { false }, helperAbsent: { true },
                                            administrator: { _ in .success("") })
        let removed = try await gone.status()
        guard case .absent = removed else { return XCTFail("pins, files and process gone is absence") }
        let lingering = ProtectedHelperLifecycle(record: record, candidate: { throw ServiceFailure.untrustedIdentity },
                                                 recordPresent: { false }, helperAbsent: { false },
                                                 administrator: { _ in .success("") })
        let unproven = try await lingering.status()
        guard case .unknown = unproven else { return XCTFail("missing pins alone are not absence") }
    }

    func testHelperExplanationSaysWhatTheHelperIsFor() {
        let text = HelperPurpose.explanation
        for needed in ["CPU", "GPU", "Neural Engine", "administrator access", "password", "updates"] {
            XCTAssertTrue(text.contains(needed), "explanation should mention \(needed)")
        }
        for banned in ["\u{2014}", "Developer ID", "code hash", "launchd", "cdhash", "daemon"] {
            XCTAssertFalse(text.contains(banned), "explanation should not contain \(banned)")
        }
    }

    func testFailedInstallAlwaysEndsWithAMessage() async {
        for (failure, expected) in [
            (ServiceFailure.timedOut, "Installing the helper took too long, so Watt? stopped waiting. Try again."),
            (.cancelled, "Helper installation was cancelled."),
            (.adminRequired, "Watt? couldn’t install the helper. Try again."),
            (.unknownStatus, "Watt? couldn’t install the helper. Try again.")
        ] {
            let setup = SettingsHelperSetup()
            setup.unavailableReason = .installationRequired
            setup.installHelper = { failure }
            let result = await setup.installFromInterface()
            XCTAssertEqual(result, failure)
            XCTAssertFalse(setup.isInstalling, "the install button comes back after \(failure)")
            XCTAssertEqual(setup.installResult, expected)
            XCTAssertEqual(setup.message, expected)
        }
    }

    func testHelperIsOnlyCalledNotInstalledWhenNothingOfItIsThere() {
        XCTAssertEqual(HelperInstallPresence.detect(pinsPresent: false, journalPresent: false, helperPresent: false), .notInstalled)
        // An install that stopped part way leaves its journal and maybe the helper file.
        XCTAssertEqual(HelperInstallPresence.detect(pinsPresent: false, journalPresent: true, helperPresent: false), .unfinished)
        XCTAssertEqual(HelperInstallPresence.detect(pinsPresent: false, journalPresent: false, helperPresent: true), .unfinished)
        // A finished install that this copy can't use is set up for another copy.
        XCTAssertEqual(HelperInstallPresence.detect(pinsPresent: true, journalPresent: false, helperPresent: true), .otherCopy)
        XCTAssertEqual(HelperInstallPresence.detect(pinsPresent: true, journalPresent: true, helperPresent: true), .otherCopy)
    }

    func testSettingsAndComponentsReportTheRealHelperState() async {
        // Installed and running: on, nothing offers an install, Components are not "not installed".
        let service = FakeHelperService(); service.status = .connected
        let running = SettingsHelperSetup(service: service)
        running.installHelper = { nil }
        let prefs = PreferencesStore(storage: InMemoryStorage())
        prefs.onboarding.completed = true
        await running.turnOn(preferences: prefs)
        XCTAssertTrue(running.helperOn)
        XCTAssertEqual(running.statusTitle, "On")
        XCTAssertFalse(running.canInstallHelper)
        let runningPanel = StatusPanelModel(reading: .sampleChargedOnAdapter, componentsNeedInstall: running.canInstallHelper,
                                            componentsInstallSubtitle: running.componentsInstallSubtitle)
        XCTAssertEqual(runningPanel.unavailableComponentsSubtitle, "Unavailable")
        XCTAssertNotEqual(runningPanel.unavailableComponentsValue, "Install")

        // Installed, but for a different copy of Watt?: say so and keep the install that moves it to this copy.
        let other = SettingsHelperSetup()
        other.unavailableReason = .installationRequired
        other.installHelper = { nil }
        other.installPresence = .otherCopy
        XCTAssertEqual(other.statusTitle, "Other copy")
        XCTAssertEqual(other.statusSubtitle, "The helper is set up for a different copy of Watt?. Install it again to use it with this copy.")
        XCTAssertTrue(other.canInstallHelper)
        let otherPanel = StatusPanelModel(reading: .sampleChargedOnAdapter, componentsNeedInstall: other.canInstallHelper,
                                          componentsInstallSubtitle: other.componentsInstallSubtitle)
        XCTAssertEqual(otherPanel.unavailableComponentsSubtitle, "Helper set up for another copy")
        XCTAssertFalse(otherPanel.unavailableComponentsSubtitle.contains("not installed"))

        // An install that stopped part way is not "not installed" either.
        other.installPresence = .unfinished
        XCTAssertEqual(other.statusTitle, "Not finished")
        XCTAssertEqual(other.componentsInstallSubtitle, "Helper setup didn’t finish")

        // Not installed at all.
        let absent = SettingsHelperSetup()
        absent.unavailableReason = .installationRequired
        absent.installHelper = { nil }
        XCTAssertEqual(absent.statusTitle, "Not installed")
        XCTAssertEqual(absent.statusSubtitle, "Watt? Helper isn’t installed.")
        XCTAssertEqual(StatusPanelModel(reading: .sampleChargedOnAdapter, componentsNeedInstall: true,
                                        componentsInstallSubtitle: absent.componentsInstallSubtitle).unavailableComponentsSubtitle,
                       "Helper not installed")
    }

    func testFailedInstallRechecksWhatIsOnThisMac() async {
        let setup = SettingsHelperSetup()
        setup.unavailableReason = .installationRequired
        setup.installHelper = { .adminRequired }
        setup.presenceProbe = { .unfinished }
        XCTAssertEqual(setup.statusTitle, "Not installed")
        _ = await setup.installFromInterface()
        XCTAssertEqual(setup.installPresence, .unfinished)
        XCTAssertEqual(setup.statusTitle, "Not finished")
    }

    func testInstallToolThatNeverFinishesIsStoppedAtTheTimeout() async {
        let started = Date()
        let run = HelperBundleInstall.execute("/bin/sleep", ["30"], timeout: 0.5)
        XCTAssertEqual(run, .timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
        let direct = await Task.detached {
            HelperBundleInstall.runDirect(.init(executable: "/bin/sleep", arguments: ["30"], privileged: false), timeout: 0.5)
        }.value
        XCTAssertEqual(direct, .failure(.timedOut))
        XCTAssertEqual(HelperBundleInstall.execute("/bin/echo", ["Approval: ok"], timeout: 10),
                       .exited(status: 0, output: "Approval: ok\n", errors: ""))
        XCTAssertEqual(HelperBundleInstall.execute("/nonexistent/tool", [], timeout: 1), .launchFailed)
    }

    func testAdministratorPromptOutcomesMapToDistinctFailures() {
        XCTAssertEqual(HelperBundleInstall.privilegedOutcome(.exited(status: 0, output: "Installed\n", errors: "")), .success("Installed\n"))
        XCTAssertEqual(HelperBundleInstall.privilegedOutcome(.exited(status: 1, output: "", errors: "execution error: User canceled. (-128)")),
                       .failure(.cancelled))
        XCTAssertEqual(HelperBundleInstall.privilegedOutcome(.exited(status: 1, output: "", errors: "execution error: interrupted (1)")),
                       .failure(.adminRequired))
        XCTAssertEqual(HelperBundleInstall.privilegedOutcome(.timedOut), .failure(.timedOut))
        XCTAssertEqual(HelperBundleInstall.privilegedOutcome(.launchFailed), .failure(.unknownStatus))
        XCTAssertGreaterThanOrEqual(HelperBundleInstall.administratorTimeout, 120, "the password prompt needs time")
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
