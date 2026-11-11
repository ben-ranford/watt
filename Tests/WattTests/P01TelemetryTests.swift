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
        if reading.detail == "Power source: AC" {
            XCTAssertEqual(reading.capabilities.charger, .available)
            XCTAssertNotNil(reading.chargerWatts)
        }
        print("P01 HOST: battery=\(reading.batteryState.rawValue) percentage=\(String(describing: reading.batteryPercentage)) batteryWatts=\(String(describing: reading.watts)) chargerWatts=\(String(describing: reading.chargerWatts)) systemWatts=\(String(describing: reading.systemWatts)) source=\(reading.detail ?? "unknown") observedAt=\(reading.timestamp)")
    }

    private func assertFailure(_ outcome: ServiceOutcome<PowerReading>, _ expected: ServiceFailure, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let failure) = outcome else { return XCTFail("Expected failure", file: file, line: line) }
        XCTAssertEqual(failure, expected, file: file, line: line)
    }
}
