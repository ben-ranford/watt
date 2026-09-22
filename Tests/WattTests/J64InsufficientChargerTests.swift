import AppKit
import SwiftUI
import XCTest
#if SWIFT_PACKAGE
import WattFixtures
#endif
@testable import Watt

@MainActor
final class J64InsufficientChargerTests: XCTestCase {
    private static let message = "Because your Mac draws 78 W and this charger gives 65 W. The battery covers the rest."

    func testExactWarningCopyAndThreePowerRowsWithoutComponents() {
        let model = StatusPanelModel(reading: .sampleInsufficientCharger,
            chargerDescription: "67 W USB-C charger")
        XCTAssertEqual(model.state, .insufficientCharger)
        XCTAssertEqual(model.title, "Charger can’t keep up")
        XCTAssertEqual(model.headlineValue, "−13.0 W")
        XCTAssertEqual(model.subtitle, Self.message)
        XCTAssertEqual(model.chargerSubtitle, "67 W USB-C charger")
        XCTAssertEqual([model.charger, model.system, model.battery], ["65.0 W", "78.0 W", "−13.0 W"])
        XCTAssertEqual(model.accessibilitySummary, "Charger can’t keep up, −13.0 W, " + Self.message)
        XCTAssertFalse(model.showsComponents)
        XCTAssertFalse(model.componentsOff)
        XCTAssertEqual(model.panelHeight, 279)
        XCTAssertEqual(InsufficientChargerPresentation.symbol, "exclamationmark.triangle.fill")
    }

