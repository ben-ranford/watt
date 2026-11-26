import XCTest
@testable import Watt

@MainActor
final class AppIntentsTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await WattIntentSession.resetForTests()
        WattIntentHost.registerIfNeeded()
    }

    override func tearDown() async throws {
        await WattIntentSession.resetForTests()
        try await super.tearDown()
    }

    func testFreshReadingMatchesThePanelAndDoesNotSample() async throws {
        let telemetry = CountingTelemetry()
        let clock = FakeWattClock(now: PowerReading.sampleCharging.timestamp)
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, telemetry: telemetry)
        install(store: store)
        let reading = WattIntentSession.currentReading()
        XCTAssertTrue(reading.available)
        XCTAssertEqual(reading.systemDrawWatts, 22.9)
        XCTAssertEqual(reading.chargerWatts, 65)
        XCTAssertEqual(reading.batteryPercentage, 64)
        XCTAssertEqual(reading.batteryState, "Charging")
        XCTAssertEqual(reading.summary(), "System draw 22.9 W, charger 65.0 W, battery 64%, Charging.")
        _ = try await GetPowerReadingIntent().perform()
        XCTAssertEqual(telemetry.samples, 0)
        XCTAssertFalse(store.isRefreshing)
    }

    func testStaleReadingIsUnavailableRatherThanZero() async throws {
        let telemetry = CountingTelemetry()
        let clock = FakeWattClock(now: PowerReading.sampleCharging.timestamp)
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, telemetry: telemetry)
        install(store: store)
        clock.advance(by: PowerReadingStore.statusMaximumAge + 0.01)
        assertUnavailable(WattIntentSession.currentReading())
        _ = try await GetPowerReadingIntent().perform()
        XCTAssertEqual(telemetry.samples, 0)
    }

    func testUnavailableAndMarkedStaleSamplesDoNotBecomeZeroWatts() async throws {
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock())
        install(store: store)
        assertUnavailable(WattIntentSession.currentReading())
        _ = try await GetPowerReadingIntent().perform()

        let stale = PowerReading(mode: .charging, watts: 42.1, batteryPercentage: 64,
                                 timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                 batteryState: .charging,
                                 capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                                 freshness: .stale, source: .system, chargerWatts: 65, systemWatts: 22.9)
        assertUnavailable(WattPowerReading.make(from: stale))

        let zeros = PowerReading(mode: .noReading, watts: 0, batteryPercentage: 0,
                                 timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                 batteryState: .unknown,
                                 capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                                 freshness: .unavailable, source: .unavailable, chargerWatts: 0, systemWatts: 0)
        assertUnavailable(WattPowerReading.make(from: zeros))
        let storedZeros = PowerReadingStore(currentReading: zeros, clock: FakeWattClock(now: zeros.timestamp))
        install(store: storedZeros)
        assertUnavailable(WattIntentSession.currentReading())
    }

    func testDisconnectedChargerStaysUnmeasuredAndARealZeroIsKept() async throws {
        let unplugged = PowerReading(mode: .onBattery, watts: -18.4, batteryPercentage: 64,
                                     timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                     batteryState: .discharging,
                                     capabilities: .init(battery: .available, charger: .disconnected, systemDraw: .available),
                                     freshness: .fresh, source: .fixture, systemWatts: 18.4)
        let reading = WattPowerReading.make(from: unplugged)
        XCTAssertTrue(reading.available)
        XCTAssertEqual(reading.systemDrawWatts, 18.4)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertEqual(reading.batteryPercentage, 64)
        XCTAssertEqual(reading.batteryState, "On battery")
        XCTAssertEqual(reading.summary(), "System draw 18.4 W, charger Unavailable, battery 64%, On battery.")

        let idle = PowerReading(mode: .systemDraw, watts: nil,
                                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                batteryState: .noBattery,
                                capabilities: .init(battery: .unsupported, charger: .unsupported, systemDraw: .available),
                                freshness: .fresh, source: .fixture, systemWatts: 0)
        let zero = WattPowerReading.make(from: idle)
        XCTAssertEqual(zero.systemDrawWatts, 0)
        XCTAssertNil(zero.chargerWatts)
        XCTAssertNil(zero.batteryPercentage)
        XCTAssertEqual(zero.batteryState, "No battery")
        XCTAssertEqual(zero.summary(), "System draw 0.0 W, charger Unavailable, battery Unavailable, No battery.")

        let idleOnAC = PowerReading(mode: .chargerInput, watts: 0, batteryPercentage: 80,
                                    detail: "Power source: AC",
                                    timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                    batteryState: .unknown,
                                    capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                                    freshness: .fresh, source: .system, chargerWatts: 24, systemWatts: 18)
        XCTAssertEqual(StatusPanelModel(reading: idleOnAC).title, "Not charging")
        let ac = WattPowerReading.make(from: idleOnAC)
        XCTAssertEqual(ac.batteryState, "Not charging")
        XCTAssertEqual(ac.systemDrawWatts, 18)
        XCTAssertEqual(ac.chargerWatts, 24)
        XCTAssertEqual(ac.batteryPercentage, 80)
        XCTAssertEqual(ac.summary(), "System draw 18.0 W, charger 24.0 W, battery 80%, Not charging.")

        let unclassified = PowerReading(mode: .chargerInput, watts: nil,
                                        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                        batteryState: .unknown,
                                        capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                                        freshness: .fresh, source: .system, chargerWatts: 10, systemWatts: 10)
        XCTAssertEqual(WattPowerReading.make(from: unclassified).batteryState, "Unknown")
        let idleStore = PowerReadingStore(currentReading: idle, clock: FakeWattClock(now: idle.timestamp))
        install(store: idleStore)
        XCTAssertEqual(WattIntentSession.currentReading().systemDrawWatts, 0)
        _ = try await GetPowerReadingIntent().perform()
        XCTAssertEqual(WattIntentSession.currentReading().systemDrawWatts, 0)
        XCTAssertFalse(WattIntentSession.isPerformingIntent)
    }

    func testDisplayModeIntentWritesEveryExistingMode() async throws {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        let router = AppRouter()
        var removals = 0
        router.removeFromSettings = { _ in
            removals += 1
            return .failed(.unknownStatus)
        }
        WattIntentSession.install(router: router, readings: PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock()),
                                  preferences: preferences)
        XCTAssertEqual(Set(WattMenuBarDisplay.allCases.map(\.displayMode)), Set(WattDisplayMode.allCases))
        for mode in WattDisplayMode.allCases {
            XCTAssertEqual(WattMenuBarDisplay(mode).displayMode, mode)
            let title = try SetMenuBarDisplayIntent.apply(WattMenuBarDisplay(mode))
            XCTAssertEqual(title, mode.title)
            XCTAssertEqual(preferences.displayMode, mode)
            XCTAssertEqual(PreferencesStore(storage: storage).displayMode, mode)
            let stored = try JSONSerialization.jsonObject(with: XCTUnwrap(storage.values["preferences.v1"])) as? [String: Any]
            XCTAssertEqual(stored?["displayMode"] as? String, mode.rawValue)
            let choice = WattMenuBarDisplay(mode)
            if choice.rawValue != mode.rawValue {
                XCTAssertNotEqual(stored?["displayMode"] as? String, choice.rawValue)
            }
            let label = MenuBarStatusLabel(reading: .unavailable, preferences: preferences)
            XCTAssertEqual(label.text == nil, mode == .iconOnly)
        }
        XCTAssertEqual(removals, 0)
        XCTAssertFalse(SetMenuBarDisplayIntent.openAppWhenRun)
    }

    func testOpeningIntentsUseTheRouterAndCanWaitForThePresenter() async throws {
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var activations = 0
        install(router: router)
        WattIntentSession.activateForIntent = { activations += 1 }
        XCTAssertFalse(OpenStatusPanelIntent.openAppWhenRun)
        XCTAssertFalse(OpenSettingsIntent.openAppWhenRun)
        try WattIntentSession.open(.statusPanel)
        XCTAssertTrue(routes.isEmpty)
        WattIntentSession.notePresenterReady()
        XCTAssertEqual(routes, [.statusPanel])

        routes.removeAll()
        _ = try await OpenStatusPanelIntent().perform()
        XCTAssertEqual(routes, [.statusPanel])

        routes.removeAll()
        router.statusPanelPresented = true
        _ = try await OpenStatusPanelIntent().perform()
        XCTAssertEqual(routes, [.statusPanel])
        XCTAssertTrue(router.statusPanelPresented)

        routes.removeAll()
        _ = try await OpenSettingsIntent().perform()
        XCTAssertEqual(routes, [.settings])
        XCTAssertGreaterThan(activations, 0)
    }

    func testActionsRunInTheOpenProcessWithoutAForegroundLaunch() {
        for openAppWhenRun in [
            GetPowerReadingIntent.openAppWhenRun, OpenStatusPanelIntent.openAppWhenRun,
            OpenSettingsIntent.openAppWhenRun, SetMenuBarDisplayIntent.openAppWhenRun
        ] {
            XCTAssertFalse(openAppWhenRun)
        }
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            for modes in [
                GetPowerReadingIntent.supportedModes, OpenStatusPanelIntent.supportedModes,
                OpenSettingsIntent.supportedModes, SetMenuBarDisplayIntent.supportedModes
            ] {
                XCTAssertEqual(modes, .background)
            }
        }
        if #available(macOS 27, *) {
            for targets in [
                GetPowerReadingIntent.allowedExecutionTargets, OpenStatusPanelIntent.allowedExecutionTargets,
                OpenSettingsIntent.allowedExecutionTargets, SetMenuBarDisplayIntent.allowedExecutionTargets
            ] {
                XCTAssertEqual(targets, .main)
            }
        }
        #endif
    }

    func testShortcutReopenDoesNotOpenSettingsAndFinderStillDoes() async throws {
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.shortcuts", hasAppleEvent: true), .suppress)
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.shortcuts.events", hasAppleEvent: true), .suppress)
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.linkd", hasAppleEvent: true), .suppress)
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.finder", hasAppleEvent: true), .showSettings)
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false, frontmost: "com.apple.shortcuts"), .suppress)
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false, frontmost: "com.apple.finder"), .showSettings)
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false, frontmost: Bundle.main.bundleIdentifier), .waitForIntent)
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false), .waitForIntent)
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.launchservicesd", hasAppleEvent: true), .waitForIntent)

        let delegate = WattApplicationDelegate()
        var shown = 0
        delegate.onReopen = { shown += 1 }
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        WattIntentSession.reopenQuietNanoseconds = 60_000_000_000
        WattIntentSession.reopenHasAppleEvent = { false }
        WattIntentSession.reopenSenderLookup = { nil }

        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 0)

        WattIntentSession.reopenHasAppleEvent = { true }
        WattIntentSession.reopenSenderLookup = { "com.apple.shortcuts" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 0)

        _ = try await GetPowerReadingIntent().perform()
        WattIntentSession.reopenSenderLookup = { "com.apple.launchservicesd" }
        WattIntentSession.handleReopen { shown += 1 }
        XCTAssertEqual(shown, 0)

        WattIntentSession.reopenSenderLookup = { "com.apple.finder" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 1)

        WattIntentSession.reopenQuietNanoseconds = 0
        WattIntentSession.beginIntent()
        WattIntentSession.endIntent()
        WattIntentSession.reopenQuietNanoseconds = 50_000_000
        WattIntentSession.reopenHasAppleEvent = { true }
        WattIntentSession.reopenSenderLookup = { "com.apple.launchservicesd" }
        var deferred = 0
        WattIntentSession.handleReopen { deferred += 1 }
        XCTAssertEqual(deferred, 0)
        WattIntentSession.beginIntent()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(deferred, 0)
        WattIntentSession.endIntent()
    }

    func testFinderReopenWithoutASenderOpensSettingsAfterTheQuietWait() async {
        var shown = 0
        WattIntentSession.reopenQuietNanoseconds = 20_000_000
        WattIntentSession.reopenHasAppleEvent = { false }
        WattIntentSession.reopenSenderLookup = { nil }
        WattIntentSession.frontmostBundleIdentifier = { nil }
        WattIntentSession.handleReopen { shown += 1 }
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false, frontmost: nil), .waitForIntent)
        XCTAssertEqual(shown, 0)
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(shown, 1)
    }

    func testOpenStatusPanelShowsThePopoverAndLeavesItOpen() throws {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.onboarding.checkpoint = .runningDefaults
        let store = PowerReadingStore(currentReading: .sampleCharging,
                                      clock: FakeWattClock(now: PowerReading.sampleCharging.timestamp))
        let router = AppRouter()
        let delegate = WattApplicationDelegate()
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        delegate.installFallbackStatusItem(router: router, powerStore: store, preferences: preferences)
        install(store: store, router: router, preferences: preferences)
        WattIntentSession.notePresenterReady()
        try WattIntentSession.open(.statusPanel)
        XCTAssertTrue(router.statusPanelPresented)
        try WattIntentSession.open(.statusPanel)
        XCTAssertTrue(router.statusPanelPresented)
    }

    func testStatusPanelRetriesUntilTheButtonIsOnScreen() {
        XCTAssertEqual(StatusPanelShowPlan.beforeShow(hasButton: false, buttonOnScreen: false, mayRetry: true), .retry)
        XCTAssertEqual(StatusPanelShowPlan.beforeShow(hasButton: true, buttonOnScreen: false, mayRetry: true), .retry)
        XCTAssertEqual(StatusPanelShowPlan.beforeShow(hasButton: true, buttonOnScreen: true, mayRetry: false), .show)
        XCTAssertEqual(StatusPanelShowPlan.beforeShow(hasButton: false, buttonOnScreen: false, mayRetry: false), .unavailable)
        XCTAssertEqual(StatusPanelShowPlan.afterShow(shown: false, mayRetry: true), .retry)
        XCTAssertEqual(StatusPanelShowPlan.afterShow(shown: true, mayRetry: false), .show)
        XCTAssertEqual(StatusPanelShowPlan.afterShow(shown: false, mayRetry: false), .unavailable)
    }

    func testReopenDoesNotOpenSettingsWhileAnIntentIsRunning() {
        let delegate = WattApplicationDelegate()
        var reopens = 0
        delegate.onReopen = { reopens += 1 }
        WattIntentSession.reopenQuietNanoseconds = 60_000_000_000
        WattIntentSession.reopenHasAppleEvent = { false }
        WattIntentSession.reopenSenderLookup = { nil }

        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 0)

        WattIntentSession.beginIntentHandling()
        XCTAssertFalse(WattIntentSession.shouldPresentOnReopen)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 0)

        WattIntentSession.endIntentHandling()
        XCTAssertTrue(WattIntentSession.shouldPresentOnReopen)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 0)

        WattIntentSession.reopenSenderLookup = { "com.apple.shortcuts" }
        WattIntentSession.reopenHasAppleEvent = { true }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 0)

        WattIntentSession.reopenSenderLookup = { "com.apple.finder" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 1)
    }

    func testMissingSessionFailsClosed() async {
        assertUnavailable(WattIntentSession.currentReading())
        await XCTAssertThrowsErrorAsync(try WattIntentSession.setDisplayMode(.draw), WattIntentFailure.notRunning)
        await XCTAssertThrowsErrorAsync(try WattIntentSession.open(.settings), WattIntentFailure.notRunning)
    }

    func testShortcutSurfaceDoesNotExposeHelperOrBypassVerification() throws {
        XCTAssertEqual(WattShortcuts.appShortcuts.count, 4)
        XCTAssertFalse(GetPowerReadingIntent.openAppWhenRun)
        XCTAssertFalse(OpenStatusPanelIntent.openAppWhenRun)
        XCTAssertFalse(OpenSettingsIntent.openAppWhenRun)
        XCTAssertFalse(SetMenuBarDisplayIntent.openAppWhenRun)
        let root = repoRoot()
        let folder = root.appendingPathComponent("Features/Intents")
        let sources = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(sources.map(\.lastPathComponent), ["WattAppIntents.swift", "WattIntentSession.swift"])
        let source = try sources.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        XCTAssertFalse(source.contains("CheckForUpdatesIntent"))
        XCTAssertFalse(source.contains("checkForUpdates"))
        XCTAssertTrue(source.contains("hasCurrentSample"))
        XCTAssertTrue(source.contains("NSApp.activate(ignoringOtherApps: true)"))
        XCTAssertTrue(source.contains("NSApp.setActivationPolicy(.accessory)"))
        XCTAssertTrue(source.contains("openAppWhenRun"))
        XCTAssertFalse(source.contains("openAppWhenRun: Bool { true }"))
        XCTAssertTrue(source.contains("supportedModes"))
        XCTAssertTrue(source.contains(".background"))
        XCTAssertTrue(source.contains("allowedExecutionTargets"))
        XCTAssertTrue(source.contains(".main"))
        XCTAssertTrue(source.contains("preferences.v1"))
        XCTAssertTrue(source.contains("shouldPresentOnReopen"))
        XCTAssertTrue(source.contains("handlingIntent"))
        for forbidden in ["installHelper", "removeFromSettings", "URLSession", "confirmInstall",
                          "register(receipt", "powermetrics", "runSampling", "refresh(", "URLRequest"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        let app = try String(contentsOf: root.appendingPathComponent("App/WattApp.swift"), encoding: .utf8)
        XCTAssertTrue(app.contains("WattIntentSession.install"))
        XCTAssertTrue(app.contains("WattIntentSession.connectToShortcuts()"))
        XCTAssertTrue(app.contains("WattIntentSession.handleReopen"))
        XCTAssertTrue(app.contains("self?.showPanel()"))
        XCTAssertEqual(app.components(separatedBy: "WattIntentSession.notePresenterReady()").count - 1, 2)
        XCTAssertFalse(app.contains("AppIntent"))
        XCTAssertFalse(app.contains("AppShortcut"))
        let exercise = try String(contentsOf: root.appendingPathComponent("docs/shortcuts.md"), encoding: .utf8)
        XCTAssertTrue(exercise.contains("Unavailable"))
        XCTAssertTrue(exercise.contains("Get Power Reading"))
        XCTAssertTrue(exercise.contains("Open Status Panel"))
        XCTAssertTrue(exercise.contains("Open Settings"))
        XCTAssertTrue(exercise.contains("Set Menu Bar Display"))
        XCTAssertTrue(exercise.contains("may not exit"))
        XCTAssertFalse(exercise.contains("Check for Updates"))
        XCTAssertTrue(exercise.contains("no Dock icon"))
        XCTAssertFalse(exercise.contains("install the helper"))
        XCTAssertTrue(exercise.contains("log stream --level debug --style compact --predicate 'subsystem == \"io.github.ben-ranford.watt\" AND category == \"intents\"'"))
        XCTAssertTrue(source.contains("AppDependencyManager.shared.add"))
        XCTAssertTrue(source.contains("io.github.ben-ranford.watt"))
        XCTAssertTrue(source.contains("category: \"intents\""))
        let claim = try String(contentsOf: root.appendingPathComponent("Services/UpdateRelaunchLifecycle.swift"), encoding: .utf8)
        XCTAssertTrue(claim.contains("deferredForIntent"))
        XCTAssertTrue(claim.contains("intentLaunch"))
        XCTAssertTrue(app.contains("WattIntentSession.finishLaunchClaim()"))
        XCTAssertFalse(source.contains("com.apple.runningboard"))
    }

    func testIntentDispatcherCannotQuitTheMenuBarProcess() {
        let delegate = WattApplicationDelegate()
        WattIntentSession.reopenSenderLookup = { "com.apple.linkd" }
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateCancel)
        WattIntentSession.reopenSenderLookup = { "com.apple.shortcuts" }
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateCancel)
        WattIntentSession.reopenSenderLookup = { nil }
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)
        WattIntentSession.reopenSenderLookup = { "com.apple.finder" }
        XCTAssertEqual(delegate.applicationShouldTerminate(.shared), .terminateNow)
    }

    func testIntentLaunchLeavesTheRunningInstanceInPlace() async {
        let probe = ClaimProbe()
        prepareClaim(probe)
        WattIntentSession.otherInstances = { [20, 21] }
        WattIntentSession.launchSignal = {
            WattIntentLaunchSignal(parentPID: 8, parentBundleIdentifier: "com.apple.linkd", eventSenderBundleIdentifier: nil)
        }
        await WattIntentSession.finishLaunchClaim()
        XCTAssertEqual(WattIntentSession.role, .satellite)
        XCTAssertEqual(probe.calls, 0)
        XCTAssertFalse(probe.becameKeeper)
    }

    func testSecondLaunchWithoutAnIntentStillClaims() async {
        let probe = ClaimProbe()
        prepareClaim(probe)
        WattIntentSession.otherInstances = { [20] }
        await WattIntentSession.finishLaunchClaim()
        XCTAssertEqual(WattIntentSession.role, .keeper)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(probe.becameKeeper)
    }

    func testKeeperIntentInFlightSkipsTheClaim() async {
        let probe = ClaimProbe()
        prepareClaim(probe)
        WattIntentSession.otherInstances = { [20] }
        WattIntentSession.keeperIntentInFlight = { true }
        await WattIntentSession.finishLaunchClaim()
        XCTAssertEqual(WattIntentSession.role, .satellite)
        XCTAssertEqual(probe.calls, 0)
    }

    func testOnlyInstanceBecomesTheKeeperImmediately() async {
        let probe = ClaimProbe()
        prepareClaim(probe)
        WattIntentSession.otherInstances = { [] }
        await WattIntentSession.finishLaunchClaim()
        XCTAssertEqual(WattIntentSession.role, .keeper)
        XCTAssertEqual(probe.calls, 1)
        XCTAssertTrue(probe.becameKeeper)
    }

    func testLaunchLineRecordsAnAdhocSignatureWithoutATeamID() {
        let line = WattCodeSignature.launchLine(
            pid: 42, version: "1002000", path: "/Applications/Watt.app",
            signature: WattCodeSignature.Snapshot(teamIdentifier: "none", adhoc: true, cdhash: "abcd", readable: true),
            others: [7],
            other: WattCodeSignature.Snapshot(teamIdentifier: "none", adhoc: true, cdhash: "abcd", readable: true),
            signal: WattIntentLaunchSignal(parentPID: 1, parentBundleIdentifier: "com.apple.linkd", eventSenderBundleIdentifier: nil))
        XCTAssertTrue(line.contains("pid=42"))
        XCTAssertTrue(line.contains("team=none"))
        XCTAssertTrue(line.contains("adhoc=true"))
        XCTAssertTrue(line.contains("cdhash=abcd"))
        XCTAssertTrue(line.contains("others=7"))
        XCTAssertTrue(line.contains("signatureMatch=true"))
        XCTAssertTrue(line.contains("parentBundle=com.apple.linkd"))
        XCTAssertTrue(line.contains("no Team ID"))
        XCTAssertTrue(WattIntentSession.isDispatcherLaunch(WattIntentLaunchSignal(parentPID: 9, parentBundleIdentifier: "com.apple.shortcuts", eventSenderBundleIdentifier: nil)))
        XCTAssertTrue(WattIntentSession.isDispatcherLaunch(WattIntentLaunchSignal(parentPID: 1, parentBundleIdentifier: nil, eventSenderBundleIdentifier: "com.apple.linkd")))
        XCTAssertFalse(WattIntentSession.isDispatcherLaunch(WattIntentLaunchSignal(parentPID: 1, parentBundleIdentifier: nil, eventSenderBundleIdentifier: "com.apple.finder")))
        let signed = WattCodeSignature.current()
        XCTAssertFalse(signed.cdhash.isEmpty)
    }

    func testSatelliteDoesNotInstallASecondStatusItem() {
        let router = AppRouter()
        let delegate = WattApplicationDelegate()
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        WattIntentSession.role = .satellite
        delegate.installFallbackStatusItem(router: router,
                                           powerStore: PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock()),
                                           preferences: PreferencesStore(storage: InMemoryStorage()))
        router.present(.statusPanel)
        XCTAssertFalse(router.statusPanelPresented)
    }

    func testIntentBridgeReachesTheRegisteredHost() async throws {
        let root = URL(fileURLWithPath: "/tmp/watt-intent-\(getpid())", isDirectory: true)
        WattIntentBridge.directoryOverride = root
        defer {
            WattIntentBridge.stop()
            try? FileManager.default.removeItem(at: root)
        }
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let clock = FakeWattClock(now: PowerReading.sampleCharging.timestamp)
        // The session keeps a weak reference. The test has to retain the store
        // or the bridge reads the missing-sample value, Unavailable.
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock)
        install(store: store, router: router, preferences: preferences)
        WattIntentSession.notePresenterReady()
        XCTAssertEqual(WattIntentSession.currentReading().summary(), "System draw 22.9 W, charger 65.0 W, battery 64%, Charging.")
        WattIntentBridge.startKeeper()
        let idle = try await WattIntentBridge.exchange(WattIntentRequest(action: "probe"))
        XCTAssertFalse(idle.intentInFlight)
        let reading = try await WattIntentBridge.exchange(WattIntentRequest(action: "reading"))
        XCTAssertEqual(reading.summary, "System draw 22.9 W, charger 65.0 W, battery 64%, Charging.")
        XCTAssertEqual(reading.systemDrawWatts ?? -1, 22.9, accuracy: 0.001)
        let marked = try await WattIntentBridge.exchange(WattIntentRequest(action: "probe"))
        XCTAssertTrue(marked.intentInFlight)
        WattIntentSession.intentVisibleUntil = .distantPast
        let quiet = try await WattIntentBridge.exchange(WattIntentRequest(action: "probe"))
        XCTAssertFalse(quiet.intentInFlight)
        WattIntentSession.beginIntent()
        let during = try await WattIntentBridge.exchange(WattIntentRequest(action: "probe"))
        XCTAssertTrue(during.intentInFlight)
        WattIntentSession.endIntent()
        let mode = try await WattIntentBridge.exchange(WattIntentRequest(action: "displayMode", mode: WattDisplayMode.charger.rawValue))
        XCTAssertEqual(mode.displayTitle, WattDisplayMode.charger.title)
        XCTAssertEqual(preferences.displayMode, .charger)
        let opened = try await WattIntentBridge.exchange(WattIntentRequest(action: "open", destination: "statusPanel"))
        XCTAssertTrue(opened.ok)
        XCTAssertEqual(routes, [.statusPanel])
    }

    private func prepareClaim(_ probe: ClaimProbe) {
        WattIntentSession.exitProcess = {}
        WattIntentSession.startBridge = {}
        WattIntentSession.claimDeferralNanoseconds = 0
        WattIntentSession.keeperIntentInFlight = { false }
        WattIntentSession.launchSignal = {
            WattIntentLaunchSignal(parentPID: 1, parentBundleIdentifier: nil, eventSenderBundleIdentifier: nil)
        }
        WattIntentSession.onBecameKeeper = { probe.becameKeeper = true }
        WattIntentSession.claimSingleInstance = {
            probe.calls += 1
            return SingleInstanceOutcome()
        }
    }

    private func install(store: PowerReadingStore? = nil, router: AppRouter = AppRouter(),
                         preferences: PreferencesStore = PreferencesStore(storage: InMemoryStorage())) {
        WattIntentSession.install(router: router,
                                  readings: store ?? PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock()),
                                  preferences: preferences)
        WattIntentSession.activateForIntent = {}
    }

    private func assertUnavailable(_ reading: WattPowerReading, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(reading.available, file: file, line: line)
        XCTAssertNil(reading.systemDrawWatts, file: file, line: line)
        XCTAssertNil(reading.chargerWatts, file: file, line: line)
        XCTAssertNil(reading.batteryPercentage, file: file, line: line)
        XCTAssertEqual(reading.batteryState, WattPowerReading.unavailableLabel, file: file, line: line)
        XCTAssertEqual(reading.summary(), WattPowerReading.unavailableLabel, file: file, line: line)
        XCTAssertFalse(reading.summary().contains("0"), file: file, line: line)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

@MainActor
private final class ClaimProbe {
    var calls = 0
    var becameKeeper = false
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure () async throws -> T,
                                          _ expected: WattIntentFailure,
                                          file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("Expected \(expected)", file: file, line: line)
    } catch let error as WattIntentFailure {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error \(error)", file: file, line: line)
    }
}

@MainActor
private final class CountingTelemetry: TelemetryService {
    var samples = 0
    func sample() async -> ServiceOutcome<PowerReading> {
        samples += 1
        return .failure(.disconnected)
    }
}

