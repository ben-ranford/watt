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
        let systemWatts = watts(telemetry?["SystemLoad"])
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
        let key: CFString? = switch state {
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

    /// PowerTelemetryData values are milliwatts. Keep zero as a real reading;
    /// only malformed, non-finite and negative input values are unavailable.
    private static func watts(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.doubleValue / 1_000
        guard value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func batteryWatts(_ value: Any?, state: BatteryState) -> Double? {
        guard let value = watts(value) else { return nil }
        switch state {
        case .discharging: return -value
        case .charging, .chargingHold, .full: return value
        case .unknown:
            // Not charging on AC is not a charging hold, but a measured idle
            // flow is still a reading. A non-zero rate without a classified
            // state stays unavailable rather than inventing a sign.
            return value == 0 ? 0 : nil
        case .noBattery: return nil
        }
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

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == 0,
              let properties else { return nil }
        return properties.takeRetainedValue() as? [String: Any]
    }
}