    func testThresholdRequiresBoundValidatedProvenanceAndAvailableFreshTelemetry() {
        let badThresholds: [ChargerThresholdProvenance?] = [nil,
            .init(episodeID: " ", observedAt: Self.timestamp, sustainedDuration: 300),
            .init(episodeID: "test", observedAt: Self.timestamp, sustainedDuration: 299.9),
            .init(episodeID: "test", observedAt: Self.timestamp, sustainedDuration: .infinity),
            .init(episodeID: "test", observedAt: Self.timestamp, sustainedDuration: .nan),
            .init(episodeID: "test", observedAt: Self.timestamp.addingTimeInterval(-1), sustainedDuration: 300)]
        var expected = Array(repeating: StatusPanelState.standard, count: badThresholds.count)
        expected += [.noReading, .standard, .noReading, .standard, .standard, .noReading, .noReading,
                     .standard, .standard, .standard, .noReading, .noReading, .noReading, .noReading,
                     .noReading, .standard, .standard]
        var rejected = badThresholds.map { reading(threshold: $0) }
        rejected += [reading(watts: nil), reading(watts: 0), reading(watts: .nan),
            reading(charger: nil), reading(charger: 0), reading(charger: -1), reading(charger: .infinity),
            reading(system: nil), reading(system: 65), reading(system: 64), reading(system: .nan),
            reading(source: .unavailable), reading(freshness: .stale), reading(freshness: .unavailable),
            reading(state: .charging), reading(state: .unknown), reading(state: .full)]
        for capability in [Capability.unknown, .unsupported, .permissionRequired, .disconnected] {
            expected += [.noReading, .standard, .standard]
            rejected += [reading(batteryCapability: capability), reading(chargerCapability: capability),
                         reading(systemCapability: capability)]
        }
        XCTAssertEqual(rejected.count, expected.count)
        for (sample, expectedState) in zip(rejected, expected) {
            XCTAssertFalse(sample.hasInsufficientCharger)
            XCTAssertNil(sample.insufficientChargerMessage)
            XCTAssertEqual(StatusPanelModel(reading: sample).state, expectedState)
        }
        for source in [ReadingSource.fixture, .system, .helper] {
            XCTAssertTrue(reading(source: source).hasInsufficientCharger)
        }
        XCTAssertFalse(PowerReading.sampleOnBattery.hasInsufficientCharger)
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).title, "Charging")
        XCTAssertEqual(StatusPanelModel(reading: .sampleFullOnAdapter).title, "Full")
        XCTAssertEqual(StatusPanelModel(reading: .sampleChargingHold).title, "Holding at 80%")
    }

    func testFailedFutureAndAgedSamplesSuppressClaimAndRecover() {
        let clock = FakeWattClock(now: Self.timestamp)
        let store = PowerReadingStore(currentReading: .sampleInsufficientCharger, clock: clock)
        XCTAssertFalse(store.accept(reading(watts: .nan), generation: store.generation))
        XCTAssertEqual(store.failure, .invalidData)
        XCTAssertEqual(store.currentReading, .sampleInsufficientCharger)
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.sampleInsufficientCharger, generation: store.generation))
        XCTAssertFalse(store.accept(reading(timestamp: Self.timestamp.addingTimeInterval(1)), generation: store.generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertTrue(store.accept(.sampleInsufficientCharger, generation: store.generation))
        clock.advance(by: 5)
        XCTAssertTrue(store.statusReading.hasInsufficientCharger)
        clock.advance(by: 0.01)
        XCTAssertEqual(store.statusReading, .unavailable)
        let recovered = reading(timestamp: clock.now, threshold: .init(episodeID: "new", observedAt: clock.now, sustainedDuration: 300))
        XCTAssertTrue(store.accept(recovered, generation: store.generation))
        XCTAssertTrue(store.statusReading.hasInsufficientCharger)
    }

    private static let timestamp = PowerReading.sampleInsufficientCharger.timestamp
    private func reading(watts: Double? = -13, charger: Double? = 65, system: Double? = 78,
                         source: ReadingSource = .fixture, freshness: ReadingFreshness = .fresh,
                         state: BatteryState = .discharging,
                         batteryCapability: Capability = .available,
                         chargerCapability: Capability = .available,
                         systemCapability: Capability = .available,
                         timestamp: Date = PowerReading.sampleInsufficientCharger.timestamp,
                         threshold: ChargerThresholdProvenance? = PowerReading.sampleInsufficientCharger.chargerThreshold) -> PowerReading {
        PowerReading(mode: .onBattery, watts: watts, timestamp: timestamp, batteryState: state,
            capabilities: .init(battery: batteryCapability, charger: chargerCapability, systemDraw: systemCapability),
            freshness: freshness, source: source, chargerWatts: charger, systemWatts: system,
            chargerThreshold: threshold)
    }

    func testNativeDarkHostGeometryAndFooterButtonCallbacks() throws {
        let preferences = J64FixtureLaunch.makePreferences()
        let original = preferences.onboarding
        let router = AppRouter()
        var routes: [AppDestination] = []
        router.present = { routes.append($0) }
        var quits = 0
        let panel = StatusPanelView(reading: .sampleInsufficientCharger,
            chargerDescription: "67 W USB-C charger", includesComponents: false,
            onSettings: { router.showSettings() }, onQuit: { quits += 1 })
        let host = NSHostingView(rootView: panel)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 279),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: J64FixtureLaunch.appearanceName)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.fittingSize, NSSize(width: 320, height: 279))
        XCTAssertEqual(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        // SwiftUI hosts text separately and leaves the backing NSButton's title/AX ID empty.
        // The native footer places Settings on the left and Quit on the right.
        let buttons = nativeButtons(in: host).sorted {
            $0.convert($0.bounds, to: host).minX < $1.convert($1.bounds, to: host).minX
        }
        XCTAssertEqual(buttons.count, 2)
        let settings = try XCTUnwrap(buttons.first)
        let quit = try XCTUnwrap(buttons.last)
        XCTAssertFalse(settings === quit)
        XCTAssertFalse(settings.isBordered)
        XCTAssertFalse(quit.isBordered)
        settings.performClick(nil)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(quits, 0)
        quit.performClick(nil)
        XCTAssertEqual(routes, [.settings])
        XCTAssertEqual(quits, 1)
        XCTAssertEqual(preferences.onboarding, original)
        XCTAssertEqual(preferences.displayMode, .delta)
    }

    func testNativeAccessibilityExposesThreePowerRowsWithoutComponents() throws {
        let host = NSHostingView(rootView: StatusPanelView(reading: .sampleInsufficientCharger,
            chargerDescription: "67 W USB-C charger", onSettings: {}, onQuit: {}))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 279),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        let labels = accessibilityLabels(in: host).filter { !$0.isEmpty }
        try XCTSkipIf(labels.isEmpty,
            "Native SwiftUI host exposes no AX labels in this test process; row AX validation remains blocked. No AX or visual pass is claimed.")
        for row in ["Charger input", "System draw", "Battery"] {
            XCTAssertEqual(labels.filter { $0 == row }.count, 1, row)
        }
        XCTAssertFalse(labels.contains("Components"))
    }

    func testSelectedNativeStatusItemKeepsExactLabelAndDarkAqua() throws {
        let preferences = J64FixtureLaunch.makePreferences()
        let store = J64FixtureLaunch.makeStore()
        let label = MenuBarStatusLabel(reading: store.currentReading, preferences: preferences)
        XCTAssertEqual(label.text, "−13.0 W")
        XCTAssertEqual(label.symbolName, "battery.100percent")
        XCTAssertTrue(label.showsSymbol)
        let item = NSStatusBar.system.statusItem(withLength: 96)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try XCTUnwrap(item.button)
        button.appearance = NSAppearance(named: J64FixtureLaunch.appearanceName)
        let router = AppRouter()
        let selection = C0410PanelSelection(button: button, router: router,
            preferences: preferences, store: store)
        selection.applySelection(isPresented: true)
        XCTAssertTrue(router.statusPanelPresented)
        XCTAssertTrue(button.isHighlighted)
        XCTAssertEqual(button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
        XCTAssertNil(button.contentTintColor)
        selection.applySelection(isPresented: false)
        XCTAssertFalse(router.statusPanelPresented)
        XCTAssertFalse(button.isHighlighted)
    }

    func testSharedPanelUsesNativeFormRowsAndBorderlessFooter() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/StatusPanelView.swift"), encoding: .utf8)
        for token in ["Form {", ".formStyle(.grouped)", "LabeledContent", "if model.showsComponents",
                      "Label(model.title, systemImage: InsufficientChargerPresentation.symbol)",
                      "row(\"Charger input\"", "row(\"System draw\"", "row(\"Battery\"",
                      "Button(\"Settings…\", action: onSettings)", "Button(\"Quit Watt?\", action: onQuit)",
                      ".buttonStyle(.borderless)"] {
            XCTAssertTrue(source.contains(token), token)
        }
        for token in ["RoundedRectangle", "Gradient", ".background(", ".shadow(", ".tint(", "Font.custom"] {
            XCTAssertFalse(source.contains(token), token)
        }
    }

    private func accessibilityLabels(in root: NSView) -> [String] {
        var seen = Set<ObjectIdentifier>()
        func collect(_ object: Any) -> [String] {
            guard let element = object as? any NSAccessibilityProtocol,
                  seen.insert(ObjectIdentifier(element as AnyObject)).inserted else { return [] }
            let own = element.accessibilityLabel().map { [$0] } ?? []
            return own + (element.accessibilityChildren() ?? []).flatMap(collect)
                + ((object as? NSView)?.subviews ?? []).flatMap(collect)
        }
        return collect(root)
    }

    private func nativeButtons(in view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap { nativeButtons(in: $0) }
    }
}

