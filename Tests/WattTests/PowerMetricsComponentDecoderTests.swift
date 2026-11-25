import XCTest
#if SWIFT_PACKAGE
import WattHelperShared
#endif
@testable import Watt

/// Reduced Apple Silicon `powermetrics -f plist` documents. Power, energy, and `elapsed_ns`
/// match earlier Apple silicon captures. Cluster and DVFM tables are omitted because the
/// decoder must not depend on them.
enum PowerMetricsFixture {
    static let acquisition = UUID(uuidString: "E4B1C0DE-0000-4000-8000-000000000001")!
    static let started = Date(timeIntervalSince1970: 1_700_000_000)

    static func capture(stdout: Data, duration: TimeInterval = 1.2, exitStatus: Int32? = 0,
                        status: HelperCaptureStatus = .completed, terminationConfirmed: Bool = true) -> HelperCapture {
        HelperCapture(acquisitionID: acquisition, startedAt: started, duration: duration,
                      stdout: stdout, stderr: Data(), exitStatus: exitStatus, status: status,
                      terminationConfirmed: terminationConfirmed)
    }

    static func reply(_ capture: HelperCapture?, status: HelperReplyStatus = .sourceUnvalidated) -> HelperReply {
        let request = HelperRequest(command: .sample, generation: UUID())
        return HelperReply(request: request, build: "test", daemonInstance: UUID(), status: status, capture: capture)
    }

    static func plist(_ body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \(body)
        </dict>
        </plist>
        """.utf8)
    }

    /// Idle low-power window (`elapsed_ns` 2019178750). cpu 44.0773 mW and gpu 15.3528 mW.
    static func lowPowerIdle() -> Data {
        plist("""
        <key>elapsed_ns</key>
        <integer>2019178750</integer>
        <key>hw_model</key>
        <string>Mac</string>
        <key>is_delta</key>
        <true/>
        <key>thermal_pressure</key>
        <string>Nominal</string>
        \(processor(cpuPower: "44.0773", gpuPower: "15.3528", anePower: "0.0", combined: "59.4301",
                    cpuEnergy: "89", gpuEnergy: "31", aneEnergy: "0", realPower: true))
        <key>gpu</key>
        <dict>
        <key>freq_hz</key>
        <real>714.836</real>
        <key>idle_ratio</key>
        <real>0.983341</real>
        </dict>
        """)
    }

    /// Loaded high-GPU window (`elapsed_ns` 1023721416). GPU average 70924.6 mW.
    static func highGPULoaded() -> Data {
        plist("""
        <key>elapsed_ns</key>
        <integer>1023721416</integer>
        <key>hw_model</key>
        <string>Mac</string>
        <key>is_delta</key>
        <true/>
        \(processor(cpuPower: "835.188", gpuPower: "70924.6", anePower: "0.0", combined: "71759.8",
                    cpuEnergy: "855", gpuEnergy: "72607", aneEnergy: "0", realPower: true))
        """)
    }

    /// One-second integer rails, the shape `-i 1000` produces when the window is exact.
    static func oneSecondRails(cpu: Int = 2340, gpu: Int = 860, ane: Int = 0) -> Data {
        let combined = cpu + gpu + ane
        return plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>hw_model</key>
        <string>Mac</string>
        \(processor(cpuPower: "\(cpu)", gpuPower: "\(gpu)", anePower: "\(ane)", combined: "\(combined)",
                    cpuEnergy: "\(cpu)", gpuEnergy: "\(gpu)", aneEnergy: "\(ane)", realPower: false))
        """)
    }

    private static func processor(cpuPower: String, gpuPower: String, anePower: String, combined: String,
                                  cpuEnergy: String, gpuEnergy: String, aneEnergy: String, realPower: Bool) -> String {
        let number = realPower ? "real" : "integer"
        return """
        <key>processor</key>
        <dict>
        <key>clusters</key>
        <array>
        <dict>
        <key>name</key>
        <string>E-Cluster</string>
        <key>freq_hz</key>
        <real>1022870000</real>
        </dict>
        </array>
        <key>ane_energy</key>
        <integer>\(aneEnergy)</integer>
        <key>ane_power</key>
        <\(number)>\(anePower)</\(number)>
        <key>combined_power</key>
        <\(number)>\(combined)</\(number)>
        <key>cpu_energy</key>
        <integer>\(cpuEnergy)</integer>
        <key>cpu_power</key>
        <\(number)>\(cpuPower)</\(number)>
        <key>gpu_energy</key>
        <integer>\(gpuEnergy)</integer>
        <key>gpu_power</key>
        <\(number)>\(gpuPower)</\(number)>
        </dict>
        """
    }
}

