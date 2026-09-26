import AppKit
import Combine
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J81NoReadingTests: XCTestCase {
    func testExactNoReadingStateCopyAndAccessibility() {
        let model = StatusPanelModel(reading: .unavailable)
        XCTAssertEqual(model.state, .noReading)
        XCTAssertEqual(model.title, "No reading")
        XCTAssertEqual(model.headlineValue, "− − W")
        XCTAssertEqual(model.subtitle, "Usually right after wake. Watt? tries again every few seconds.")
        XCTAssertEqual(model.accessibilitySummary, "No reading, Usually right after wake. Watt? tries again every few seconds.")
        XCTAssertEqual(model.summaryLabel, "No reading")
        XCTAssertFalse(model.hasReading)
        XCTAssertFalse(model.showsComponents)
        XCTAssertTrue(model.components.isEmpty)
        XCTAssertEqual([model.battery, model.charger, model.system], ["—", "—", "—"])
        XCTAssertNil(model.panelHeight, "Native Form content owns the retry panel height")
    }

    #if DEBUG || SWIFT_PACKAGE
    func testNoReadingStatusItemAndNativeSymbols() throws {
        let label = MenuBarStatusLabel(reading: .unavailable, preferences: J81FixtureLaunch.makePreferences())
        XCTAssertEqual(label.text, "− − W")
        XCTAssertEqual(label.symbolName, "bolt.fill")
        XCTAssertTrue(label.showsSymbol)
        XCTAssertEqual(label.accessibilityReading, "No reading yet")
        XCTAssertEqual(NoReadingPresentation.symbol, "exclamationmark.triangle.fill")
        for symbol in [label.symbolName, NoReadingPresentation.symbol] {
            XCTAssertTrue(try XCTUnwrap(NSImage(systemSymbolName: symbol, accessibilityDescription: nil)).isTemplate)
        }
    }

    func testExplicitNoReadingModeNeverUsesContradictoryWatts() {
        let sample = reading(mode: .noReading)
        XCTAssertFalse(sample.hasCurrentSample)
        assertNoPower(sample)
        XCTAssertEqual(MenuBarStatusLabel(reading: sample, preferences: J81FixtureLaunch.makePreferences()).text, "− − W")
    }

    func testUnavailableStaleInvalidAndPermissionConditionsFailClosed() {
        for sample in [reading(source: .unavailable), reading(freshness: .unavailable),
                       reading(freshness: .stale), reading(watts: .nan), reading(watts: .infinity),
                       reading(watts: -1), reading(percentage: 101), reading(capability: .permissionRequired),
                       reading(capability: .unknown), reading(capability: .unsupported),
                       reading(capability: .disconnected), reading(watts: nil, chargerWatts: nil, systemWatts: nil)] {
            assertNoPower(sample)
        }
    }
    #endif

    func testStatusOnlyTelemetryDoesNotPretendToMeasureWatts() {
        let sample = PowerReading(mode: .charging, watts: nil, batteryPercentage: 64,
            detail: "Power source: AC", batteryState: .charging,
            capabilities: .init(battery: .available), source: .system)
        let model = StatusPanelModel(reading: sample)
        XCTAssertEqual(model.state, .noReading)
        XCTAssertEqual(model.headlineValue, "− − W")
        XCTAssertFalse(model.accessibilitySummary.contains("64%"))
        XCTAssertFalse(model.accessibilitySummary.contains("Power source: AC"))
    }

    #if DEBUG || SWIFT_PACKAGE
    func testStaleChargingAndDesktopSamplesExpireEvenWhenAdapterSaysFresh() {
        for sample in [PowerReading.sampleCharging, .sampleChargingHold, .sampleFullOnAdapter,
                       .sampleOnBattery, .sampleInsufficientCharger, .sampleDesktopSystemDraw] {
            let clock = FakeWattClock(now: sample.timestamp)
            let store = PowerReadingStore(currentReading: sample, clock: clock)
            XCTAssertEqual(store.statusReading, sample)
            clock.advance(by: PowerReadingStore.statusMaximumAge + 0.01)
            XCTAssertEqual(store.statusReading, .unavailable)
            XCTAssertEqual(store.currentReading, sample, "Keep the diagnostic sample")
            assertNoPower(store.statusReading)
        }
    }
    #endif

    func testWakeInvalidatesOldGenerationAndImmediatelyShowsNoReading() {
        let store = PowerReadingStore.preview
        let old = store.generation
        store.handleWake()
        XCTAssertNotEqual(old, store.generation)
        XCTAssertEqual(store.currentReading, .unavailable)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertFalse(store.accept(.sampleCharging, generation: old))
        XCTAssertNil(store.failure)
        XCTAssertTrue(store.accept(.sampleCharging, generation: store.generation))
        XCTAssertEqual(store.statusReading, .sampleCharging)
    }

    #if DEBUG || SWIFT_PACKAGE
    func testRetryUsesTelemetryAndRecoversOnlyOnValidatedData() async {
        let telemetry = FakeTelemetryService(outcome: .failure(.disconnected))
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(), telemetry: telemetry)
        await store.refresh()
        XCTAssertEqual(store.failure, .disconnected)
        assertNoPower(store.statusReading)
        telemetry.outcome = .success(.unavailable)
        await store.refresh()
        assertNoPower(store.statusReading)
        telemetry.outcome = .success(.sampleCharging)
        await store.refresh()
        XCTAssertEqual(store.statusReading, .sampleCharging)
        XCTAssertNil(store.failure)
        XCTAssertFalse(store.isRefreshing)
    }

    func testRetryRejectsInvalidFutureStalePermissionAndFailedSamples() async {
        let telemetry = FakeTelemetryService()
        let clock = FakeWattClock()
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, telemetry: telemetry)
        telemetry.outcome = .failure(.denied)
        await store.refresh()
        XCTAssertEqual(store.currentReading, .sampleCharging)
        XCTAssertEqual(store.failure, .denied)
        assertNoPower(store.statusReading)
        for sample in [reading(watts: .nan), reading(timestamp: clock.now.addingTimeInterval(1)),
                       reading(freshness: .stale), reading(capability: .permissionRequired), .unavailable] {
            store.handleWake()
            telemetry.outcome = .success(sample)
            await store.refresh()
            assertNoPower(store.statusReading)
            XCTAssertFalse(store.isRefreshing)
        }
    }

    func testRetryCoalescesAndLatePreWakeResponseCannotRestorePower() async {
        let telemetry = DeferredTelemetry()
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(), telemetry: telemetry)
        let old = Task { await store.refresh() }
        await telemetry.waitForCalls(1)
        XCTAssertTrue(store.isRefreshing)
        await store.refresh()
        XCTAssertEqual(telemetry.calls, 1)
        store.handleWake()
        XCTAssertFalse(store.isRefreshing)
        let fresh = Task { await store.refresh() }
        await telemetry.waitForCalls(2)
        telemetry.finish(0, with: .success(.sampleCharging))
        await old.value
        XCTAssertTrue(store.isRefreshing, "Old request must not clear the new request's busy state")
        assertNoPower(store.statusReading)
        telemetry.finish(1, with: .failure(.denied))
        await fresh.value
        XCTAssertEqual(store.failure, .denied)
        XCTAssertFalse(store.isRefreshing)
        assertNoPower(store.statusReading)
    }

    func testDisconnectedOrCancelledRequestsCannotPublishLateResults() async {
        for disconnect in [false, true] {
            let telemetry = DeferredTelemetry()
            let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(), telemetry: telemetry)
            let task = Task { await store.refresh() }
            await telemetry.waitForCalls(1)
            if disconnect { store.disconnect() } else { task.cancel() }
            telemetry.finish(0, with: .success(.sampleCharging))
            await task.value
            assertNoPower(store.statusReading)
            XCTAssertFalse(store.isRefreshing)
        }
    }

    func testPeriodicRetryUsesSharedPathAndStopsOnCancellation() async throws {
        let telemetry = CountingTelemetry()
        let store = PowerReadingStore(currentReading: .unavailable, telemetry: telemetry)
        XCTAssertTrue(store.observesSystemWake)
        XCTAssertEqual(PowerReadingStore.retryInterval, 3)
        let task = Task { await store.runSampling() }
        defer { task.cancel() }
        for _ in 0..<80 {
            if telemetry.calls >= 2 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertGreaterThanOrEqual(telemetry.calls, 2)
        task.cancel()
        await task.value
        let calls = telemetry.calls
        await Task.yield()
        XCTAssertEqual(telemetry.calls, calls)
        assertNoPower(store.statusReading)
    }

    func testPeriodicRetryUsesProvidedSamplingInterval() async throws {
        let telemetry = CountingTelemetry()
        let store = PowerReadingStore(currentReading: .unavailable, telemetry: telemetry)
        let task = Task { await store.runSampling(interval: { 0.25 }) }
        defer { task.cancel() }
        for _ in 0..<30 {
            if telemetry.calls >= 2 { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertGreaterThanOrEqual(telemetry.calls, 2)
        task.cancel()
        await task.value
    }

    func testFiveSecondSamplingIntervalRefreshesBeforeStatusExpiry() {
        XCTAssertEqual(PowerReadingStore.samplingDelay(for: 5), 4.5, accuracy: 0.001)
        XCTAssertEqual(PowerReadingStore.samplingDelay(for: 2), 2, accuracy: 0.001)
        XCTAssertEqual(PowerReadingStore.samplingDelay(for: 0), PowerReadingStore.retryInterval, accuracy: 0.001)
        XCTAssertEqual(PowerReadingStore.samplingDelay(for: .infinity), PowerReadingStore.retryInterval, accuracy: 0.001)
    }

    func testRetryCallbackAndNativeFooterActionsPreserveRouterAndPreferences() async throws {
        let preferences = J81FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        let telemetry = CountingTelemetry()
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(), telemetry: telemetry)
        var quits = 0
        let panel = StatusPanelView(reading: store.statusReading,
            onRetry: { Task { await store.refresh() } },
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 320, height: 300),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // macOS 27 implements bordered SwiftUI Form buttons as graphics nodes,
        // not NSButtons. Verify the shared callback here; live AX press needs capture proof.
        let buttons = nativeButtons(in: host)
        XCTAssertEqual(buttons.count, 2)
        panel.onRetry()
        for _ in 0..<100 { if telemetry.calls > 0 { break }; await Task.yield() }
        XCTAssertEqual(telemetry.calls, 1)
        assertNoPower(store.statusReading)
        XCTAssertTrue(routes.isEmpty)
        let footer = buttons.filter { !$0.isBordered }.sorted {
            $0.convert($0.bounds, to: host).minX < $1.convert($1.bounds, to: host).minX
        }
        XCTAssertEqual(footer.count, 2)
        try XCTUnwrap(footer.first).performClick(nil)
        XCTAssertEqual(routes, [.settings])
        try XCTUnwrap(footer.last).performClick(nil)
        XCTAssertEqual(quits, 1)
        XCTAssertEqual(preferences.onboarding, original)
        XCTAssertEqual(preferences.displayMode, .delta)
    }
    #endif

    func testRetryDisabledDuringRefreshAndNativeAppearanceOwnsMetrics() async throws {
        for appearance in [NSAppearance.Name.darkAqua, .accessibilityHighContrastDarkAqua] {
            let host = NSHostingView(rootView: StatusPanelView(reading: .unavailable,
                isRetrying: true, onSettings: {}, onQuit: {}))
            host.appearance = NSAppearance(named: appearance)
            let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 320, height: 195),
                styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            XCTAssertEqual(host.fittingSize.width, 320)
            XCTAssertGreaterThan(host.fittingSize.height, 100)
            XCTAssertLessThan(host.fittingSize.height, 400)
            XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
            let panel = StatusPanelView(reading: .unavailable, isRetrying: true, onSettings: {}, onQuit: {})
            XCTAssertTrue(panel.isRetrying)
            let source = try source("Features/MenuBar/Views/StatusPanelView.swift")
            XCTAssertTrue(source.contains(".disabled(isRetrying)"))
            XCTAssertTrue(source.contains(".buttonStyle(.bordered)"))

        }
    }

    #if DEBUG || SWIFT_PACKAGE
    func testFixtureIsolationFrozenClockAndRetryRemainUnavailable() async {
        let first = J81FixtureLaunch.makePreferences(), second = J81FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertEqual(second.onboarding, .init(checkpoint: .livePanel, completed: true, helperOptIn: true))
        XCTAssertTrue(second.componentReadings)
        XCTAssertTrue(second.showSymbol)
        XCTAssertEqual(second.precision, .decimal)
        first.onboarding.completed = false
        first.displayMode = .iconOnly
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertEqual(second.displayMode, .delta)
        let store = J81FixtureLaunch.makeStore(), other = J81FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        XCTAssertFalse(store.observesSystemWake)
        await store.runSampling()
        await store.refresh()
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(other.statusReading, .unavailable)
        store.disconnect()
        XCTAssertNil(other.failure)
        XCTAssertEqual(J81FixtureLaunch.appearanceName, .darkAqua)
        let router = AppRouter()
        await J81FixtureLaunch.prepare(router: router)
        XCTAssertTrue(router.settingsHelperSetup.service is FakeHelperService)
        XCTAssertFalse(router.settingsHelperSetup.helperSwitchedOff)
    }

    func testExactSelectorAndReleaseCompilationBoundary() throws {
        let fixture = try ScenarioRegistry.resolve("J8.1")
        XCTAssertEqual(fixture.story.node, "32:3451")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, ["base"])
        let args = ["Watt", "--watt-fixture", "J8.1/base"]
        XCTAssertEqual(try FixtureLaunchSelection.parse(args)?.smokeLaunchArguments(), Array(args.dropFirst()))
        #if SWIFT_PACKAGE
        XCTAssertFalse(J81FixtureLaunch.matches(arguments: args))
        XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
        #else
        XCTAssertTrue(J81FixtureLaunch.matches(arguments: args))
        XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
        #endif
        for selector in ["J8.1", "J8.1/stale", "J8.1/unavailable", "J8.1/", "J8.1//base", "J8.1/base/extra", "j8.1/base"] {
            let invalid = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J81FixtureLaunch.matches(arguments: invalid))
        }
        for invalid in [["Watt", "--watt-fixture"], ["Watt", "--watt-fixture=J8.1/base"],
                        args + ["--watt-fixture", "J7.4/base"]] {
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(invalid))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: invalid))
            XCTAssertFalse(J81FixtureLaunch.matches(arguments: invalid))
        }
    }

    func testJ74AndJ6ProductionStatesRemainDistinctFromNoReading() {
        let preferences = J74FixtureLaunch.makePreferences()
        let icon = MenuBarStatusLabel(reading: .unavailable, preferences: preferences)
        XCTAssertNil(icon.text)
        XCTAssertEqual(icon.symbolName, "bolt.fill")
        XCTAssertEqual(icon.accessibilityReading, "No reading yet")
        XCTAssertTrue(icon.showsSymbol)
        for sample in [PowerReading.sampleCharging, .sampleChargingHold, .sampleFullOnAdapter,
                       .sampleInsufficientCharger, .sampleOnBattery] {
            XCTAssertFalse(StatusPanelModel(reading: sample).hasNoReading)
            XCTAssertNotEqual(StatusPanelModel(reading: sample).headlineValue, "− − W")
        }
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        router.showStatusPanel()
        XCTAssertEqual(routes, [.statusPanel])
    }

    func testValidPerComponentPanelSurvivesNoReadingRecovery() async {
        let telemetry = FakeTelemetryService(outcome: .success(.samplePerComponent))
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(), telemetry: telemetry)
        await store.refresh()
        let model = StatusPanelModel(reading: store.statusReading)
        XCTAssertEqual(model.state, .standard)
        XCTAssertEqual(model.title, "Power")
        XCTAssertEqual(model.headlineValue, "—", "Component watts do not fabricate battery watts")
        XCTAssertTrue(model.showsComponents)
        XCTAssertEqual(model.components, PowerReading.samplePerComponent.components)
        let preferences = J72FixtureLaunch.makePreferences()
        XCTAssertEqual(MenuBarStatusLabel(reading: store.statusReading, preferences: preferences).text,
                       "CPU 9.8 · GPU 4.1 W")
        store.disconnect()
        XCTAssertEqual(StatusPanelModel(reading: store.statusReading).state, .noReading)
        XCTAssertTrue(StatusPanelModel(reading: store.statusReading).components.isEmpty)
    }
    #endif

    func testNativeFormAndSharedBridgeHaveNoCustomChromeOrFixtureRenderer() throws {
        let panel = try source("Features/MenuBar/Views/StatusPanelView.swift")
        for token in ["Form {", "LabeledContent(NoReadingPresentation.retryLabel)",
                      "Button(NoReadingPresentation.retryAction, action: onRetry)", ".buttonStyle(.bordered)",
                      ".buttonStyle(.borderless)", "Image(systemName: NoReadingPresentation.symbol)",
                      "WattTypography.headline", "WattTypography.largeTitle", "WattTypography.subheadline",
                      "Button(\"Settings…\", action: onSettings)", "Button(\"Quit Watt?\", action: onQuit)"] {
            XCTAssertTrue(panel.contains(token), token)
        }
        for token in ["RoundedRectangle", "Gradient", ".background(", ".shadow(", ".tint(",
                      "Font.custom", ".position(", ".offset(", ".font(.system(size:"] {
            XCTAssertFalse(panel.contains(token), token)
        }
        let root = try source("Features/MenuBar/Views/MenuBarRootView.swift")
        XCTAssertTrue(root.contains("Task { await powerStore.refresh() }"))
        XCTAssertTrue(root.contains("isRetrying: powerStore.isRefreshing"))
        let app = try source("App/WattApp.swift")
        for token in ["MenuBarExtra(isInserted:", ".menuBarExtraStyle(.window)", "ScenePresentationBridge(",
                      ".task(id: preferences.updateInterval)", "await powerStore.runSampling(interval:",
                      "NSWorkspace.didWakeNotification", "powerStore.handleWake()",
                      "private var samplingTask: Task<Void, Never>?", "startSampling()",
                      "preferences.$updateInterval", "private func startSampling()",
                      "samplingTask?.cancel()",
                      "await J81FixtureLaunch.prepare(router: router)", "view.observeJ81StatusFixture(router: router)"] {
            XCTAssertTrue(app.contains(token), token)
        }
        for token in ["private var wakeObserver: NSObjectProtocol?",
                      "notificationCenter.addObserver(", "removeObserver(wakeObserver)",
                      "matching: [.rightMouseDown, .leftMouseDown]",
                      "event.modifierFlags.contains(.control)",
                      "StatusItemContextMenu.endPresentation(menu)"] {
            XCTAssertTrue(app.contains(token), token)
        }
        let fixture = try source("App/J81FixtureLaunch.swift")
        XCTAssertTrue(fixture.hasPrefix("#if DEBUG\n"))
        XCTAssertTrue(fixture.hasSuffix("#endif\n"))
        for token in ["NSWindow(", "NSImage(", "NSPopover(", "NSHostingView", ".cacheDisplay(",
                      ".displayIgnoringOpacity(", "UserDefaults", "CGRequestScreenCaptureAccess", "AXIsProcessTrustedWithOptions"] {
            XCTAssertFalse(fixture.contains(token), token)
        }
    }

    #if DEBUG || SWIFT_PACKAGE
    private func assertNoPower(_ sample: PowerReading, file: StaticString = #filePath, line: UInt = #line) {
        let model = StatusPanelModel(reading: sample)
        XCTAssertEqual(model.state, .noReading, file: file, line: line)
        XCTAssertEqual(model.title, "No reading", file: file, line: line)
        XCTAssertEqual(model.headlineValue, "− − W", file: file, line: line)
        XCTAssertFalse(model.accessibilitySummary.contains("42.1"), file: file, line: line)
        XCTAssertFalse(model.showsComponents, file: file, line: line)
        let preferences = J81FixtureLaunch.makePreferences()
        for mode in WattDisplayMode.allCases {
            preferences.displayMode = mode
            XCTAssertEqual(MenuBarStatusLabel(reading: sample, preferences: preferences).accessibilityReading,
                           "No reading yet", file: file, line: line)
        }
    }
    #endif

    private func reading(mode: PowerMode = .charging, source: ReadingSource = .system,
                         freshness: ReadingFreshness = .fresh, watts: Double? = 42.1,
                         percentage: Int = 64, capability: Capability = .available,
                         timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
                         chargerWatts: Double? = 65, systemWatts: Double? = 22.9) -> PowerReading {
        PowerReading(mode: mode, watts: watts, batteryPercentage: percentage,
            timestamp: timestamp, batteryState: .charging,
            capabilities: .init(battery: capability, charger: capability, systemDraw: capability),
            freshness: freshness, source: source, chargerWatts: chargerWatts, systemWatts: systemWatts)
    }

    private func nativeButtons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { nativeButtons(in: $0) }
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}

@MainActor
private final class CountingTelemetry: TelemetryService {
    private(set) var calls = 0
    func sample() async -> ServiceOutcome<PowerReading> { calls += 1; return .success(.unavailable) }
}

@MainActor
private final class DeferredTelemetry: TelemetryService {
    private var continuations: [CheckedContinuation<ServiceOutcome<PowerReading>, Never>] = []
    var calls: Int { continuations.count }
    func sample() async -> ServiceOutcome<PowerReading> {
        await withCheckedContinuation { continuations.append($0) }
    }
    func waitForCalls(_ count: Int) async {
        for _ in 0..<100 { if calls >= count { return }; await Task.yield() }
        XCTFail("Telemetry request did not start")
    }
    func finish(_ index: Int, with outcome: ServiceOutcome<PowerReading>) {
        continuations[index].resume(returning: outcome)
    }
}
