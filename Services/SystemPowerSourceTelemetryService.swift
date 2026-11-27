import Foundation
import IOKit
import IOKit.ps

// Observation time is app acquisition time, not a hardware measurement timestamp.
struct SystemPowerSourceSnapshot {
    let descriptions: [[String: Any]]
    let providingSource: String?
    let timestamp: Date
    /// The public IOPS description intentionally omits live watt telemetry.
    /// AppleSmartBattery exposes the measured values through its IORegistry
    /// properties; this is collected separately and remains optional so the
    /// metadata-only path still fails closed on unsupported hardware.
    let batteryProperties: [String: Any]?
    /// `IOPSCopyExternalPowerAdapterDetails()`. Flat dictionary, often Watts only.
    /// Nil when no adapter is attached or the call returns nothing.
    let externalAdapter: [String: Any]?

    init(descriptions: [[String: Any]], providingSource: String?, timestamp: Date,
         batteryProperties: [String: Any]? = nil, externalAdapter: [String: Any]? = nil) {
        self.descriptions = descriptions
        self.providingSource = providingSource
        self.timestamp = timestamp
        self.batteryProperties = batteryProperties
        self.externalAdapter = externalAdapter
    }
}

/// Menu-bar system draw, in watts.
///
/// `PowerTelemetryData` is one IORegistry dictionary on `AppleSmartBattery`.
/// On an M5 Pro running macOS 27.2.1, on battery, `SystemLoad` sat unchanged
/// for about 56 seconds and then stepped. `SystemPowerIn` and `BatteryPower`
/// live in that same dictionary and move with it. Polling faster cannot make
/// that bucket fresher. It remains the system-draw value on AC (pack current
/// there is charge current, not the Mac's draw), on a Mac with no usable
/// gauge, and whenever the gauge is missing or implausible.
///
/// These three `AppleSmartBattery` keys are the gas gauge. They are read with
/// the same `IORegistryEntryCreateCFProperty` call the app already makes, so
/// they add no entitlement, sandbox exception, or helper:
///
/// - `Voltage` is pack voltage in millivolts and updates about once a second.
/// - `InstantAmperage` is the latest pack current in milliamps, signed
///   (negative while discharging, positive while charging), at that same
///   roughly 1 Hz cadence. It is the preferred live current.
/// - `Amperage` is a short average of that current, still seconds rather than
///   a minute, used when instant current is missing or stuck at zero.
///
/// On battery the pack is the only supply, so the live system draw is the
/// pack power `|millivolts × milliamps| / 1_000_000`. A constant `SystemLoad`
/// is indistinguishable from a stale one until the bucket steps, so a
/// plausible gauge wins whenever the Mac is on battery instead of waiting for
/// that step and jumping back to it. `SystemLoad` is the fallback, and the
/// cross-check for a gauge whose current keys are present but stuck at 0
/// while the telemetry bucket still reports real draw.
///
/// IOPS `Current` and `Voltage` are not used. On recent macOS that public
/// copy is republished with the slow telemetry, not with the gauge. Adapter
/// `Current` and `Voltage` describe the charger, not live system draw.
enum SystemDrawResolver {
    /// Below a MacBook series string in millivolts. A value in volts fails this.
    static let minimumPackMillivolts = 3_000.0
    /// Above a full series pack, with margin. A microvolt-scale value fails this.
    static let maximumPackMillivolts = 20_000.0
    /// Above a short burst on a high-power MacBook. Amps stored as if they were
    /// milliamps still fit; microamps do not.
    static let maximumPackMilliamps = 30_000.0
    /// Above a laptop system draw. A desktop has no pack gauge and keeps `SystemLoad`.
    static let maximumPackWatts = 500.0
    /// Telemetry at or above this, with a zeroed gauge, means the current keys are stuck.
    static let stuckGaugeSystemWatts = 0.5

    static func systemWatts(systemLoad: Double?, batteryProperties: [String: Any]?, onBattery: Bool) -> Double? {
        guard onBattery, let live = packWatts(batteryProperties) else { return systemLoad }
        if live == 0, let systemLoad, systemLoad >= stuckGaugeSystemWatts { return systemLoad }
        return live
    }

