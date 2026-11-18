import XCTest
import IOKit.ps
@testable import Watt

final class P01TelemetryTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_700_000_000)
    private func battery(_ changes: [String: Any] = [:]) -> [String: Any] {
        [kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSIsPresentKey: true,
         kIOPSIsChargingKey: true, kIOPSIsChargedKey: false,
         kIOPSPowerSourceStateKey: kIOPSACPowerValue,
         kIOPSCurrentCapacityKey: 64, kIOPSMaxCapacityKey: 100].merging(changes) { _, new in new }
    }
    private func parse(_ descriptions: [[String: Any]], source: String? = kIOPSACPowerValue) throws -> PowerReading {
        try SystemPowerSourceParser.parse(.init(descriptions: descriptions, providingSource: source, timestamp: time))
    }

    private func parseSnapshot(_ descriptions: [[String: Any]], source: String? = kIOPSACPowerValue,
                               properties: [String: Any]? = nil, external: [String: Any]? = nil) throws -> PowerReading {
        try SystemPowerSourceParser.parse(.init(
            descriptions: descriptions, providingSource: source, timestamp: time,
            batteryProperties: properties, externalAdapter: external))
    }

    private func chargingTelemetry(description: String = "pd charger") -> [String: Any] {
        [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ],
            "AdapterDetails": ["Watts": 96, "Description": description]
        ]
    }

    private func parseTelemetry(_ telemetry: [String: Any], source: String? = kIOPSACPowerValue) throws -> PowerReading {
        try SystemPowerSourceParser.parse(.init(
            descriptions: [battery()], providingSource: source, timestamp: time,
            batteryProperties: ["PowerTelemetryData": telemetry]))
    }

    func testPresentChargingBatteryHasMetadataButNeverWatts() throws {
        let reading = try parse([battery(["Watts": 140, "Voltage": 12000, "Amperage": 2000])])
        XCTAssertEqual(reading.batteryState, .charging)
        XCTAssertEqual(reading.mode, .charging)
        XCTAssertEqual(reading.batteryPercentage, 64)
        XCTAssertEqual(reading.source, .system)
        XCTAssertEqual(reading.timestamp, time)
        XCTAssertEqual(reading.capabilities, .init(battery: .available, charger: .unsupported, systemDraw: .unsupported, components: .unsupported))
        XCTAssertNil(reading.watts)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertNil(reading.systemWatts)
        XCTAssertTrue(reading.components.isEmpty)
        for mode in WattDisplayMode.allCases { XCTAssertNil(reading.value(for: mode)) }
        XCTAssertEqual(PowerFormatter.watts(reading.watts), "—")
        try reading.validate()
    }

    func testRegistryTelemetryMapsChargingRateChargerInputAndSystemDraw() throws {
        let reading = try parseTelemetry([
            "BatteryPower": 42_100,
            "SystemPowerIn": 65_000,
            "SystemLoad": 22_900
        ])

        XCTAssertEqual(reading.batteryState, .charging)
        XCTAssertEqual(try XCTUnwrap(reading.watts), 42.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 65, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.systemWatts), 22.9, accuracy: 0.001)
        XCTAssertEqual(reading.capabilities,
                       .init(battery: .available, charger: .available,
                             systemDraw: .available, components: .unsupported))
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .delta)), 42.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .charger)), 65, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .draw)), 22.9, accuracy: 0.001)
        try reading.validate()
    }

    func testRegistryTelemetrySurvivesUnknownBatteryState() throws {
        let snapshot = battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false
        ])
        let reading = try SystemPowerSourceParser.parse(.init(
            descriptions: [snapshot], providingSource: kIOPSACPowerValue,
            timestamp: time,
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": 0,
                "SystemPowerIn": 24_000,
                "SystemLoad": 18_000
            ]]))

        XCTAssertEqual(reading.batteryState, .unknown)
        XCTAssertEqual(reading.mode, .chargerInput)
        XCTAssertEqual(reading.capabilities.battery, .available)
        XCTAssertEqual(try XCTUnwrap(reading.watts), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 24, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.systemWatts), 18, accuracy: 0.001)
        XCTAssertTrue(reading.hasCurrentSample)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .charger)), 24, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .draw)), 18, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .delta)), 0, accuracy: 0.001)
        let panel = StatusPanelModel(reading: reading)
        XCTAssertEqual(panel.state, .standard)
        XCTAssertEqual(panel.title, "Not charging")
        XCTAssertEqual(panel.headlineValue, "0.0 W")
        XCTAssertEqual(panel.battery, "0.0 W")
        XCTAssertNotEqual(panel.headlineValue, "—")
        XCTAssertEqual(panel.charger, "24.0 W")
        XCTAssertEqual(panel.system, "18.0 W")
        XCTAssertNil(panel.panelHeight)
        try reading.validate()
    }

    func testBatterylessSystemTelemetryUsesSystemDrawMode() throws {
        let reading = try SystemPowerSourceParser.parse(.init(
            descriptions: [], providingSource: kIOPSACPowerValue, timestamp: time,
            batteryProperties: ["PowerTelemetryData": ["SystemLoad": 12_500]]))

        XCTAssertEqual(reading.batteryState, .noBattery)
        XCTAssertEqual(reading.mode, .systemDraw)
        XCTAssertTrue(reading.hasCurrentSample)
        XCTAssertEqual(try XCTUnwrap(reading.value(for: .draw)), 12.5, accuracy: 0.001)
        try reading.validate()
    }

    func testRegistryTelemetryUsesNegativeBatteryRateWhenDischarging() throws {
        let discharging = battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue
        ])
        let reading = try SystemPowerSourceParser.parse(.init(
            descriptions: [discharging], providingSource: kIOPSBatteryPowerValue,
            timestamp: time,
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": 18_400,
                "SystemPowerIn": 0,
                "SystemLoad": 18_400
            ]]))

        XCTAssertEqual(try XCTUnwrap(reading.watts), -18.4, accuracy: 0.001)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertEqual(try XCTUnwrap(reading.systemWatts), 18.4, accuracy: 0.001)
        XCTAssertEqual(reading.capabilities.charger, .disconnected)
        try reading.validate()
    }

    @MainActor
    func testLiveUnpluggedChargerModeUsesMeasuredSystemDraw() throws {
        let discharging = battery([
            kIOPSIsChargingKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue
        ])
        let reading = try SystemPowerSourceParser.parse(.init(
            descriptions: [discharging], providingSource: kIOPSBatteryPowerValue,
            timestamp: time,
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": 12_000,
                "SystemPowerIn": 0,
                "SystemLoad": 18_400
            ]]))
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .charger
        let label = MenuBarStatusLabel(reading: reading, preferences: preferences)
        XCTAssertEqual(reading.mode, .onBattery)
        XCTAssertEqual(label.text, "18.4 W")
        XCTAssertEqual(label.symbolName, "battery.100percent")
    }

    func testRegistryTelemetryPreservesZeroRateForFullBattery() throws {
        let full = battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: true,
            kIOPSCurrentCapacityKey: 100
        ])
        let reading = try SystemPowerSourceParser.parse(.init(
            descriptions: [full], providingSource: kIOPSACPowerValue,
            timestamp: time,
            batteryProperties: ["PowerTelemetryData": [
                "BatteryPower": 0,
                "SystemPowerIn": 6_193,
                "SystemLoad": 6_193
            ]]))

        XCTAssertEqual(reading.batteryState, .full)
        XCTAssertEqual(try XCTUnwrap(reading.watts), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 6.193, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.systemWatts), 6.193, accuracy: 0.001)
        try reading.validate()
    }

    func testMalformedRegistryTelemetryDoesNotFabricateMeasurements() throws {
        let reading = try parseTelemetry([
            "BatteryPower": -1,
            "SystemPowerIn": "65000",
            "SystemLoad": true
        ])

        XCTAssertNil(reading.watts)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertNil(reading.systemWatts)
        XCTAssertEqual(reading.capabilities.charger, .unsupported)
        XCTAssertEqual(reading.capabilities.systemDraw, .unsupported)
        try reading.validate()
    }

    func testChargedIsNotInferredFromPercentageAndHoldIsNotGuessed() throws {
        let charged = try parse([battery([kIOPSIsChargingKey: false, kIOPSIsChargedKey: true, kIOPSCurrentCapacityKey: 95])])
        XCTAssertEqual(charged.batteryState, .full)
        XCTAssertEqual(charged.mode, .charged)
        XCTAssertEqual(try parse([battery([kIOPSCurrentCapacityKey: 100])]).batteryState, .charging)
        XCTAssertEqual(try parse([battery([kIOPSIsChargingKey: false])]).batteryState, .unknown)
        XCTAssertEqual(try parse([battery([kIOPSIsChargedKey: true])]).batteryState, .unknown)
    }

    func testDischargingAndProvidingSourcesRemainIndependent() throws {
        let discharging = battery([kIOPSIsChargingKey: false, kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue])
        for (source, detail) in [(kIOPSACPowerValue, "AC"), (kIOPSBatteryPowerValue, "Battery"), (kIOPMUPSPowerKey, "UPS")] {
            let reading = try parse([discharging], source: source)
            XCTAssertEqual(reading.batteryState, .discharging)
            XCTAssertEqual(reading.mode, .onBattery)
            XCTAssertEqual(reading.detail, "Power source: \(detail)")
        }
        XCTAssertNil(try parse([discharging], source: "invalid").detail)
        XCTAssertNil(try parse([discharging], source: nil).detail)
    }

    func testAbsentBatteryAndUPSDoNotBecomeInternalBattery() throws {
        for descriptions in [[], [battery([kIOPSIsPresentKey: false])], [[kIOPSTypeKey: kIOPSUPSType, kIOPSIsPresentKey: true]]] {
            let reading = try parse(descriptions)
            XCTAssertEqual(reading.batteryState, .noBattery)
            XCTAssertEqual(reading.capabilities.battery, .unsupported)
            XCTAssertNil(reading.batteryPercentage)
            XCTAssertNil(reading.watts)
            try reading.validate()
        }
        XCTAssertThrowsError(try parse([battery(), battery()]))
    }

    func testMissingAndInvalidKeysNeverBecomeFalseOrZero() throws {
        for description: [String: Any] in [[:], [kIOPSTypeKey: kIOPSInternalBatteryType], battery([kIOPSIsPresentKey: 1]), battery([kIOPSIsPresentKey: "true"])] {
            let reading = try parse([description])
            XCTAssertEqual(reading.batteryState, .unknown)
            XCTAssertEqual(reading.capabilities.battery, .unknown)
            XCTAssertNil(reading.batteryPercentage)
        }
        XCTAssertEqual(try parse([battery([kIOPSIsChargingKey: 1])]).batteryState, .unknown)
        for key in [kIOPSIsChargingKey, kIOPSPowerSourceStateKey] {
            var description = battery(); description.removeValue(forKey: key)
            XCTAssertEqual(try parse([description]).batteryState, .unknown)
        }
        for value: Any in ["64", true, -1, 101, Double.nan, Double.infinity, 2.5] {
            XCTAssertNil(try parse([battery([kIOPSCurrentCapacityKey: value])]).batteryPercentage)
        }
        for value: Any in ["100", false, 0, -100, Double.nan] {
            XCTAssertNil(try parse([battery([kIOPSMaxCapacityKey: value])]).batteryPercentage)
        }
        var missing = battery(); missing.removeValue(forKey: kIOPSCurrentCapacityKey)
        XCTAssertNil(try parse([missing]).batteryPercentage)
        XCTAssertEqual(try parse([battery([kIOPSCurrentCapacityKey: 0])]).batteryPercentage, 0)
        XCTAssertEqual(try parse([battery([kIOPSCurrentCapacityKey: 2500, kIOPSMaxCapacityKey: 5000])]).batteryPercentage, 50)
    }

    @MainActor func testClockFreshStaleRecoveryAndFailures() async throws {
        let clock = FakeWattClock(now: time)
        let description = battery()
        let service = SystemPowerSourceTelemetryService(clock: clock) { date in
            .init(descriptions: [description], providingSource: kIOPSACPowerValue, timestamp: date)
        }
        guard case .success(let reading) = await service.sample() else { return XCTFail("Expected sample") }
        let store = PowerReadingStore(currentReading: reading, clock: clock)
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
        clock.advance(by: 6)
        XCTAssertEqual(store.freshness(maximumAge: 5), .stale)
        guard case .success(let next) = await service.sample() else { return XCTFail("Expected fresh sample") }
        XCTAssertTrue(store.accept(next, generation: store.generation))
        XCTAssertEqual(store.freshness(maximumAge: 5), .fresh)
        let cached = SystemPowerSourceTelemetryService(clock: clock) { _ in
            .init(descriptions: [description], providingSource: nil, timestamp: reading.timestamp)
        }
        guard case .success(let stale) = await cached.sample() else { return XCTFail("Expected cached sample") }
        XCTAssertEqual(stale.timestamp, reading.timestamp)
        XCTAssertEqual(stale.freshness(at: clock.now, maximumAge: 5), .stale)
        let missing = SystemPowerSourceTelemetryService(clock: clock) { _ in nil }
        assertFailure(await missing.sample(), .unknownStatus)
        for date in [clock.now.addingTimeInterval(1), Date(timeIntervalSince1970: .nan)] {
            let invalid = SystemPowerSourceTelemetryService(clock: clock) { _ in
                .init(descriptions: [], providingSource: nil, timestamp: date)
            }
            assertFailure(await invalid.sample(), .invalidData)
        }
    }

    @MainActor func testCancellationBeforeAndDuringProvider() async {
        var called = false
        let service = SystemPowerSourceTelemetryService { date in
            called = true
            return .init(descriptions: [], providingSource: nil, timestamp: date)
        }
        let task = Task { @MainActor in await service.sample() }
        task.cancel()
        assertFailure(await task.value, .cancelled)
        XCTAssertFalse(called)
        let interrupted = SystemPowerSourceTelemetryService { date in
            withUnsafeCurrentTask { $0?.cancel() }
            return .init(descriptions: [], providingSource: nil, timestamp: date)
        }
        let during = Task { @MainActor in await interrupted.sample() }
        assertFailure(await during.value, .cancelled)
    }

    func testAppleSiliconChargingFillsAdapterSubtitleAndTimeToFull() throws {
        let reading = try parseSnapshot([battery([
            kIOPSTimeToFullChargeKey: 38,
            kIOPSTimeToEmptyKey: -1
        ])], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ],
            "AdapterDetails": [
                "Watts": 96,
                "Description": "pd charger",
                "Current": 4_800,
                "AdapterVoltage": 20_000,
                "IsWireless": false,
                "FamilyCode": -536_854_518,
                "SharedSource": false
            ]
        ])

        XCTAssertEqual(reading.batteryState, .charging)
        XCTAssertEqual(try XCTUnwrap(reading.watts), 42.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 65, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.systemWatts), 22.9, accuracy: 0.001)
        XCTAssertEqual(reading.adapterRatedWatts, 96)
        XCTAssertEqual(reading.adapterName, "USB-C charger")
        XCTAssertEqual(reading.adapterSubtitle, "96 W USB-C charger")
        XCTAssertEqual(reading.detail, "full in about 38 min")
        let panel = StatusPanelModel(reading: reading)
        XCTAssertEqual(panel.charger, "65.0 W")
        XCTAssertEqual(panel.battery, "+42.1 W")
        XCTAssertEqual(panel.chargerSubtitle, "96 W USB-C charger")
        XCTAssertEqual(panel.subtitle, "64% · full in about 38 min")
        XCTAssertEqual(panel.accessibilityRows.first?.subtitle, "96 W USB-C charger")
        XCTAssertNotEqual(panel.charger, "96.0 W")
        XCTAssertNotEqual(panel.charger, "0.0 W")
        let presented = reading.presenting(nil)
        XCTAssertEqual(presented.adapterRatedWatts, 96)
        XCTAssertEqual(presented.adapterName, "USB-C charger")
        XCTAssertEqual(presented.detail, reading.detail)
        let fixture = StatusPanelModel(reading: reading, chargerDescription: "67 W USB-C charger")
        XCTAssertEqual(fixture.chargerSubtitle, "67 W USB-C charger")
        try reading.validate()
    }

    func testIntelRawAdapterNameKeepsMeasuredChargeRate() throws {
        let details = NSMutableDictionary()
        details["Watts"] = 87
        details["Description"] = ""
        details["Name"] = "Apple 87W USB-C Power Adapter"
        details["IsWireless"] = false
        details["Current"] = 4_300
        let reading = try parseSnapshot([battery([kIOPSTimeToFullChargeKey: 90])], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 20_000,
                "SystemPowerIn": 60_000,
                "SystemLoad": 40_000
            ],
            "AppleRawAdapterDetails": details
        ])

        XCTAssertEqual(try XCTUnwrap(reading.watts), 20, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 60, accuracy: 0.001)
        XCTAssertEqual(reading.adapterSubtitle, "Apple 87 W USB-C Power Adapter")
        XCTAssertEqual(reading.detail, "full in about 1 h 30 min")
        let panel = StatusPanelModel(reading: reading)
        XCTAssertEqual(panel.charger, "60.0 W")
        XCTAssertEqual(panel.battery, "+20.0 W")
        XCTAssertEqual(panel.chargerSubtitle, reading.adapterSubtitle)
        try reading.validate()
    }

    func testOnBatteryShowsTimeToEmptyAndHidesLingeringAdapter() throws {
        let reading = try parseSnapshot([battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: 250,
            kIOPSTimeToFullChargeKey: 12
        ])], source: kIOPSBatteryPowerValue, properties: [
            "PowerTelemetryData": [
                "BatteryPower": 18_400,
                "SystemPowerIn": 0,
                "SystemLoad": 18_400
            ],
            "AdapterDetails": ["Watts": 96, "Description": "pd charger"]
        ])

        XCTAssertEqual(reading.batteryState, .discharging)
        XCTAssertEqual(try XCTUnwrap(reading.watts), -18.4, accuracy: 0.001)
        XCTAssertNil(reading.chargerWatts)
        XCTAssertEqual(reading.capabilities.charger, .disconnected)
        XCTAssertEqual(reading.detail, "about 4 h 10 min left")
        XCTAssertFalse(reading.detail?.contains("12") ?? true)
        let panel = StatusPanelModel(reading: reading)
        XCTAssertEqual(panel.charger, "Unplugged")
        XCTAssertNil(panel.chargerSubtitle)
        XCTAssertEqual(panel.battery, "−18.4 W")
        XCTAssertEqual(panel.subtitle, "64% · about 4 h 10 min left")
        try reading.validate()
    }

    func testFullChargeAndUnfinishedEstimatesOmitTime() throws {
        let full = try parseSnapshot([battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: true,
            kIOPSCurrentCapacityKey: 100,
            kIOPSTimeToFullChargeKey: 0,
            kIOPSTimeToEmptyKey: -1
        ])], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 0,
                "SystemPowerIn": 19_800,
                "SystemLoad": 19_800
            ],
            "AdapterDetails": ["Watts": 96.0, "Description": "usb-c"]
        ])
        XCTAssertEqual(full.batteryState, .full)
        XCTAssertEqual(full.detail, "Power source: AC")
        XCTAssertEqual(full.adapterSubtitle, "96 W USB-C charger")
        let fullPanel = StatusPanelModel(reading: full)
        XCTAssertEqual(fullPanel.subtitle, "100% · running straight off the charger")
        XCTAssertEqual(fullPanel.charger, "19.8 W")
        XCTAssertEqual(fullPanel.chargerSubtitle, "96 W USB-C charger")
        XCTAssertFalse(fullPanel.subtitle?.contains("0 min") ?? false)

        let calculating = try parseSnapshot([battery([
            kIOPSTimeToFullChargeKey: -1,
            kIOPSTimeToEmptyKey: "Calculating"
        ])], properties: chargingTelemetry())
        XCTAssertEqual(calculating.detail, "Power source: AC")
        XCTAssertNil(calculating.detail.flatMap { $0.contains("min") ? $0 : nil })

        let unknown = try parseSnapshot([battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false,
            kIOPSTimeToFullChargeKey: 38
        ])], properties: chargingTelemetry())
        XCTAssertEqual(unknown.batteryState, .unknown)
        XCTAssertEqual(unknown.detail, "Power source: AC")
        try full.validate()
    }

    func testMissingAndOddAdapterKeysNeverBecomeZeroOrATime() throws {
        let missing = try parseSnapshot([battery()], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ]
        ])
        XCTAssertNil(missing.adapterRatedWatts)
        XCTAssertNil(missing.adapterName)
        XCTAssertNil(missing.adapterSubtitle)
        XCTAssertNil(StatusPanelModel(reading: missing).chargerSubtitle)
        XCTAssertEqual(missing.detail, "Power source: AC")
        XCTAssertEqual(try XCTUnwrap(missing.chargerWatts), 65, accuracy: 0.001)

        let longName = String(repeating: "USB-C ", count: 20)
        let long = try parseSnapshot([battery()], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ],
            "AdapterDetails": ["Watts": 96, "Description": longName + "\u{0001}"]
        ])
        XCTAssertEqual(long.adapterRatedWatts, 96)
        XCTAssertNil(long.adapterName)
        XCTAssertEqual(long.adapterSubtitle, "96 W charger")
        XCTAssertEqual(try XCTUnwrap(long.chargerWatts), 65, accuracy: 0.001)
        try long.validate()

        let measured: [String: Any] = [
            "BatteryPower": 42_100,
            "SystemPowerIn": 65_000,
            "SystemLoad": 22_900
        ]
        let oddWatts: [Any] = ["96", true, false, -1, 0, 501, 96.5, Double.nan, Double.infinity]
        for watts in oddWatts {
            let reading = try parseSnapshot([battery()], properties: [
                "PowerTelemetryData": measured,
                "AdapterDetails": [
                    "Watts": watts,
                    "Current": 4_800,
                    "AdapterVoltage": 20_000,
                    "Description": watts,
                    "AdapterWattage": 96
                ],
                "LegacyBatteryInfo": ["Watts": 96],
                "DesignCapacity": 5_000
            ])
            XCTAssertNil(reading.adapterRatedWatts, "\(watts)")
            XCTAssertNil(reading.adapterSubtitle, "\(watts)")
            XCTAssertEqual(reading.detail, "Power source: AC", "\(watts)")
            XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 65, accuracy: 0.001, "\(watts)")
            XCTAssertEqual(StatusPanelModel(reading: reading).charger, "65.0 W", "\(watts)")
            try reading.validate()
        }

        let hiddenMinutes: [Any] = [-1, -2, 0, 65_535, 2_881, "38", true, 38.5, Double.nan]
        for minutes in hiddenMinutes {
            let reading = try parseSnapshot([battery([
                kIOPSTimeToFullChargeKey: minutes,
                kIOPSTimeToEmptyKey: minutes
            ])], properties: chargingTelemetry(description: "   \n  "))
            XCTAssertEqual(reading.detail, "Power source: AC", "\(minutes)")
            XCTAssertEqual(reading.adapterSubtitle, "96 W charger", "\(minutes)")
            XCTAssertFalse(reading.detail?.contains("0 min") ?? false, "\(minutes)")
            try reading.validate()
        }

        let blank = try parseSnapshot([battery([kIOPSTimeToFullChargeKey: 38.0])], properties: chargingTelemetry(description: "charger"))
        XCTAssertEqual(blank.detail, "full in about 38 min")
        XCTAssertEqual(blank.adapterSubtitle, "96 W charger")
        let hour = try parseSnapshot([battery([kIOPSTimeToFullChargeKey: 60])])
        XCTAssertEqual(hour.detail, "full in about 1 h")
        let mixed = try parseSnapshot([battery([kIOPSTimeToFullChargeKey: 70])])
        XCTAssertEqual(mixed.detail, "full in about 1 h 10 min")
        let minute = try parseSnapshot([battery([
            kIOPSIsChargingKey: false,
            kIOPSIsChargedKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: 1
        ])], source: kIOPSBatteryPowerValue)
        XCTAssertEqual(minute.detail, "about 1 min left")
        XCTAssertNil(PowerReading.sampleCharging.adapterSubtitle)
        XCTAssertNil(StatusPanelModel(reading: .sampleCharging).chargerSubtitle)
    }

    func testDesktopAndUPSOmitTimeToFull() throws {
        var absent = battery([kIOPSIsPresentKey: false, kIOPSTimeToFullChargeKey: 40])
        absent["Watts"] = 900
        let desktop = try parseSnapshot([
            absent
        ], properties: [
            "PowerTelemetryData": ["SystemLoad": 38_200]
        ], external: ["Watts": 96, "Description": "pd charger", "Source": "External"])
        XCTAssertEqual(desktop.batteryState, .noBattery)
        XCTAssertNil(desktop.watts)
        XCTAssertNil(desktop.batteryPercentage)
        XCTAssertEqual(try XCTUnwrap(desktop.systemWatts), 38.2, accuracy: 0.001)
        XCTAssertEqual(desktop.adapterSubtitle, "96 W USB-C charger")
        XCTAssertEqual(desktop.detail, "96 W USB-C charger")
        XCTAssertFalse(desktop.detail?.contains("min") ?? true)
        let panel = StatusPanelModel(reading: desktop)
        XCTAssertTrue(panel.isDesktop)
        XCTAssertEqual(panel.headlineValue, "38.2 W")
        XCTAssertEqual(panel.subtitle, "96 W USB-C charger")
        XCTAssertFalse(panel.accessibilityRows.contains { $0.label == "Charger input" })
        try desktop.validate()

        let bareDesktop = try parseSnapshot([], properties: [
            "PowerTelemetryData": ["SystemLoad": 12_500]
        ])
        XCTAssertEqual(bareDesktop.batteryState, .noBattery)
        XCTAssertNil(bareDesktop.adapterSubtitle)
        XCTAssertEqual(bareDesktop.detail, "Power source: AC")

        var upsDescription: [String: Any] = [
            kIOPSTypeKey: kIOPSUPSType,
            kIOPSIsPresentKey: true,
            kIOPSTimeToFullChargeKey: 38,
            kIOPSTimeToEmptyKey: 120
        ]
        upsDescription["Watts"] = 4_000
        upsDescription["Description"] = "pd charger"
        let ups = try parseSnapshot([upsDescription], source: kIOPMUPSPowerKey, properties: [
            "AdapterDetails": ["Watts": "nope", "Current": 9_000],
            "LegacyBatteryInfo": ["Watts": 96]
        ], external: ["Watts": 0, "Source": "Internal"])
        XCTAssertEqual(ups.batteryState, .noBattery)
        XCTAssertNil(ups.watts)
        XCTAssertNil(ups.adapterSubtitle)
        XCTAssertEqual(ups.detail, "Power source: UPS")
        XCTAssertFalse(ups.detail?.contains("min") ?? false)

        let upsAdapter = try parseSnapshot([[
            kIOPSTypeKey: kIOPSUPSType,
            kIOPSIsPresentKey: true,
            kIOPSTimeToEmptyKey: 90
        ]], source: kIOPMUPSPowerKey, external: [
            "Watts": 150,
            "Description": "magsafe 3"
        ])
        XCTAssertEqual(upsAdapter.batteryState, .noBattery)
        XCTAssertNil(upsAdapter.watts)
        XCTAssertEqual(upsAdapter.adapterSubtitle, "150 W MagSafe charger")
        XCTAssertEqual(upsAdapter.detail, "150 W MagSafe charger")
        XCTAssertFalse(upsAdapter.detail?.contains("min") ?? true)
        try upsAdapter.validate()
    }

    func testAdapterSourcesPreferTheFirstRealWattsAndName() throws {
        let reading = try parseSnapshot([battery()], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ],
            "AdapterDetails": ["Watts": 0, "Description": "", "Current": 4_800],
            "AppleRawAdapterDetails": ["Name": "magsafe 3", "Manufacturer": "Apple Inc."]
        ], external: [
            "Watts": 140,
            "Description": "pd charger",
            "AdapterID": 0,
            "FamilyCode": 1
        ])
        XCTAssertEqual(reading.adapterRatedWatts, 140)
        XCTAssertEqual(reading.adapterName, "MagSafe charger")
        XCTAssertEqual(reading.adapterSubtitle, "140 W MagSafe charger")
        XCTAssertEqual(try XCTUnwrap(reading.chargerWatts), 65, accuracy: 0.001)

        let externalOnly = try parseSnapshot([battery()], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ]
        ], external: ["Watts": 67])
        XCTAssertEqual(externalOnly.adapterSubtitle, "67 W charger")
        XCTAssertEqual(externalOnly.detail, "Power source: AC")
        XCTAssertEqual(StatusPanelModel(reading: externalOnly).charger, "65.0 W")

        let trailing = try parseSnapshot([battery()], properties: [
            "AdapterDetails": ["Watts": 30, "Name": "USB-C Port 2"]
        ])
        XCTAssertEqual(trailing.adapterSubtitle, "30 W USB-C Port 2")
        let suffixed = try parseSnapshot([battery()], properties: [
            "AdapterDetails": ["Watts": 96, "Name": "Compact 96W"]
        ])
        XCTAssertEqual(suffixed.adapterSubtitle, "Compact 96 W")
        try trailing.validate()
        try suffixed.validate()

        let conflicting = try parseSnapshot([battery()], properties: [
            "PowerTelemetryData": [
                "BatteryPower": 42_100,
                "SystemPowerIn": 65_000,
                "SystemLoad": 22_900
            ],
            "AdapterDetails": ["Watts": 67, "Name": "96W USB-C Power Adapter"]
        ])
        XCTAssertEqual(conflicting.adapterSubtitle, "67 W charger")
        let conflicted = StatusPanelModel(reading: conflicting)
        XCTAssertEqual(conflicted.charger, "65.0 W")
        XCTAssertEqual(conflicted.chargerSubtitle, "67 W charger")
        XCTAssertEqual(conflicted.battery, "+42.1 W")
        try reading.validate()
    }

    func testReleaseChargerCopyIsNotAFixtureString() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let menu = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Views/MenuBarRootView.swift"), encoding: .utf8)
        let release = menu.components(separatedBy: "#else").dropFirst().joined(separator: "#else")
        XCTAssertFalse(release.contains("USB-C charger"))
        XCTAssertTrue(release.contains("nil"))
        let service = try String(contentsOf: root.appendingPathComponent("Services/SystemPowerSourceTelemetryService.swift"), encoding: .utf8)
        XCTAssertTrue(service.contains("IOPSCopyExternalPowerAdapterDetails"))
        XCTAssertTrue(service.contains("AdapterDetails"))
        XCTAssertTrue(service.contains("kIOPSTimeToFullChargeKey"))
        XCTAssertTrue(service.contains("kIOPSTimeToEmptyKey"))
        XCTAssertTrue(service.contains("kIOPSPowerAdapterWattsKey"))
        for forbidden in ["Timer(", "Timer.", "Task.sleep", "scheduledTimer", "asyncAfter"] {
            XCTAssertFalse(service.contains(forbidden), forbidden)
        }
    }

    @MainActor func testPhysicalHostPublicAPISmoke() async throws {
        guard ProcessInfo.processInfo.environment["WATT_P01_HOST_PROBE"] == "1" else {
            throw XCTSkip("Opt-in physical-host metadata probe; not fixture evidence")
        }
        let service = SystemPowerSourceTelemetryService()
        guard case .success(let reading) = await service.sample() else { return XCTFail("Host snapshot unavailable") }
        try reading.validate()
        XCTAssertEqual(reading.source, .system)
        if reading.batteryState != .noBattery {
            XCTAssertEqual(reading.capabilities.battery, .available)
            XCTAssertNotNil(reading.watts)
        }
        XCTAssertEqual(reading.capabilities.systemDraw, .available)
        XCTAssertNotNil(reading.systemWatts)
        if reading.capabilities.charger == .available {
            XCTAssertNotNil(reading.chargerWatts)
        }
        print("P01 HOST: battery=\(reading.batteryState.rawValue) percentage=\(String(describing: reading.batteryPercentage)) batteryWatts=\(String(describing: reading.watts)) chargerWatts=\(String(describing: reading.chargerWatts)) systemWatts=\(String(describing: reading.systemWatts)) adapter=\(reading.adapterSubtitle ?? "none") detail=\(reading.detail ?? "none") observedAt=\(reading.timestamp)")
    }

    private func assertFailure(_ outcome: ServiceOutcome<PowerReading>, _ expected: ServiceFailure, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let failure) = outcome else { return XCTFail("Expected failure", file: file, line: line) }
        XCTAssertEqual(failure, expected, file: file, line: line)
    }
}