@MainActor
final class J64FixtureTests: XCTestCase {
    func testExactRegistryAndInvalidSelectorsFailClosed() throws {
        let fixture = try ScenarioRegistry.resolve("J6.4")
        XCTAssertEqual(fixture.story.node, "31:4956")
        XCTAssertEqual(fixture.story.appearance, "dark")
        XCTAssertEqual(fixture.story.expectedScene, "panel")
        XCTAssertEqual(fixture.story.status, "implemented")
        XCTAssertEqual(fixture.story.variants, J64FixtureLaunch.variants)
        for variant in J64FixtureLaunch.variants {
            XCTAssertNoThrow(try ScenarioRegistry.resolve("J6.4", variant: variant))
            let args = ["Watt", "--watt-fixture", "J6.4/" + variant]
            let launch = try XCTUnwrap(FixtureLaunchSelection.parse(args))
            XCTAssertEqual(try launch.smokeLaunchArguments(), Array(args.dropFirst()))
            #if SWIFT_PACKAGE
            XCTAssertFalse(J64FixtureLaunch.matches(arguments: args))
            #else
            XCTAssertNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertTrue(J64FixtureLaunch.matches(arguments: args))
            #endif
        }
        for selector in ["J6.4/light", "J6.4/unknown", "J6.4/base/extra", "J6.4/", "/base", "j6.4/base"] {
            let args = ["Watt", "--watt-fixture", selector]
            XCTAssertThrowsError(try FixtureLaunchSelection.parse(args))
            XCTAssertNotNil(WattFixtureLaunchGate.rejection(arguments: args))
            XCTAssertFalse(J64FixtureLaunch.matches(arguments: args))
        }
        for args in [[], ["--watt-fixture"], ["--watt-fixture", "J6.3/base"],
                     ["--watt-fixture", "J6.4/base", "--watt-fixture", "C01/base"]] {
            XCTAssertFalse(J64FixtureLaunch.matches(arguments: args))
        }
    }

