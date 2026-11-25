import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Host schema for the helper's fixed `powermetrics -f plist -n 1 -i 1000 -s cpu_power,gpu_power` capture.
///
/// There is no separate G005 document in this repo. This type is that gate.
/// Apple Silicon plists report average power under `processor` in milliwatts and the matching
/// `*_energy` fields in millijoules over `elapsed_ns`. `combined_power` matches cpu + gpu + ane.
/// The daemon returns those bytes unchanged. A sample that is incomplete, mistyped, inconsistent,
/// or above the rail ceiling is not an estimate.
enum PowerMetricsComponentDecoder {
    static let provenance = "powermetrics processor cpu_power/gpu_power mW"
    /// One SoC rail. M2 Ultra GPU samples sit near 71 W. Anything above this is rejected.
    static let maximumRailMilliwatts = 200_000.0

    static func estimate(from reply: HelperReply) -> ServiceOutcome<ComponentEstimatePair> {
        guard reply.command == .sample, reply.status == .sourceUnvalidated, let capture = reply.capture else {
            return .failure(.unknownStatus)
        }
        guard capture.status == .completed, capture.terminationConfirmed, capture.exitStatus == 0 else {
            return .failure(.unknownStatus)
        }
        guard let pair = decode(capture) else { return .failure(.invalidData) }
        return .success(pair)
    }

    private static func decode(_ capture: HelperCapture) -> ComponentEstimatePair? {
        guard let frame = xmlFrame(capture.stdout),
              let root = dictionary(plist: frame),
              let elapsed = finiteNumber(root["elapsed_ns"]),
              elapsed >= 500_000_000, elapsed <= 4_000_000_000,
              let processor = dictionary(root["processor"]) else { return nil }
        let seconds = elapsed / 1_000_000_000
        guard capture.startedAt.timeIntervalSince1970.isFinite,
              capture.duration.isFinite, capture.duration > 0, capture.duration <= 4,
              capture.duration + 0.05 >= seconds,
              let cpu = rail(processor, power: "cpu_power", energy: "cpu_energy", seconds: seconds),
              let gpu = rail(processor, power: "gpu_power", energy: "gpu_energy", seconds: seconds),
              let ane = rail(processor, power: "ane_power", energy: "ane_energy", seconds: seconds),
              let combined = finiteNumber(processor["combined_power"]),
              combined >= 0, combined <= maximumRailMilliwatts * 3 else { return nil }
        let sum = cpu + gpu + ane
        let slack = max(1.0, 0.02 * max(sum, combined, 1))
        guard abs(sum - combined) <= slack else { return nil }
        let pair = ComponentEstimatePair(acquisitionID: capture.acquisitionID, startedAt: capture.startedAt,
                                        duration: capture.duration, cpuWatts: cpu / 1_000, gpuWatts: gpu / 1_000,
                                        provenance: provenance)
        return (try? pair.validate()) == nil ? nil : pair
    }

    /// Power in milliwatts must integrate to the published millijoule energy across the sample window.
    private static func rail(_ processor: [String: Any], power: String, energy: String, seconds: Double) -> Double? {
        guard let powerMW = finiteNumber(processor[power]),
              let energyMJ = finiteNumber(processor[energy]),
              powerMW >= 0, powerMW <= maximumRailMilliwatts, energyMJ >= 0 else { return nil }
        let expected = powerMW * seconds
        let slack = max(1.0, 0.02 * max(expected, energyMJ, 1))
        guard abs(expected - energyMJ) <= slack else { return nil }
        return powerMW
    }

    private static func xmlFrame(_ data: Data) -> Data? {
        let frames = data.split(separator: 0, omittingEmptySubsequences: true)
        guard frames.count == 1 else { return nil }
        let frame = Data(frames[0])
        guard !frame.isEmpty, frame.count <= HelperLimits.captureBytes,
              let text = String(data: frame, encoding: .utf8) else { return nil }
        let upper = text.uppercased()
        guard !upper.contains("<!ENTITY"), upper.components(separatedBy: "</PLIST>").count == 2 else { return nil }
        return frame
    }

    private static func dictionary(plist frame: Data) -> [String: Any]? {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let root = try? PropertyListSerialization.propertyList(from: frame, options: [], format: &format),
              format == .xml else { return nil }
        return dictionary(root)
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] { return dictionary }
        guard let dictionary = value as? NSDictionary else { return nil }
        let result: [String: Any] = dictionary.reduce(into: [:]) { result, pair in
            guard let key = pair.key as? String else { return }
            result[key] = pair.value
        }
        guard result.count == dictionary.count else { return nil }
        return result
    }

    /// `CFBoolean` bridges to `NSNumber`. A boolean power field is not a measurement.
    private static func finiteNumber(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let reading = number.doubleValue
        return reading.isFinite ? reading : nil
    }
}