final class PowerMetricsComponentDecoderTests: XCTestCase {
    /// Real current-generation Apple silicon capture on macOS 27. Same `processor` keys and units as the
    /// reduced fixtures above: power in mW, energy in mJ over `elapsed_ns`, and `combined_power` equal to cpu + gpu + ane.
    func testRealIdleCaptureDecodes() throws {
        let capture = PowerMetricsFixture.capture(stdout: PowerMetricsRealCapture.idle, duration: 1.547)
        guard case .success(let pair) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)) else {
            return XCTFail("A real idle capture must decode")
        }
        XCTAssertEqual(pair.cpuWatts, 1.23097, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.gpuWatts, 0.594923, accuracy: 0.000_000_1)
    }

    func testRealLoadedCaptureDecodesInsideTheRailCeiling() throws {
        let capture = PowerMetricsFixture.capture(stdout: PowerMetricsRealCapture.loaded, duration: 1.653)
        guard case .success(let pair) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)) else {
            return XCTFail("A real loaded capture must decode")
        }
        XCTAssertEqual(pair.cpuWatts, 15.8682, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.gpuWatts, 30.5204, accuracy: 0.000_000_1)
        XCTAssertLessThan(pair.gpuWatts, PowerMetricsComponentDecoder.maximumRailMilliwatts / 1_000)
    }

    func testRealCaptureMatchesTheDecoderSchema() throws {
        for data in [PowerMetricsRealCapture.idle, PowerMetricsRealCapture.loaded] {
            XCTAssertFalse(data.contains(0), "-n 1 on macOS 27 is one plist with no NUL")
            let root = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            let processor = try XCTUnwrap(root["processor"] as? [String: Any])
            let elapsed = try XCTUnwrap(root["elapsed_ns"] as? NSNumber).doubleValue / 1_000_000_000
            func value(_ key: String) throws -> Double { try XCTUnwrap(processor[key] as? NSNumber, key).doubleValue }
            let sum = try value("cpu_power") + value("gpu_power") + value("ane_power")
            XCTAssertEqual(sum, try value("combined_power"), accuracy: 0.01)
            for rail in ["cpu", "gpu", "ane"] {
                XCTAssertEqual(try value("\(rail)_power") * elapsed, try value("\(rail)_energy"), accuracy: 1)
            }
        }
    }

    /// Two real frames in one capture are not one sample.
    func testTwoRealFramesFailClosed() {
        let stdout = PowerMetricsRealCapture.idle + Data([0]) + PowerMetricsRealCapture.loaded
        let outcome = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(PowerMetricsFixture.capture(stdout: stdout)))
        guard case .failure(.invalidData) = outcome else { return XCTFail("Two frames are not one sample") }
    }

    func testLowPowerIdleCaptureDecodesMilliwattsToWatts() throws {
        let capture = PowerMetricsFixture.capture(stdout: PowerMetricsFixture.lowPowerIdle(), duration: 2.2)
        guard case .success(let pair) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)) else {
            return XCTFail("Low-power idle sample must decode")
        }
        XCTAssertEqual(pair.cpuWatts, 0.0440773, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.gpuWatts, 0.0153528, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.acquisitionID, PowerMetricsFixture.acquisition)
        XCTAssertEqual(pair.startedAt, PowerMetricsFixture.started)
        XCTAssertEqual(pair.duration, 2.2)
        XCTAssertEqual(pair.components.map(\.name), ["CPU estimate", "GPU estimate"])
        try pair.validate()
    }

    func testHighGPULoadStaysInsideTheRailCeiling() throws {
        let capture = PowerMetricsFixture.capture(stdout: PowerMetricsFixture.highGPULoaded(), duration: 1.2)
        guard case .success(let pair) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)) else {
            return XCTFail("High-GPU sample must decode")
        }
        XCTAssertEqual(pair.cpuWatts, 0.835188, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.gpuWatts, 70.9246, accuracy: 0.000_000_1)
        try pair.validate()
    }

    func testTrailingNULStillDecodesTheSingleFrame() {
        var stdout = PowerMetricsFixture.oneSecondRails()
        stdout.append(0)
        let outcome = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(PowerMetricsFixture.capture(stdout: stdout)))
        guard case .success(let pair) = outcome else { return XCTFail("One trailing NUL is the powermetrics frame separator") }
        XCTAssertEqual(pair.cpuWatts, 2.34, accuracy: 0.000_000_1)
        XCTAssertEqual(pair.gpuWatts, 0.86, accuracy: 0.000_000_1)
    }

    func testZeroRailsAreARealSample() throws {
        let outcome = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(
            PowerMetricsFixture.capture(stdout: PowerMetricsFixture.oneSecondRails(cpu: 0, gpu: 0))))
        guard case .success(let pair) = outcome else { return XCTFail("Zero milliwatts is a measurement") }
        XCTAssertEqual(pair.components.map(\.watts), [0, 0])
        try pair.validate()
    }

    func testMissingGPUPowerFailsClosed() {
        assertInvalid(PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <integer>0</integer>
        <key>combined_power</key>
        <integer>2340</integer>
        <key>cpu_energy</key>
        <integer>2340</integer>
        <key>cpu_power</key>
        <integer>2340</integer>
        <key>gpu_energy</key>
        <integer>860</integer>
        </dict>
        """))
    }

    func testMissingEnergyFailsClosed() {
        assertInvalid(PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <integer>0</integer>
        <key>combined_power</key>
        <integer>3200</integer>
        <key>cpu_power</key>
        <integer>2340</integer>
        <key>gpu_energy</key>
        <integer>860</integer>
        <key>gpu_power</key>
        <integer>860</integer>
        </dict>
        """))
    }

    func testWattScalePowerWithMillijouleEnergyFailsClosed() {
        let watts = PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <real>0.0</real>
        <key>combined_power</key>
        <real>3.2</real>
        <key>cpu_energy</key>
        <integer>2340</integer>
        <key>cpu_power</key>
        <real>2.34</real>
        <key>gpu_energy</key>
        <integer>860</integer>
        <key>gpu_power</key>
        <real>0.86</real>
        </dict>
        """)
        assertInvalid(watts)
    }

    func testCombinedPowerThatIsNotTheRailSumFailsClosed() {
        assertInvalid(PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <integer>0</integer>
        <key>combined_power</key>
        <integer>10000</integer>
        <key>cpu_energy</key>
        <integer>2340</integer>
        <key>cpu_power</key>
        <integer>2340</integer>
        <key>gpu_energy</key>
        <integer>860</integer>
        <key>gpu_power</key>
        <integer>860</integer>
        </dict>
        """))
    }

    func testOutOfRangeRailFailsClosed() {
        let aboveCeiling = 250_000
        assertInvalid(PowerMetricsFixture.oneSecondRails(cpu: aboveCeiling, gpu: 0))
    }

    func testNegativePowerFailsClosed() {
        let negative = PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <integer>0</integer>
        <key>combined_power</key>
        <integer>0</integer>
        <key>cpu_energy</key>
        <integer>-5</integer>
        <key>cpu_power</key>
        <integer>-5</integer>
        <key>gpu_energy</key>
        <integer>0</integer>
        <key>gpu_power</key>
        <integer>0</integer>
        </dict>
        """)
        assertInvalid(negative)
    }

    func testBooleanPowerFailsClosed() {
        let flag = PowerMetricsFixture.plist("""
        <key>elapsed_ns</key>
        <integer>1000000000</integer>
        <key>processor</key>
        <dict>
        <key>ane_energy</key>
        <integer>0</integer>
        <key>ane_power</key>
        <integer>0</integer>
        <key>combined_power</key>
        <integer>0</integer>
        <key>cpu_energy</key>
        <integer>1</integer>
        <key>cpu_power</key>
        <true/>
        <key>gpu_energy</key>
        <integer>0</integer>
        <key>gpu_power</key>
        <integer>0</integer>
        </dict>
        """)
        assertInvalid(flag)
    }

    func testGarbageInputFailsClosed() {
        let entity = Data("""
        <?xml version="1.0"?>
        <!DOCTYPE plist [<!ENTITY x "bomb">]>
        <plist version="1.0"><dict></dict></plist>
        """.utf8)
        let doubled = PowerMetricsFixture.oneSecondRails() + PowerMetricsFixture.oneSecondRails()
        for garbage in [Data(), Data("not a plist".utf8), Data("{\"processor\":1}".utf8), Data([0x00, 0x01, 0x02]), entity, doubled] {
            assertInvalid(garbage)
        }
    }

    func testSecondPlistFrameFailsClosed() {
        var doubled = PowerMetricsFixture.oneSecondRails()
        doubled.append(0)
        doubled.append(PowerMetricsFixture.oneSecondRails())
        assertInvalid(doubled)
    }

    func testIncompleteCaptureFailsClosed() {
        let stdout = PowerMetricsFixture.oneSecondRails()
        let cases = [
            PowerMetricsFixture.capture(stdout: stdout, exitStatus: 1),
            PowerMetricsFixture.capture(stdout: stdout, exitStatus: nil),
            PowerMetricsFixture.capture(stdout: stdout, status: .timedOut),
            PowerMetricsFixture.capture(stdout: stdout, terminationConfirmed: false)
        ]
        for capture in cases {
            guard case .failure(.unknownStatus) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)) else {
                return XCTFail("An unfinished capture must not become a reading")
            }
        }
    }

    func testBusyAndDiagnosticRepliesAreNotEstimates() {
        guard case .failure(.unknownStatus) = PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(nil, status: .busy)) else {
            return XCTFail("A declined sample stays unavailable")
        }
        let request = HelperRequest(command: .diagnosticCapture, generation: UUID())
        let reply = HelperReply(request: request, build: "test", daemonInstance: UUID(), status: .sourceUnvalidated,
                                capture: PowerMetricsFixture.capture(stdout: PowerMetricsFixture.oneSecondRails()))
        guard case .failure(.unknownStatus) = PowerMetricsComponentDecoder.estimate(from: reply) else {
            return XCTFail("Diagnostic export must not become a reading")
        }
    }

    func testSampleShorterThanItsElapsedWindowFailsClosed() {
        let capture = PowerMetricsFixture.capture(stdout: PowerMetricsFixture.lowPowerIdle(), duration: 0.5)
        assertInvalidOutcome(PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(capture)))
    }

    private func assertInvalid(_ stdout: Data, duration: TimeInterval = 1.2) {
        assertInvalidOutcome(PowerMetricsComponentDecoder.estimate(from: PowerMetricsFixture.reply(
            PowerMetricsFixture.capture(stdout: stdout, duration: duration))))
    }

    private func assertInvalidOutcome(_ outcome: ServiceOutcome<ComponentEstimatePair>,
                                      file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(.invalidData) = outcome else {
            return XCTFail("Expected invalidData, got \(outcome)", file: file, line: line)
        }
    }
}