    func testIndependentMemoryPreferencesFrozenStoreAndDisconnect() {
        let first = J64FixtureLaunch.makePreferences()
        let second = J64FixtureLaunch.makePreferences()
        XCTAssertFalse(first === second)
        XCTAssertTrue(first.onboarding.completed)
        XCTAssertEqual(first.onboarding.checkpoint, .livePanel)
        XCTAssertEqual(first.displayMode, .delta)
        XCTAssertEqual(first.precision, .decimal)
        XCTAssertTrue(first.showSymbol)
        XCTAssertFalse(first.componentReadings)
        XCTAssertNil(first.persistenceFailure)
        first.displayMode = .draw
        first.onboarding.completed = false
        first.chargerNotification = false
        XCTAssertEqual(second.displayMode, .delta)
        XCTAssertTrue(second.onboarding.completed)
        XCTAssertTrue(second.chargerNotification)
        XCTAssertFalse(PreferencesStore(storage: InMemoryStorage()).onboarding.completed)
        XCTAssertEqual(J64FixtureLaunch.appearanceName, .darkAqua)
        let store = J64FixtureLaunch.makeStore()
        let other = J64FixtureLaunch.makeStore()
        XCTAssertFalse(store === other)
        XCTAssertNotEqual(store.generation, other.generation)
        XCTAssertEqual(store.freshness(maximumAge: 0), .fresh)
        let generation = store.generation
        store.disconnect()
        XCTAssertFalse(store.accept(.sampleInsufficientCharger, generation: generation))
        XCTAssertEqual(store.statusReading, .unavailable)
        XCTAssertEqual(other.statusReading, .sampleInsufficientCharger)
        XCTAssertEqual(J63FixtureLaunch.makeStore().currentReading, .sampleFullOnAdapter)
    }

    func testNotificationPreferenceAuthorizationMatrixRecordsIntentNeverAcceptance() async {
        for variant in J64FixtureLaunch.variants {
            let preferences = J64FixtureLaunch.makePreferences(variant: variant)
            let original = preferences.onboarding
            let store = J64FixtureLaunch.makeStore()
            let router = AppRouter()
            var routes: [AppDestination] = []
            router.present = { routes.append($0) }
            let driver = await J64FixtureLaunch.exerciseNotification(variant: variant,
                preferences: preferences, store: store, router: router)
            let eligible = variant == "base" || variant == "notification-on-authorized"
            XCTAssertEqual(driver.intents.count, eligible ? 1 : 0, variant)
            XCTAssertEqual(driver.permissionRequests, 0)
            XCTAssertEqual(router.notificationAuthorization, J64FixtureLaunch.authorization(for: variant).contract)
            if let intent = driver.intents.first {
                XCTAssertEqual(intent.identifier, "watt.insufficient-charger.J6.4")
                XCTAssertEqual(intent.title, "Charger can’t keep up")
                XCTAssertEqual(intent.body, "Because your Mac draws 78 W and this charger gives 65 W. The battery covers the rest.")
            }
            let result = await PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
                .handleInsufficientCharger(store: store)
            XCTAssertEqual(result, eligible ? .failed(.unknownStatus) : preferences.chargerNotification ? .openNotificationSettings : .preferenceOff)
            XCTAssertEqual(preferences.onboarding, original)
            XCTAssertEqual(store.currentReading, .sampleInsufficientCharger)
            XCTAssertTrue(routes.isEmpty)
        }
    }

    func testUnknownVariantCannotRequestIntent() async {
        let router = AppRouter()
        let driver = await J64FixtureLaunch.exerciseNotification(variant: "unknown",
            preferences: J64FixtureLaunch.makePreferences(), store: J64FixtureLaunch.makeStore(), router: router)
        XCTAssertTrue(driver.intents.isEmpty)
        XCTAssertEqual(driver.permissionRequests, 0)
        XCTAssertNil(router.notificationAuthorization)
    }

