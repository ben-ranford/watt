import XCTest
@testable import Watt

@MainActor
final class NotificationThresholdTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    func testDefaultsPreserveTodaysNotificationBehaviour() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        XCTAssertTrue(preferences.chargerNotification)
        XCTAssertFalse(preferences.fullyChargedNotification)
        XCTAssertFalse(preferences.lowBatteryNotification)
        XCTAssertEqual(preferences.insufficientChargerMinutes, 5)
        XCTAssertEqual(preferences.insufficientChargerDuration, PowerReading.defaultInsufficientChargerDuration)
        XCTAssertEqual(preferences.fullyChargedPercentage, 100)
        XCTAssertEqual(preferences.lowBatteryPercentage, 20)
        XCTAssertEqual(SettingsRootView.chargerNotificationDetail(minutes: 5),
                       "When your Mac draws more than the charger gives for 5 minutes.")
        XCTAssertEqual(SettingsRootView.chargerNotificationDetail(minutes: 1),
                       "When your Mac draws more than the charger gives for 1 minute.")
        XCTAssertEqual(SettingsRootView.fullyChargedNotificationDetail(percentage: 100),
                       "When the battery reaches 100%.")
        XCTAssertEqual(SettingsRootView.lowBatteryNotificationDetail(percentage: 20),
                       "When the battery falls to 20% or below.")
        XCTAssertEqual(SettingsRootView.notificationsUnavailable,
                       "Notifications unavailable. Allow Watt? in System Settings.")
    }

    func testThresholdPreferencesRoundTripAndRejectInvalidValues() {
        let storage = InMemoryStorage()
        let preferences = PreferencesStore(storage: storage)
        preferences.chargerNotification = false
        preferences.fullyChargedNotification = true
        preferences.lowBatteryNotification = true
        preferences.insufficientChargerMinutes = 10
        preferences.fullyChargedPercentage = 90
        preferences.lowBatteryPercentage = 15
        let loaded = PreferencesStore(storage: storage)
        XCTAssertNil(loaded.persistenceFailure)
        XCTAssertFalse(loaded.chargerNotification)
        XCTAssertTrue(loaded.fullyChargedNotification)
        XCTAssertTrue(loaded.lowBatteryNotification)
        XCTAssertEqual(loaded.insufficientChargerMinutes, 10)
        XCTAssertEqual(loaded.insufficientChargerDuration, 600)
        XCTAssertEqual(loaded.fullyChargedPercentage, 90)
        XCTAssertEqual(loaded.lowBatteryPercentage, 15)

        loaded.lowBatteryPercentage = 0
        loaded.lowBatteryPercentage = 100
        loaded.fullyChargedPercentage = 0
        loaded.fullyChargedPercentage = 101
        loaded.insufficientChargerMinutes = 0
        loaded.insufficientChargerMinutes = 61
        XCTAssertEqual(loaded.persistenceFailure, .invalidData)
        XCTAssertEqual(loaded.lowBatteryPercentage, 15)
        XCTAssertEqual(loaded.fullyChargedPercentage, 90)
        XCTAssertEqual(loaded.insufficientChargerMinutes, 10)
        let kept = PreferencesStore(storage: storage)
        XCTAssertEqual(kept.lowBatteryPercentage, 15)
        XCTAssertEqual(kept.fullyChargedPercentage, 90)
        XCTAssertEqual(kept.insufficientChargerMinutes, 10)
    }

    func testLegacyPreferencesWithoutThresholdsKeepTodaysDefaults() throws {
        let storage = InMemoryStorage()
        let original = PreferencesStore(storage: storage)
        original.showSymbol = false
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(storage.values["preferences.v1"])) as? [String: Any])
        for key in ["lowBatteryNotification", "lowBatteryPercentage", "insufficientChargerMinutes", "fullyChargedPercentage"] {
            json.removeValue(forKey: key)
        }
        storage.values["preferences.v1"] = try JSONSerialization.data(withJSONObject: json)
        let loaded = PreferencesStore(storage: storage)
        XCTAssertNil(loaded.persistenceFailure)
        XCTAssertFalse(loaded.showSymbol)
        XCTAssertTrue(loaded.chargerNotification)
        XCTAssertFalse(loaded.fullyChargedNotification)
        XCTAssertFalse(loaded.lowBatteryNotification)
        XCTAssertEqual(loaded.insufficientChargerMinutes, 5)
        XCTAssertEqual(loaded.fullyChargedPercentage, 100)
        XCTAssertEqual(loaded.lowBatteryPercentage, 20)
    }

    func testChargerDurationThresholdMatchesThePanel() {
        let almost = chargerReading(duration: 299.9)
        let fiveMinutes = chargerReading(duration: 300)
        let oneMinute = chargerReading(duration: 60)
        XCTAssertFalse(almost.hasInsufficientCharger)
        XCTAssertTrue(fiveMinutes.hasInsufficientCharger)
        XCTAssertFalse(oneMinute.hasInsufficientCharger)
        XCTAssertTrue(oneMinute.hasInsufficientCharger(minimumDuration: 60))
        XCTAssertFalse(oneMinute.hasInsufficientCharger(minimumDuration: 120))
        XCTAssertEqual(StatusPanelModel(reading: oneMinute).state, .standard)
        XCTAssertEqual(StatusPanelModel(reading: fiveMinutes).state, .insufficientCharger)
        let shortPanel = StatusPanelModel(reading: oneMinute, insufficientChargerMinimumDuration: 60)
        XCTAssertEqual(shortPanel.state, .insufficientCharger)
        XCTAssertEqual(shortPanel.subtitle, oneMinute.insufficientChargerMessage(minimumDuration: 60))
        XCTAssertEqual(StatusPanelModel(reading: oneMinute, insufficientChargerMinimumDuration: 600).state, .standard)
        XCTAssertNil(oneMinute.insufficientChargerMessage(minimumDuration: 600))
    }

    func testLowBatteryAndFullyChargedThresholds() {
        XCTAssertTrue(PowerNotificationThreshold.isLowBattery(battery(percentage: 20, state: .discharging, watts: -10), percentage: 20))
        XCTAssertFalse(PowerNotificationThreshold.isLowBattery(battery(percentage: 21, state: .discharging, watts: -10), percentage: 20))
        XCTAssertFalse(PowerNotificationThreshold.isLowBattery(battery(percentage: 10, state: .charging, watts: 10), percentage: 20))
        XCTAssertFalse(PowerNotificationThreshold.isLowBattery(battery(percentage: 10, state: .discharging, watts: -10), percentage: 0))
        XCTAssertFalse(PowerNotificationThreshold.isLowBattery(battery(percentage: 10, state: .discharging, watts: -10), percentage: 100))

        XCTAssertTrue(PowerNotificationThreshold.isFullyCharged(battery(percentage: 100, state: .full, watts: 0), percentage: 100))
        XCTAssertFalse(PowerNotificationThreshold.isFullyCharged(battery(percentage: 99, state: .charging, watts: 20), percentage: 100))
        XCTAssertFalse(PowerNotificationThreshold.isFullyCharged(battery(percentage: 100, state: .charging, watts: 1), percentage: 100))
        let reached = battery(percentage: 90, state: .charging, watts: 20)
        XCTAssertTrue(PowerNotificationThreshold.isFullyCharged(reached, percentage: 90))
        XCTAssertFalse(PowerNotificationThreshold.isFullyCharged(reached, percentage: 95))
        XCTAssertFalse(PowerNotificationThreshold.isFullyCharged(battery(percentage: 90, state: .discharging, watts: -5), percentage: 90))
    }

    func testPanelUsesTheSameConfiguredDurationAsTheNotification() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.insufficientChargerMinutes = 1
        let reading = chargerReading(duration: 60)
        let store = PowerReadingStore(currentReading: reading, clock: FakeWattClock(now: timestamp))
        let driver = ThresholdNotificationDriver()
        driver.current = .authorized
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
        let panel = StatusPanelModel(reading: store.statusReading,
                                      insufficientChargerMinimumDuration: preferences.insufficientChargerDuration)
        XCTAssertEqual(panel.state, .insufficientCharger)
        let first = await effects.handleInsufficientCharger(store: store)
        let second = await effects.handleInsufficientCharger(store: store)
        XCTAssertEqual(first, .accepted)
        XCTAssertEqual(second, .duplicate)
        XCTAssertEqual(driver.identifiers, ["watt.insufficient-charger.episode"])
        XCTAssertEqual(driver.titles, ["Charger can’t keep up"])

        preferences.insufficientChargerMinutes = 10
        let hidden = StatusPanelModel(reading: store.statusReading,
                                       insufficientChargerMinimumDuration: preferences.insufficientChargerDuration)
        XCTAssertEqual(hidden.state, .standard)
        let blocked = await effects.handleInsufficientCharger(store: store)
        XCTAssertEqual(blocked, .failed(.invalidData))
        XCTAssertEqual(driver.identifiers.count, 1)
    }

    func testTurningANotificationOnRequestsAuthorization() async {
        let driver = ThresholdNotificationDriver()
        driver.requested = .authorized
        let bridge = SystemNotificationBridge(driver: driver)
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter()
        router.notificationBridge = bridge
        router.powerNotificationEffects = PowerNotificationEffects(bridge: bridge, preferences: preferences)
        let store = PowerReadingStore(currentReading: battery(percentage: 64, state: .charging, watts: 20),
                                       clock: FakeWattClock(now: timestamp))
        await SettingsRootView.updateNotification(\.lowBatteryNotification, enabled: false,
                                                  preferences: preferences, router: router, store: store)
        XCTAssertEqual(driver.requests, 0)
        await SettingsRootView.updateNotification(\.fullyChargedNotification, enabled: true,
                                                  preferences: preferences, router: router, store: store)
        XCTAssertEqual(driver.requests, 1)
        XCTAssertEqual(router.notificationAuthorization, .authorized)
        XCTAssertTrue(preferences.fullyChargedNotification)
        await SettingsRootView.updateNotification(\.lowBatteryNotification, enabled: true,
                                                  preferences: preferences, router: router, store: store)
        await SettingsRootView.updateNotification(\.chargerNotification, enabled: false,
                                                  preferences: preferences, router: router, store: store)
        await SettingsRootView.updateNotification(\.chargerNotification, enabled: true,
                                                  preferences: preferences, router: router, store: store)
        XCTAssertEqual(driver.requests, 1, "A determined authorization is not prompted again")
        XCTAssertTrue(preferences.lowBatteryNotification)
        XCTAssertTrue(preferences.chargerNotification)
        XCTAssertTrue(driver.identifiers.isEmpty)
    }

    func testDeniedPermissionSuppressesDeliveryAndKeepsTheSettingsCopy() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.lowBatteryNotification = true
        preferences.fullyChargedNotification = true
        let driver = ThresholdNotificationDriver()
        driver.current = .denied
        let bridge = SystemNotificationBridge(driver: driver)
        let effects = PowerNotificationEffects(bridge: bridge, preferences: preferences)
        let low = PowerReadingStore(currentReading: battery(percentage: 15, state: .discharging, watts: -12),
                                     clock: FakeWattClock(now: timestamp))
        let full = PowerReadingStore(currentReading: battery(percentage: 100, state: .full, watts: 0),
                                      clock: FakeWattClock(now: timestamp))
        let lowEffect = await effects.handleLowBattery(store: low)
        let fullEffect = await effects.handleFullyCharged(store: full)
        let direct = await effects.handle(.lowBattery, episodeID: "again")
        XCTAssertEqual(lowEffect, .openNotificationSettings)
        XCTAssertEqual(fullEffect, .openNotificationSettings)
        XCTAssertEqual(direct, .openNotificationSettings)
        XCTAssertTrue(driver.identifiers.isEmpty)
        XCTAssertEqual(driver.requests, 0)
        XCTAssertEqual(SettingsRootView.notificationsUnavailable,
                       "Notifications unavailable. Allow Watt? in System Settings.")

        let router = AppRouter()
        router.notificationBridge = bridge
        router.powerNotificationEffects = effects
        driver.current = .notDetermined
        driver.requested = .denied
        await SettingsRootView.updateNotification(\.lowBatteryNotification, enabled: false,
                                                  preferences: preferences, router: router, store: low)
        await SettingsRootView.updateNotification(\.lowBatteryNotification, enabled: true,
                                                  preferences: preferences, router: router, store: low)
        XCTAssertEqual(driver.requests, 1)
        XCTAssertEqual(router.notificationAuthorization, .denied)
        XCTAssertTrue(driver.identifiers.isEmpty)
    }

    func testSameEpisodeDoesNotFireTwiceAndANewEpisodeDoes() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.lowBatteryNotification = true
        preferences.fullyChargedNotification = true
        let driver = ThresholdNotificationDriver()
        driver.current = .authorized
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
        let clock = FakeWattClock(now: timestamp)
        let store = PowerReadingStore(currentReading: battery(percentage: 18, state: .discharging, watts: -11), clock: clock)
        let firstLow = await effects.handleLowBattery(store: store)
        let repeatedLow = await effects.handleLowBattery(store: store)
        XCTAssertEqual(firstLow, .accepted)
        XCTAssertEqual(repeatedLow, .duplicate)
        XCTAssertEqual(driver.identifiers, ["watt.low-battery.1"])
        XCTAssertEqual(driver.titles, ["Low battery"])
        XCTAssertEqual(driver.bodies, ["Your battery is at 18%."])

        clock.advance(by: 2)
        XCTAssertTrue(store.accept(battery(percentage: 40, state: .charging, watts: 22, at: clock.now), generation: store.generation))
        let cleared = await effects.handleLowBattery(store: store)
        XCTAssertNil(cleared)
        clock.advance(by: 2)
        XCTAssertTrue(store.accept(battery(percentage: 16, state: .discharging, watts: -9, at: clock.now), generation: store.generation))
        let nextLow = await effects.handleLowBattery(store: store)
        XCTAssertEqual(nextLow, .accepted)
        XCTAssertEqual(driver.identifiers, ["watt.low-battery.1", "watt.low-battery.2"])

        preferences.fullyChargedPercentage = 90
        clock.advance(by: 2)
        XCTAssertTrue(store.accept(battery(percentage: 90, state: .charging, watts: 25, at: clock.now), generation: store.generation))
        let firstFull = await effects.handleFullyCharged(store: store)
        let repeatedFull = await effects.handleFullyCharged(store: store)
        XCTAssertEqual(firstFull, .accepted)
        XCTAssertEqual(repeatedFull, .duplicate)
        XCTAssertEqual(driver.identifiers.last, "watt.fully-charged.1")
        XCTAssertEqual(driver.titles.last, "Battery reached 90%")
        XCTAssertEqual(driver.bodies.last, "Your battery has reached 90%.")
        let lowWhileCharging = await effects.handleLowBattery(store: store)
        XCTAssertNil(lowWhileCharging)
        XCTAssertEqual(driver.identifiers.filter { $0.hasPrefix("watt.low-battery") }.count, 2)
    }

    func testPreferenceOffSuppressesAQualifiedReading() async {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let driver = ThresholdNotificationDriver()
        driver.current = .authorized
        let effects = PowerNotificationEffects(bridge: SystemNotificationBridge(driver: driver), preferences: preferences)
        let store = PowerReadingStore(currentReading: battery(percentage: 10, state: .discharging, watts: -8),
                                       clock: FakeWattClock(now: timestamp))
        let off = await effects.handleLowBattery(store: store)
        XCTAssertEqual(off, .preferenceOff)
        preferences.lowBatteryNotification = true
        let firstPass = await effects.evaluate(store: store)
        let secondPass = await effects.evaluate(store: store)
        XCTAssertEqual(firstPass, [.accepted])
        XCTAssertEqual(secondPass, [.duplicate])
        XCTAssertEqual(driver.identifiers, ["watt.low-battery.1"])
    }

    private func chargerReading(duration: TimeInterval) -> PowerReading {
        PowerReading(mode: .onBattery, watts: -13, batteryPercentage: 64, timestamp: timestamp,
                     batteryState: .discharging,
                     capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
                     source: .fixture, chargerWatts: 65, systemWatts: 78,
                     chargerThreshold: .init(episodeID: "episode", observedAt: timestamp, sustainedDuration: duration))
    }

    private func battery(percentage: Int, state: BatteryState, watts: Double, at timestamp: Date? = nil) -> PowerReading {
        let when = timestamp ?? self.timestamp
        let charging = watts >= 0
        return PowerReading(mode: charging ? .charging : .onBattery, watts: watts, batteryPercentage: percentage,
                            timestamp: when, batteryState: state,
                            capabilities: .init(battery: .available, charger: charging ? .available : .disconnected, systemDraw: .available),
                            source: .fixture, chargerWatts: charging ? 65 : nil, systemWatts: abs(watts))
    }
}

@MainActor
private final class ThresholdNotificationDriver: NotificationSystemDriver {
    var current: NotificationPermission = .notDetermined
    var requested: NotificationPermission = .authorized
    var requests = 0
    var identifiers: [String] = []
    var titles: [String] = []
    var bodies: [String] = []
    func permission() async -> NotificationPermission { current }
    func requestPermission() async throws {
        requests += 1
        current = requested
    }
    func enqueue(identifier: String, title: String, body: String) async throws {
        identifiers.append(identifier)
        titles.append(title)
        bodies.append(body)
    }
}
