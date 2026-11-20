import XCTest
@testable import Watt

@MainActor
final class AppIntentsTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await WattIntentSession.resetForTests()
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
        let entity = GetPowerReadingIntent.entity(from: reading)
        XCTAssertEqual(entity.id, "current")
        XCTAssertEqual(entity.systemDrawWatts, 22.9)
        XCTAssertEqual(entity.chargerWatts, 65)
        XCTAssertEqual(entity.batteryPercentage, 64)
        XCTAssertEqual(entity.summary, "System draw 22.9 W, charger 65.0 W, battery 64%, Charging.")
        _ = try await GetPowerReadingIntent().perform()
        let resolved = try await WattPowerReadingQuery().entities(for: ["current"])
        XCTAssertEqual(resolved.first?.summary, entity.summary)
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
        let resolved = try await WattPowerReadingQuery().entities(for: ["unavailable"])
        XCTAssertEqual(resolved.first?.summary, WattPowerReading.unavailableLabel)
        XCTAssertNil(resolved.first?.systemDrawWatts)
        XCTAssertNil(resolved.first?.chargerWatts)
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

    func testUpdateIntentCallsTheManualCheckAndDoesNotInstall() async throws {
        let service = IntentUpdateSpy()
        let router = AppRouter(updateService: service)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var removals = 0
        router.removeFromSettings = { _ in
            removals += 1
            return .failed(.unknownStatus)
        }
        install(router: router)
        WattIntentSession.notePresenterReady()
        _ = try await CheckForUpdatesIntent().perform()
        XCTAssertEqual(routes, [.softwareUpdate])
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(service.initiators, [.manual])
        XCTAssertEqual(service.downloads, 0)
        XCTAssertEqual(service.installs, 0)
        XCTAssertEqual(router.updates.state, .idle)
        XCTAssertEqual(removals, 0)
        XCTAssertFalse(CheckForUpdatesIntent.openAppWhenRun)
    }

    func testUpdateIntentReturnsTheDialogBeforeTheCheckFinishes() async throws {
        let service = SuspendedUpdateSpy()
        let router = AppRouter(updateService: service)
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        install(router: router)
        WattIntentSession.notePresenterReady()
        defer { service.resume() }
        let outcome = try WattIntentSession.checkForUpdates()
        XCTAssertTrue(outcome.started)
        XCTAssertEqual(outcome.message, "Checking for updates.")
        XCTAssertEqual(routes, [.softwareUpdate])
        XCTAssertEqual(router.updates.state, .checking)
        XCTAssertEqual(service.downloads, 0)
        XCTAssertEqual(service.installs, 0)
    }

    func testActionsRunInTheOpenProcessWithoutAForegroundLaunch() {
        for openAppWhenRun in [
            GetPowerReadingIntent.openAppWhenRun, OpenStatusPanelIntent.openAppWhenRun,
            OpenSettingsIntent.openAppWhenRun, SetMenuBarDisplayIntent.openAppWhenRun,
            CheckForUpdatesIntent.openAppWhenRun
        ] {
            XCTAssertFalse(openAppWhenRun)
        }
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            for modes in [
                GetPowerReadingIntent.supportedModes, OpenStatusPanelIntent.supportedModes,
                OpenSettingsIntent.supportedModes, SetMenuBarDisplayIntent.supportedModes,
                CheckForUpdatesIntent.supportedModes
            ] {
                XCTAssertEqual(modes, .background)
            }
        }
        if #available(macOS 27, *) {
            for targets in [
                GetPowerReadingIntent.allowedExecutionTargets, OpenStatusPanelIntent.allowedExecutionTargets,
                OpenSettingsIntent.allowedExecutionTargets, SetMenuBarDisplayIntent.allowedExecutionTargets,
                CheckForUpdatesIntent.allowedExecutionTargets
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
        XCTAssertEqual(WattIntentSession.decision(for: nil, hasAppleEvent: false), .showSettings)
        XCTAssertEqual(WattIntentSession.decision(for: "com.apple.launchservicesd", hasAppleEvent: true), .waitForIntent)

        let delegate = WattApplicationDelegate()
        var shown = 0
        delegate.onReopen = { shown += 1 }
        defer { delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification)) }
        WattIntentSession.reopenHasAppleEvent = { false }
        WattIntentSession.reopenSenderLookup = { nil }

        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 1)

        WattIntentSession.reopenHasAppleEvent = { true }
        WattIntentSession.reopenSenderLookup = { "com.apple.shortcuts" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 1)

        _ = try await GetPowerReadingIntent().perform()
        WattIntentSession.reopenSenderLookup = { "com.apple.launchservicesd" }
        WattIntentSession.handleReopen { shown += 1 }
        XCTAssertEqual(shown, 1)

        WattIntentSession.reopenSenderLookup = { "com.apple.finder" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(shown, 2)

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

    func testUpdateIntentWithoutAServiceDoesNotInventACheck() async throws {
        let router = AppRouter()
        install(router: router)
        let outcome = try WattIntentSession.checkForUpdates()
        XCTAssertFalse(outcome.started)
        XCTAssertEqual(outcome.message, "Updates aren’t configured in this build.")
        XCTAssertEqual(router.updates.state, .idle)
        _ = try await CheckForUpdatesIntent().perform()
        XCTAssertEqual(router.updates.state, .idle)
    }

    func testReopenDoesNotOpenSettingsWhileAnIntentIsRunning() {
        let delegate = WattApplicationDelegate()
        var reopens = 0
        delegate.onReopen = { reopens += 1 }
        WattIntentSession.reopenSenderLookup = { nil }
        WattIntentSession.reopenHasAppleEvent = { false }

        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 1)

        WattIntentSession.beginIntentHandling()
        XCTAssertFalse(WattIntentSession.shouldPresentOnReopen)
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 1)

        WattIntentSession.endIntentHandling()
        XCTAssertTrue(WattIntentSession.shouldPresentOnReopen)
        // The reopen that follows an action is still inside the quiet window.
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 1)

        WattIntentSession.reopenSenderLookup = { "com.apple.shortcuts" }
        WattIntentSession.reopenHasAppleEvent = { true }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 1)

        WattIntentSession.reopenSenderLookup = { "com.apple.finder" }
        XCTAssertFalse(delegate.applicationShouldHandleReopen(.shared, hasVisibleWindows: false))
        XCTAssertEqual(reopens, 2)
    }

    func testMissingSessionFailsClosed() async {
        assertUnavailable(WattIntentSession.currentReading())
        await XCTAssertThrowsErrorAsync(try WattIntentSession.setDisplayMode(.draw), WattIntentFailure.notRunning)
        await XCTAssertThrowsErrorAsync(try WattIntentSession.open(.settings), WattIntentFailure.notRunning)
        await XCTAssertThrowsErrorAsync(try WattIntentSession.checkForUpdates(), WattIntentFailure.notRunning)
    }

    func testShortcutSurfaceDoesNotExposeHelperOrBypassVerification() throws {
        XCTAssertEqual(WattShortcuts.appShortcuts.count, 5)
        XCTAssertFalse(GetPowerReadingIntent.openAppWhenRun)
        XCTAssertFalse(OpenStatusPanelIntent.openAppWhenRun)
        XCTAssertFalse(OpenSettingsIntent.openAppWhenRun)
        XCTAssertFalse(SetMenuBarDisplayIntent.openAppWhenRun)
        XCTAssertFalse(CheckForUpdatesIntent.openAppWhenRun)
        let root = repoRoot()
        let folder = root.appendingPathComponent("Features/Intents")
        let sources = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(sources.map(\.lastPathComponent), ["WattAppIntents.swift", "WattIntentSession.swift"])
        let source = try sources.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        XCTAssertTrue(source.contains("checkForUpdatesNow"))
        XCTAssertTrue(source.contains("WattIntentSession.checkForUpdates()"))
        XCTAssertTrue(source.contains("Checking for updates."))
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
        XCTAssertTrue(exercise.contains("Check for"))
        XCTAssertTrue(exercise.contains("no Dock icon"))
        XCTAssertFalse(exercise.contains("install the helper"))
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
        let entity = GetPowerReadingIntent.entity(from: reading)
        XCTAssertFalse(entity.available, file: file, line: line)
        XCTAssertNil(entity.systemDrawWatts, file: file, line: line)
        XCTAssertNil(entity.chargerWatts, file: file, line: line)
        XCTAssertNil(entity.batteryPercentage, file: file, line: line)
        XCTAssertEqual(entity.summary, WattPowerReading.unavailableLabel, file: file, line: line)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
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

@MainActor
private final class SuspendedUpdateSpy: UpdateService {
    var downloads = 0
    var installs = 0
    private var resumed = false
    private var continuation: CheckedContinuation<ServiceOutcome<String?>, Never>?

    func check() async -> ServiceOutcome<String?> { await check(initiator: .automatic) }

    func check(initiator: UpdateCheckInitiator) async -> ServiceOutcome<String?> {
        if resumed { return .success(nil) }
        return await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        resumed = true
        continuation?.resume(returning: .success(nil))
        continuation = nil
    }

    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        downloads += 1
        return .failure(.unknownStatus)
    }

    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        installs += 1
        return .failure(.unknownStatus)
    }

    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}

@MainActor
private final class IntentUpdateSpy: UpdateService {
    var initiators: [UpdateCheckInitiator] = []
    var downloads = 0
    var installs = 0

    func check() async -> ServiceOutcome<String?> {
        initiators.append(.automatic)
        return .success(nil)
    }

    func check(initiator: UpdateCheckInitiator) async -> ServiceOutcome<String?> {
        initiators.append(initiator)
        return .success(nil)
    }

    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        downloads += 1
        return .failure(.unknownStatus)
    }

    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        installs += 1
        return .failure(.unknownStatus)
    }

    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
