import XCTest
@testable import Watt

@MainActor
final class StatusPanelVoiceOverSummaryTests: XCTestCase {
    func testChargingPreservesJ111Phrase() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleCharging).voiceOverSummary,
                       "Charging, +42.1 W, Into battery · 64% · full in 38 min")
    }

    #if DEBUG || SWIFT_PACKAGE
    func testDischargingPreservesOnBatteryPhrase() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleOnBattery).voiceOverSummary,
                       "On battery, −18.4 W, From battery · 64% · about 4 h 10 min left")
    }

    func testDesktopDoesNotAnnounceBatteryFlow() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleDesktopSystemDraw).voiceOverSummary,
                       "Drawing, 38.2 W, No battery, so it’s all draw")
    }

    func testFullOnAdapterDoesNotAnnounceBatteryFlow() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleFullOnAdapter).voiceOverSummary,
                       "Full, 0.0 W, 100% · running straight off the charger")
    }

    func testLegacyFullDoesNotAnnounceBatteryFlow() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleChargedOnAdapter).voiceOverSummary,
                       "Fully Charged, 0.0 W, 100%")
    }

    func testOptimisedHoldDoesNotAnnounceBatteryFlow() {
        XCTAssertEqual(StatusPanelModel(reading: .sampleChargingHold).voiceOverSummary,
                       "Holding at 80%, 0.0 W, Because Optimised Battery Charging is on. Charging resumes before you usually unplug.")
    }

    func testGenericHoldDoesNotAnnounceBatteryFlow() {
        let reading = PowerReading(mode: .charged, watts: 0, batteryPercentage: 80,
            timestamp: PowerReading.sampleChargingHold.timestamp, batteryState: .chargingHold,
            capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
            source: .fixture, chargerWatts: 21.4, systemWatts: 21.4)
        XCTAssertEqual(StatusPanelModel(reading: reading).voiceOverSummary,
                       "Charging Paused, 0.0 W, 80%")
    }
    #endif
}