    /// `|Voltage × current|` in watts. Instant current wins when it is non-zero.
    static func packWatts(_ properties: [String: Any]?) -> Double? {
        guard let millivolts = finite(properties?["Voltage"]),
              (minimumPackMillivolts...maximumPackMillivolts).contains(millivolts) else { return nil }
        guard let milliamps = packMilliamps(instant: finite(properties?["InstantAmperage"]),
                                             average: finite(properties?["Amperage"])) else { return nil }
        let magnitude = abs(milliamps)
        guard magnitude <= maximumPackMilliamps else { return nil }
        let watts = millivolts * magnitude / 1_000_000
        guard watts.isFinite, (0...maximumPackWatts).contains(watts) else { return nil }
        return watts
    }

    private static func packMilliamps(instant: Double?, average: Double?) -> Double? {
        if let instant, instant != 0 { return instant }
        if let average, average != 0 { return average }
        if instant == 0 || average == 0 { return 0 }
        return nil
    }

    private static func finite(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.isFinite else { return nil }
        return value
    }
}

// Pure parser: public IOPS keys determine state and time remaining. IORegistry
// telemetry supplies measured watts. Adapter identity comes from AdapterDetails
// or the external adapter dictionary. Missing and odd values stay hidden.
enum SystemPowerSourceParser {
    static func parse(_ snapshot: SystemPowerSourceSnapshot) throws -> PowerReading {
        let batteries = snapshot.descriptions.filter { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        let present = batteries.filter { boolean($0[kIOPSIsPresentKey]) == true }
        guard present.count <= 1 else { throw ServiceFailure.invalidData }
        let battery = present.first
        let knownAbsent = batteries.allSatisfy { boolean($0[kIOPSIsPresentKey]) == false }
            && snapshot.descriptions.allSatisfy { ($0[kIOPSTypeKey] as? String).map {
                $0 == kIOPSInternalBatteryType || $0 == kIOPSUPSType
            } ?? false }
        var state: BatteryState = battery == nil && knownAbsent ? .noBattery : .unknown
        if let battery {
            let charging = boolean(battery[kIOPSIsChargingKey])
            let charged = boolean(battery[kIOPSIsChargedKey])
            let source = battery[kIOPSPowerSourceStateKey] as? String
            if charging == true && charged != true && source == kIOPSACPowerValue {
                state = .charging
            } else if charging == false && source == kIOPSBatteryPowerValue && charged != true {
                state = .discharging
            } else if charging == false && charged == true && source == kIOPSACPowerValue {
                state = .full
            }
            // Not charging on AC is not proof of an intentional charging hold.
        }
        let sourceDetail: String? = switch snapshot.providingSource {
        case kIOPSACPowerValue: "Power source: AC"
        case kIOPSBatteryPowerValue: "Power source: Battery"
        case kIOPMUPSPowerKey: "Power source: UPS"
        default: nil
        }
        let identity = adapterIdentity(batteryProperties: snapshot.batteryProperties,
                                       externalAdapter: snapshot.externalAdapter)
        let minutes = reportedMinutes(battery, state: state)
        let adapterSubtitle = PowerSourceCopy.chargerSubtitle(ratedWatts: identity.watts, name: identity.name)
        // A desktop has no charger row, so the adapter name has to live in the summary.
        // On a laptop the summary keeps the time estimate, or the power source when
        // IOPS has not finished calculating one.
        let detail: String? = state == .noBattery
            ? (adapterSubtitle ?? sourceDetail)
            : (PowerSourceCopy.timeDetail(minutes: minutes, state: state) ?? sourceDetail)
        let telemetry = measurement(snapshot.batteryProperties?["PowerTelemetryData"])
        // Battery watts stay on BatteryPower. Only system draw consults the gauge.
        let onBattery = state == .discharging && snapshot.providingSource == kIOPSBatteryPowerValue
        let systemWatts = SystemDrawResolver.systemWatts(
            systemLoad: watts(telemetry?["SystemLoad"]),
            batteryProperties: snapshot.batteryProperties,
            onBattery: onBattery)
        let chargerWatts = watts(telemetry?["SystemPowerIn"])
        let hasSystemDraw = systemWatts != nil
        let hasChargerInput = chargerWatts != nil && snapshot.providingSource == kIOPSACPowerValue
        // Battery state and power telemetry are independent. Keep a valid
        // charger/system sample visible while the battery state is briefly
        // unknown (and expose system draw on battery-less Macs).
        let mode: PowerMode = switch state {
        case .charging: .charging
        case .discharging: .onBattery
        case .full: .charged
        default:
            if hasChargerInput { .chargerInput }
            else if hasSystemDraw { .systemDraw }
            else { .noReading }
        }
        let batteryWatts = batteryWatts(telemetry?["BatteryPower"], state: state)
        let reading = PowerReading(
            mode: mode, watts: batteryWatts, batteryPercentage: battery.flatMap(percentage), detail: detail,
            timestamp: snapshot.timestamp, batteryState: state,
            capabilities: .init(battery: battery != nil ? .available : (knownAbsent ? .unsupported : .unknown),
                                charger: hasChargerInput ? .available : (snapshot.providingSource == kIOPSBatteryPowerValue ? .disconnected : .unsupported),
                                systemDraw: hasSystemDraw ? .available : .unsupported, components: .unsupported),
            source: .system, chargerWatts: hasChargerInput ? chargerWatts : nil,
            systemWatts: systemWatts,
            adapterRatedWatts: identity.watts, adapterName: identity.name)
        try reading.validate()
        return reading
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func capacity(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.isFinite, value >= 0, value.rounded() == value else { return nil }
        return value
    }

    /// AdapterDetails, then AppleRawAdapterDetails, then the external adapter dictionary.
    /// The first usable watts and the first usable name win independently, so a zeroed
    /// Watts field does not hide a later real rating. Current, voltage, and unrelated
    /// dictionaries are not wattage.
    private static func adapterIdentity(batteryProperties: [String: Any]?,
                                        externalAdapter: [String: Any]?) -> (watts: Int?, name: String?) {
        let sources = [
            measurement(batteryProperties?["AdapterDetails"]),
            measurement(batteryProperties?["AppleRawAdapterDetails"]),
            externalAdapter
        ]
        var watts: Int?
        var name: String?
        for source in sources.compactMap({ $0 }) {
            if watts == nil { watts = ratedWatts(source[kIOPSPowerAdapterWattsKey]) }
            if name == nil { name = adapterName(in: source) }
        }
        return (watts, name)
    }

    private static func ratedWatts(_ value: Any?) -> Int? {
        guard let watts = wholeNumber(value), (1...PowerSourceCopy.maximumRatedWatts).contains(watts) else { return nil }
        return watts
    }

    private static func adapterName(in details: [String: Any]) -> String? {
        for key in ["Description", "Name"] {
            guard let raw = details[key] as? String else { continue }
            if let name = PowerSourceCopy.normalizedAdapterName(raw) { return name }
        }
        return nil
    }

    /// Time to full while charging, time to empty on battery. -1 is still calculating.
    /// 0 is not "zero minutes", and values above two days are not estimates.
    private static func reportedMinutes(_ battery: [String: Any]?, state: BatteryState) -> Int? {
        let key: String? = switch state {
        case .charging: kIOPSTimeToFullChargeKey
        case .discharging: kIOPSTimeToEmptyKey
        default: nil
        }
        guard let battery, let key, let minutes = wholeNumber(battery[key]),
              (1...PowerSourceCopy.maximumReportedMinutes).contains(minutes) else { return nil }
        return minutes
    }

    private static func wholeNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue
        guard value.isFinite, value.rounded() == value,
              value >= Double(Int.min), value <= Double(Int.max) else { return nil }
        return Int(value)
    }

    fileprivate static func bridgedDictionary(_ value: Any?) -> [String: Any]? {
        measurement(value)
    }

    private static func measurement(_ value: Any?) -> [String: Any]? {
        if let value = value as? [String: Any] { return value }
        if let value = value as? NSDictionary {
            return value.reduce(into: [String: Any]()) { result, pair in
                guard let key = pair.key as? String else { return }
                result[key] = pair.value
            }
        }
        return nil
    }

    /// PowerTelemetryData magnitudes are milliwatts. Keep zero as a real reading;
    /// only malformed, non-finite and negative input values are unavailable.
    /// `BatteryPower` is a signed rate and is parsed separately.
    private static func watts(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue / 1_000
        guard value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// `BatteryPower` is milliwatts. Newer Macs report a signed rate, negative
    /// while discharging. IORegistry may surface those same bits as a uint64
    /// (ioreg prints the wrap). Older hardware reports a positive magnitude,
    /// and the battery state supplies the direction.
    private static func batteryWatts(_ value: Any?, state: BatteryState) -> Double? {
        guard state != .noBattery, let milliwatts = batteryMilliwatts(value) else { return nil }
        let watts = milliwatts / 1_000
        guard watts.isFinite else { return nil }
        if milliwatts < 0 {
            // The sample already carries its direction. A busy Mac can drain
            // while plugged in even though the battery state still says
            // charging, so the measured negative rate is reported as it is.
            return watts
        }
        switch state {
        case .discharging: return -watts
        case .charging, .chargingHold, .full: return watts
        case .unknown:
            // Not charging on AC is not a charging hold, but a measured idle
            // flow is still a reading. A positive magnitude without a classified
            // state stays unavailable rather than inventing a sign.
            return watts == 0 ? 0 : nil
        case .noBattery: return nil
        }
    }

    /// Signed milliwatts, including a uint64 whose bits are a negative Int64.
    /// Doubles above 2^53 cannot round-trip that wrap, so unsigned integers are
    /// reinterpreted before any conversion through Double.
    private static func batteryMilliwatts(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let encoding = String(cString: number.objCType)
        if encoding == "d" || encoding == "f" {
            let milliwatts = number.doubleValue
            guard milliwatts.isFinite else { return nil }
            return milliwatts
        }
        let bits = number.uint64Value
        if encoding == "Q" || encoding == "L" || bits > UInt64(Int64.max) {
            if bits > UInt64(Int64.max) {
                return Double(Int64(bitPattern: bits))
            }
            return Double(bits)
        }
        return Double(number.int64Value)
    }

    private static func percentage(_ battery: [String: Any]) -> Int? {
        guard let current = capacity(battery[kIOPSCurrentCapacityKey]),
              let maximum = capacity(battery[kIOPSMaxCapacityKey]), maximum > 0, current <= maximum else { return nil }
        return Int((current / maximum * 100).rounded())
    }
}

@MainActor
final class SystemPowerSourceTelemetryService: TelemetryService {
    typealias Provider = @MainActor (Date) async -> SystemPowerSourceSnapshot?
    private let clock: any WattClock
    private let provider: Provider

    init(clock: (any WattClock)? = nil, provider: Provider? = nil) {
        self.clock = clock ?? SystemWattClock()
        self.provider = provider ?? Self.systemSnapshot
    }

    func sample() async -> ServiceOutcome<PowerReading> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let snapshot = await provider(clock.now)
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard let snapshot else { return .failure(.unknownStatus) }
        do {
            let reading = try SystemPowerSourceParser.parse(snapshot)
            guard clock.now.timeIntervalSince1970.isFinite, reading.timestamp <= clock.now else {
                return .failure(.invalidData)
            }
            return .success(reading)
        } catch { return .failure(.invalidData) }
    }

    private static func systemSnapshot(at timestamp: Date) async -> SystemPowerSourceSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        var descriptions: [[String: Any]] = []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            else { return nil }
            descriptions.append(description)
        }
        let external = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue()
        return SystemPowerSourceSnapshot(descriptions: descriptions,
                                         providingSource: IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?,
                                         timestamp: timestamp,
                                         batteryProperties: Self.smartBatteryProperties(),
                                         externalAdapter: SystemPowerSourceParser.bridgedDictionary(external))
    }

    private static func smartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                   IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        // Copy the keys the parser reads. The rest of the AppleSmartBattery
        // entry stays in the registry. A missing key is the same as a dictionary
        // that does not contain it. Voltage and the two current keys are the
        // gas gauge; they are numbers, not a second copy of PowerTelemetryData.
        var properties: [String: Any] = [:]
        for key in ["PowerTelemetryData", "AdapterDetails", "AppleRawAdapterDetails",
                    "Voltage", "InstantAmperage", "Amperage"] {
            guard let value = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() else { continue }
            properties[key] = value
        }
        return properties.isEmpty ? nil : properties
    }
}
