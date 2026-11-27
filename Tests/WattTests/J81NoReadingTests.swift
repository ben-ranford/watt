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
                       reading(chargerWatts: -1), reading(percentage: 101), reading(capability: .permissionRequired),
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

    func testSamplingToleranceStaysInsideTheFreshnessLead() {
        XCTAssertEqual(PowerReadingStore.samplingToleranceFraction, 0.10, accuracy: 0.001)
        for interval in [0.25, 1, 2, 5] {
            let delay = PowerReadingStore.samplingDelay(for: interval)
            let tolerance = PowerReadingStore.samplingTolerance(for: delay)
            XCTAssertGreaterThan(tolerance, 0, "interval \(interval)")
            XCTAssertLessThanOrEqual(tolerance, PowerReadingStore.samplingRefreshLeadTime / 2)
            XCTAssertLessThanOrEqual(delay + tolerance,
                                     PowerReadingStore.statusMaximumAge - PowerReadingStore.samplingRefreshLeadTime / 2)
        }
        XCTAssertEqual(PowerReadingStore.samplingTolerance(for: 0), 0, accuracy: 0.001)
        XCTAssertEqual(PowerReadingStore.samplingDelay(for: 2), 2, accuracy: 0.001)
        let capped = PowerReadingStore.samplingDelay(for: 5)
        XCTAssertEqual(capped, 4.5, accuracy: 0.001)
        XCTAssertEqual(PowerReadingStore.samplingTolerance(for: capped), 0.25, accuracy: 0.001)
    }

    func testHiddenPanelSchedulesOnlyTheMenuBarSample() async {
        let harness = IdleSamplingHarness()
        harness.panelPresented = false
        harness.menuBarComponents = false
        let task = harness.start()
        defer { task.cancel() }

        await harness.waitForMenuBarPause()
        XCTAssertEqual(harness.system.calls, 1)
        XCTAssertEqual(harness.components.calls, 0)
        let delay = PowerReadingStore.samplingDelay(for: 2)
        let tolerance = PowerReadingStore.samplingTolerance(for: delay)
        XCTAssertEqual(harness.scheduler.pauses.count, 1)
        XCTAssertEqual(harness.scheduler.pauses[0].delay, delay, accuracy: 0.001)
        XCTAssertEqual(harness.scheduler.pauses[0].tolerance, tolerance, accuracy: 0.001)

        for _ in 0..<4 {
            let calls = harness.system.calls
            harness.scheduler.resumeNext()
            await harness.waitUntil("menu-bar sample did not advance") { harness.system.calls > calls }
            await harness.waitUntil("menu-bar pause was not rearmed") {
                harness.scheduler.pauses.count == harness.system.calls
            }
        }
        XCTAssertEqual(harness.system.calls, 5)
        XCTAssertEqual(harness.components.calls, 0)
        XCTAssertEqual(harness.scheduler.pauses.count, 5)
        XCTAssertTrue(harness.scheduler.pauses.allSatisfy {
            abs($0.delay - delay) < 0.001 && abs($0.tolerance - tolerance) < 0.001
        })
        let settledCalls = harness.system.calls
        let settledPauses = harness.scheduler.pauses.count
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(harness.system.calls, settledCalls)
        XCTAssertEqual(harness.scheduler.pauses.count, settledPauses)
        XCTAssertEqual(harness.components.calls, 0)
    }

    func testHiddenPanelStillSamplesComponentsWhenTheMenuBarShowsThem() async throws {
        let harness = IdleSamplingHarness()
        harness.menuBarComponents = true
        let task = harness.start()
        defer { task.cancel() }

        await harness.waitUntil("component sample was not scheduled for the menu bar") {
            harness.components.calls == 1 && harness.scheduler.pauses.contains { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 }
        }
        XCTAssertGreaterThanOrEqual(harness.system.calls, 1)
        XCTAssertTrue(harness.scheduler.pauses.contains { abs($0.delay - PowerReadingStore.samplingDelay(for: 2)) < 0.001 })
        let componentPause = try XCTUnwrap(harness.scheduler.pauses.first { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 })
        XCTAssertEqual(componentPause.tolerance, PowerReadingStore.samplingTolerance(for: componentPause.delay), accuracy: 0.001)
        XCTAssertLessThanOrEqual(componentPause.delay + componentPause.tolerance, PowerReadingStore.componentsStatusMaximumAge)
    }

    func testOpeningThePanelSchedulesComponentSamplingAndClosingCancelsIt() async {
        let harness = IdleSamplingHarness()
        let task = harness.start()
        defer { task.cancel() }

        await harness.waitForMenuBarPause()
        XCTAssertEqual(harness.components.calls, 0)

        harness.panelPresented = true
        harness.store.refreshComponentSamplingNeed()
        await harness.waitUntil("opening the panel did not sample components") {
            harness.components.calls == 1
                && harness.scheduler.pauses.contains { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 }
        }
        let componentPauses = harness.scheduler.pauses.filter { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 }.count

        harness.clock.advance(by: PowerReadingStore.retryInterval)
        harness.panelPresented = false
        harness.store.refreshComponentSamplingNeed()
        for _ in 0..<20 { await Task.yield() }
        harness.scheduler.resumeAll()
        await harness.waitUntil("menu-bar sampling stopped when the panel closed") { harness.system.calls >= 2 }
        XCTAssertEqual(harness.components.calls, 1)
        XCTAssertEqual(
            harness.scheduler.pauses.filter { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 }.count,
            componentPauses)
    }

    func testMenuBarSamplingHoldsAndReleasesTheAppNapExemption() async {
        let activity = RecordingSamplingActivity()
        let scheduler = ScriptedRefreshScheduler()
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(),
                                      telemetry: CountingTelemetry(), scheduler: scheduler,
                                      samplingActivity: activity)
        let task = Task { await store.runSampling(interval: { 2 }) }
        defer { task.cancel() }
        for _ in 0..<200 {
            if activity.began == 1, scheduler.pauses.count >= 1 { break }
            await Task.yield()
        }
        XCTAssertEqual(activity.began, 1)
        XCTAssertEqual(activity.ended, 0)
        task.cancel()
        scheduler.resumeAll()
        await task.value
        XCTAssertEqual(activity.began, 1)
        XCTAssertEqual(activity.ended, 1)
    }

    func testIdleFixtureClockDoesNotTakeAnAppNapExemption() async {
        let activity = RecordingSamplingActivity()
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(),
                                      samplingActivity: activity)
        await store.runSampling()
        XCTAssertEqual(activity.began, 0)
        XCTAssertEqual(activity.ended, 0)
    }

    func testUnsetComponentPolicyKeepsTheHelperSampler() async {
        let system = CountingTelemetry()
        let components = CountingComponentTelemetry()
        let scheduler = ScriptedRefreshScheduler()
        let store = PowerReadingStore(currentReading: .unavailable, clock: FakeWattClock(),
                                      telemetry: system, componentTelemetry: components, scheduler: scheduler)
        let task = Task { await store.runSampling(interval: { 2 }) }
        defer { task.cancel() }
        for _ in 0..<200 {
            if components.calls == 1,
               scheduler.pauses.contains(where: { abs($0.delay - PowerReadingStore.retryInterval) < 0.001 }) {
                break
            }
            await Task.yield()
        }
        XCTAssertEqual(components.calls, 1)
        XCTAssertGreaterThanOrEqual(system.calls, 1)
        XCTAssertTrue(scheduler.pauses.contains { abs($0.delay - PowerReadingStore.samplingDelay(for: 2)) < 0.001 })
    }

    func testProductionIdlePathReleasesTheHiddenPanelAndReadsNamedRegistryKeys() throws {
        let telemetry = try source("Services/SystemPowerSourceTelemetryService.swift")
        XCTAssertTrue(telemetry.contains("IORegistryEntryCreateCFProperty"))
        for key in ["PowerTelemetryData", "AdapterDetails", "AppleRawAdapterDetails",
                    "Voltage", "InstantAmperage", "Amperage"] {
            XCTAssertTrue(telemetry.contains("\"\(key)\""), key)
        }
        XCTAssertFalse(telemetry.contains("IORegistryEntryCreateCFProperties"))
        XCTAssertFalse(telemetry.contains("IOServiceOpen"))
        XCTAssertFalse(telemetry.contains("AppleSMC"))
        let storeSource = try source("Services/PowerReadingStore.swift")
        XCTAssertTrue(storeSource.contains("try await Task.sleep(for: duration, tolerance: leeway)"))
        XCTAssertTrue(storeSource.contains("func setComponentSamplingPolicy"))
        let app = try source("App/WattFallbackStatusItem.swift")
        let installStart = try XCTUnwrap(app.range(of: "func install()"))
        let uninstall = try XCTUnwrap(app.range(of: "func uninstall()", range: installStart.upperBound..<app.endIndex))
        let install = app[installStart.lowerBound..<uninstall.lowerBound]
        let policy = try XCTUnwrap(install.range(of: "setComponentSamplingPolicy"))
        let sampling = try XCTUnwrap(install.range(of: "startSampling()"))
        XCTAssertLessThan(policy.lowerBound, sampling.lowerBound)
        XCTAssertTrue(app.contains("popover.delegate = self"))
        XCTAssertTrue(app.contains("panel?.contentViewController = nil"))
        XCTAssertTrue(app.contains("preferences.displayMode == .components"))
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
        XCTAssertEqual(fixture.story.node, "J8.1")
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
        let app = try source("App/WattApp.swift") + source("App/WattFallbackStatusItem.swift") + source("App/StatusItemAdapter.swift")
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

private final class SamplingActivityCounts: @unchecked Sendable {
    private let lock = NSLock()
    private var beganCount = 0
    private var endedCount = 0
    var began: Int { lock.lock(); defer { lock.unlock() }; return beganCount }
    var ended: Int { lock.lock(); defer { lock.unlock() }; return endedCount }
    func beganOnce() { lock.lock(); beganCount += 1; lock.unlock() }
    func endedOnce() { lock.lock(); endedCount += 1; lock.unlock() }
}

@MainActor
private final class RecordingSamplingActivity: MenuBarSamplingActivity {
    let counts = SamplingActivityCounts()
    var began: Int { counts.began }
    var ended: Int { counts.ended }

    func begin() -> any MenuBarSamplingActivityToken {
        counts.beganOnce()
        return RecordingSamplingActivityToken(counts)
    }
}

private final class RecordingSamplingActivityToken: MenuBarSamplingActivityToken {
    private let counts: SamplingActivityCounts
    private let lock = NSLock()
    private var open = true
    init(_ counts: SamplingActivityCounts) { self.counts = counts }
    func end() {
        lock.lock()
        let shouldCount = open
        open = false
        lock.unlock()
        if shouldCount { counts.endedOnce() }
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

@MainActor
private final class CountingComponentTelemetry: ComponentTelemetryService {
    private(set) var calls = 0
    func sampleComponents() async -> ServiceOutcome<ComponentEstimatePair> {
        calls += 1
        return .failure(.unknownStatus)
    }
}

/// Records every sampler sleep and resumes it only when the test says so.
/// The recorded pauses live off the main actor so cancellation can complete
/// the sleep without a hop.
private final class ScriptedRefreshState: @unchecked Sendable {
    struct Pause: Equatable {
        var delay: TimeInterval
        var tolerance: TimeInterval
    }

    private let lock = NSLock()
    private var storedPauses: [Pause] = []
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var order: [UUID] = []

    var pauses: [Pause] {
        lock.lock()
        defer { lock.unlock() }
        return storedPauses
    }

    func begin(id: UUID, delay: TimeInterval, tolerance: TimeInterval,
               continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        storedPauses.append(Pause(delay: delay, tolerance: tolerance))
        waiters[id] = continuation
        order.append(id)
        lock.unlock()
    }

    func finish(_ id: UUID, _ error: Error?) {
        lock.lock()
        let continuation = waiters.removeValue(forKey: id)
        order.removeAll { $0 == id }
        lock.unlock()
        guard let continuation else { return }
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume() }
    }

    func resumeNext() {
        lock.lock()
        let id = order.first { waiters[$0] != nil }
        lock.unlock()
        if let id { finish(id, nil) }
    }

    func resumeAll() {
        lock.lock()
        let pending = order.compactMap { waiters[$0] }
        waiters.removeAll()
        order.removeAll()
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}

@MainActor
private final class ScriptedRefreshScheduler: RefreshScheduling {
    private let state = ScriptedRefreshState()
    var pauses: [ScriptedRefreshState.Pause] { state.pauses }

    func pause(for delay: TimeInterval, tolerance: TimeInterval) async throws {
        let id = UUID()
        let state = self.state
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                state.begin(id: id, delay: delay, tolerance: tolerance, continuation: continuation)
                if Task.isCancelled { state.finish(id, CancellationError()) }
            }
        } onCancel: {
            state.finish(id, CancellationError())
        }
    }

    func resumeNext() { state.resumeNext() }
    func resumeAll() { state.resumeAll() }
}

@MainActor
private final class IdleSamplingHarness {
    let clock = FakeWattClock()
    let system = CountingTelemetry()
    let components = CountingComponentTelemetry()
    let scheduler = ScriptedRefreshScheduler()
    let store: PowerReadingStore
    var panelPresented = false
    var menuBarComponents = false

    init() {
        store = PowerReadingStore(currentReading: .unavailable, clock: clock, telemetry: system,
                                  componentTelemetry: components, scheduler: scheduler)
    }

    func start() -> Task<Void, Never> {
        store.setComponentSamplingPolicy { [weak self] in
            guard let self else { return false }
            return self.panelPresented || self.menuBarComponents
        }
        let store = store
        return Task { await store.runSampling(interval: { 2 }) }
    }

    func waitForMenuBarPause() async {
        let delay = PowerReadingStore.samplingDelay(for: 2)
        await waitUntil("menu-bar pause was not scheduled") {
            system.calls >= 1 && scheduler.pauses.contains { abs($0.delay - delay) < 0.001 }
        }
    }

    func waitUntil(_ description: String, attempts: Int = 200, _ condition: () -> Bool) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
        }
        XCTFail(description)
    }
}