    func testDeniedUnknownProvisionalAndUndeterminedPermissionsFailClosedWithoutRequest() async {
        let preferences = J64FixtureLaunch.makePreferences()
        for permission in [NotificationPermission.denied, .unknown, .provisional, .notDetermined] {
            let driver = J64NotificationIntentDriver(permission: permission)
            let result = await PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
                .handleInsufficientCharger(store: J64FixtureLaunch.makeStore())
            XCTAssertEqual(result, permission == .notDetermined ? .requestPermission : .openNotificationSettings)
            XCTAssertTrue(driver.intents.isEmpty)
            XCTAssertEqual(driver.permissionRequests, 0)
        }
    }

    func testAuthorizationSuspensionRechecksPreferenceAndFreshTelemetry() async {
        for mutation in 0..<5 {
            let clock = FakeWattClock(now: PowerReading.sampleInsufficientCharger.timestamp)
            let store = PowerReadingStore(currentReading: .sampleInsufficientCharger, clock: clock)
            let preferences = J64FixtureLaunch.makePreferences()
            let bridge = J64SuspendingBridge()
            let effects = PowerNotificationEffects(bridge: bridge, preferences: preferences)
            let task = Task { await effects.handleInsufficientCharger(store: store) }
            while bridge.continuation == nil { await Task.yield() }
            switch mutation {
            case 0: preferences.chargerNotification = false
            case 1: clock.advance(by: 5.01)
            case 2: store.disconnect()
            case 3: store.restart()
            default:
                _ = store.accept(PowerReading(mode: .onBattery, watts: .nan), generation: store.generation)
            }
            bridge.continuation?.resume(returning: .authorized)
            bridge.continuation = nil
            let result = await task.value
            XCTAssertEqual(result, mutation == 0 ? .preferenceOff : .failed(.invalidData))
            XCTAssertEqual(bridge.deliveries, 0)
        }
    }

    func testSystemBridgeRechecksEligibilityAfterItsOwnPermissionSuspension() async {
        for mutation in 0..<4 {
            let clock = FakeWattClock(now: PowerReading.sampleInsufficientCharger.timestamp)
            let store = PowerReadingStore(currentReading: .sampleInsufficientCharger, clock: clock)
            let preferences = J64FixtureLaunch.makePreferences()
            let driver = J64SuspendingSystemDriver()
            let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
            let task = Task { await effects.handleInsufficientCharger(store: store) }
            while driver.continuation == nil { await Task.yield() }
            switch mutation {
            case 0: preferences.chargerNotification = false
            case 1: clock.advance(by: 5.01)
            case 2: store.restart()
            default: store.disconnect()
            }
            driver.continuation?.resume(returning: .authorized)
            driver.continuation = nil
            let result = await task.value
            XCTAssertEqual(result, .failed(.invalidData))
            XCTAssertEqual(driver.enqueues, 0)
        }
    }

    func testInvalidTelemetryCannotCreateNotificationIntent() async {
        let driver = J64NotificationIntentDriver(permission: .authorized)
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver),
            preferences: J64FixtureLaunch.makePreferences())
        for reading in [PowerReading.sampleOnBattery, .sampleCharging, .unavailable] {
            let store = PowerReadingStore(currentReading: reading, clock: FakeWattClock())
            let result = await effects.handleInsufficientCharger(store: store)
            XCTAssertEqual(result, .failed(.invalidData))
        }
        XCTAssertTrue(driver.intents.isEmpty)
    }
}

@MainActor
private final class J64SuspendingBridge: NotificationBridge {
    var continuation: CheckedContinuation<NotificationAuthorization, Never>?
    var deliveries = 0
    func authorization() async -> NotificationAuthorization {
        await withCheckedContinuation { continuation = $0 }
    }
    func requestAuthorization() async -> ServiceOutcome<NotificationAuthorization> { .failure(.unknownStatus) }
    func deliver(identifier: String, title: String, body: String) async -> ServiceOutcome<Bool> {
        deliveries += 1
        return .failure(.unknownStatus)
    }
}

@MainActor
private final class J64SuspendingSystemDriver: NotificationSystemDriver {
    var continuation: CheckedContinuation<NotificationPermission, Never>?
    var queries = 0
    var enqueues = 0
    func permission() async -> NotificationPermission {
        queries += 1
        if queries == 1 { return .authorized }
        return await withCheckedContinuation { continuation = $0 }
    }
    func requestPermission() async throws { throw ServiceFailure.unknownStatus }
    func enqueue(identifier: String, title: String, body: String) async throws { enqueues += 1 }
}
