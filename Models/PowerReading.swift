import Foundation

// Legacy presentation mode; physical state and capability must not be inferred from it.
enum PowerMode: String, CaseIterable, Hashable, Codable, Sendable {
    case charging, onBattery, charged, chargerInput, systemDraw, perComponent, noReading
}

enum BatteryState: String, Codable, Sendable {
    case charging, discharging, chargingHold, full, noBattery, unknown
}

// An adapter connection or zero delta alone cannot establish why charging is held.
enum BatteryChargingHoldReason: String, Codable, Sendable {
    case optimisedBatteryCharging
}

enum ReadingSource: String, Codable, Sendable { case fixture, system, helper, unavailable }
enum ReadingFreshness: String, Codable, Sendable { case fresh, stale, unavailable }
enum Capability: String, Codable, Sendable { case available, unsupported, permissionRequired, disconnected, unknown }

struct PowerCapabilities: Equatable, Codable, Sendable {
    var battery: Capability = .unknown
    var charger: Capability = .unknown
    var systemDraw: Capability = .unknown
    var components: Capability = .unknown
}

enum ChargerFallbackPolicy {
    case batteryDelta
    case systemDrawWhenDisconnected
}

/// Supplied by a threshold evaluator after sustained measured deficit, never adapter presence.
struct ChargerThresholdProvenance: Equatable, Sendable {
    let episodeID: String
    let observedAt: Date
    let sustainedDuration: TimeInterval
}

enum InsufficientChargerPresentation {
    static let title = "Charger can’t keep up"
    static let symbol = "exclamationmark.triangle.fill"
}

enum NoReadingPresentation {
    static let title = "No reading"
    static let value = "− − W"
    static let subtitle = "Usually right after wake. Watt? tries again every few seconds."
    static let symbol = "exclamationmark.triangle.fill"
    static let retryLabel = "Try now"
    static let retryAction = "Try Again"
}

/// A pair is atomic: neither channel is presented without its sibling acquisition.
struct ComponentEstimatePair: Equatable, Sendable {
    let acquisitionID: UUID
    let startedAt: Date
    let duration: TimeInterval
    let cpuWatts: Double
    let gpuWatts: Double
    let provenance: String

    func validate() throws {
        guard startedAt.timeIntervalSince1970.isFinite, duration.isFinite,
              duration > 0, duration <= 4, cpuWatts.isFinite, gpuWatts.isFinite,
              cpuWatts >= 0, gpuWatts >= 0, !provenance.isEmpty else { throw ServiceFailure.invalidData }
    }
    var components: [PowerComponent] {
        [.init(id: "cpu", name: "CPU estimate", watts: cpuWatts),
         .init(id: "gpu", name: "GPU estimate", watts: gpuWatts)]
    }
}

struct PowerReading: Equatable, Sendable {
    let mode: PowerMode
    let watts: Double?
    let batteryPercentage: Int?
    let detail: String?
    let components: [PowerComponent]
    let timestamp: Date
    let batteryState: BatteryState
    let capabilities: PowerCapabilities
    let freshness: ReadingFreshness
    let source: ReadingSource
    let chargerWatts: Double?
    let systemWatts: Double?
    let chargingHoldReason: BatteryChargingHoldReason?
    let chargerThreshold: ChargerThresholdProvenance?
    let componentEstimate: ComponentEstimatePair?
    /// Rated adapter wattage from AdapterDetails or the external adapter dictionary.
    let adapterRatedWatts: Int?
    /// Short adapter name. The panel combines this with the rated wattage.
    let adapterName: String?

    init(mode: PowerMode, watts: Double?, batteryPercentage: Int? = nil,
         detail: String? = nil, components: [PowerComponent] = [],
         timestamp: Date = Date(), batteryState: BatteryState = .unknown,
         capabilities: PowerCapabilities = .init(), freshness: ReadingFreshness = .fresh,
         source: ReadingSource = .unavailable, chargerWatts: Double? = nil, systemWatts: Double? = nil,
         chargingHoldReason: BatteryChargingHoldReason? = nil,
         chargerThreshold: ChargerThresholdProvenance? = nil,
         componentEstimate: ComponentEstimatePair? = nil,
         adapterRatedWatts: Int? = nil, adapterName: String? = nil) {
        self.mode = mode
        self.watts = watts
        self.batteryPercentage = batteryPercentage
        self.detail = detail
        self.components = components
        self.timestamp = timestamp
        self.batteryState = batteryState
        self.capabilities = capabilities
        self.freshness = freshness
        self.source = source
        self.chargerWatts = chargerWatts
        self.systemWatts = systemWatts
        self.chargingHoldReason = chargingHoldReason
        self.chargerThreshold = chargerThreshold
        self.componentEstimate = componentEstimate
        self.adapterRatedWatts = adapterRatedWatts
        self.adapterName = adapterName
    }

    /// Rated wattage and name for the charger row. Nil when the hardware did not report either.
    var adapterSubtitle: String? {
        PowerSourceCopy.chargerSubtitle(ratedWatts: adapterRatedWatts, name: adapterName)
    }

    /// Today's Settings default. Callers that pass another duration must use the same value for the panel and the notification.
    static let defaultInsufficientChargerDuration: TimeInterval = 300

    var hasInsufficientCharger: Bool {
        insufficientChargerIsActive(minimumDuration: Self.defaultInsufficientChargerDuration)
    }

    /// The supplied duration is the configured deficit, compared with measured `sustainedDuration`.
    func hasInsufficientCharger(minimumDuration: TimeInterval) -> Bool {
        insufficientChargerIsActive(minimumDuration: minimumDuration)
    }

    var insufficientChargerMessage: String? {
        insufficientChargerDetail(minimumDuration: Self.defaultInsufficientChargerDuration)
    }

    func insufficientChargerMessage(minimumDuration: TimeInterval) -> String? {
        insufficientChargerDetail(minimumDuration: minimumDuration)
    }

    private func insufficientChargerIsActive(minimumDuration: TimeInterval) -> Bool {
        guard minimumDuration.isFinite, minimumDuration > 0,
              let threshold = chargerThreshold,
              !threshold.episodeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              threshold.observedAt == timestamp,
              threshold.sustainedDuration.isFinite, threshold.sustainedDuration >= minimumDuration,
              source != .unavailable, freshness == .fresh,
              capabilities.battery == .available, capabilities.charger == .available,
              capabilities.systemDraw == .available, batteryState == .discharging,
              let watts, watts < 0, let chargerWatts, chargerWatts > 0,
              let systemWatts, systemWatts > chargerWatts,
              (try? validate()) != nil else { return false }
        return true
    }

    private func insufficientChargerDetail(minimumDuration: TimeInterval) -> String? {
        guard insufficientChargerIsActive(minimumDuration: minimumDuration) else { return nil }
        let draw = PowerFormatter.watts(systemWatts, signed: false, precision: .whole)
        let input = PowerFormatter.watts(chargerWatts, signed: false, precision: .whole)
        return "Because your Mac draws \(draw) and this charger gives \(input). The battery covers the rest."
    }

    func validate() throws {
        if let componentEstimate {
            try componentEstimate.validate()
            guard components == componentEstimate.components else { throw ServiceFailure.invalidData }
        }
        guard timestamp.timeIntervalSince1970.isFinite,
              [watts, chargerWatts, systemWatts].compactMap({ $0 }).allSatisfy(\.isFinite),
              batteryPercentage.map({ (0...100).contains($0) }) ?? true,
              [chargerWatts, systemWatts].compactMap({ $0 }).allSatisfy({ $0 >= 0 }),
              Set(components.map(\.id)).count == components.count,
              components.allSatisfy({ !$0.id.isEmpty && $0.watts.isFinite && $0.watts >= 0 }),
              batteryState != .charging || (watts.map { $0 >= 0 } ?? true),
              batteryState != .discharging || (watts.map { $0 <= 0 } ?? true),
              batteryState != .noBattery || (watts == nil && batteryPercentage == nil),
              adapterRatedWatts.map({ (1...PowerSourceCopy.maximumRatedWatts).contains($0) }) ?? true,
              adapterName.map({ PowerSourceCopy.normalizedAdapterName($0) == $0 }) ?? true
        else { throw ServiceFailure.invalidData }
    }

    func freshness(at now: Date, maximumAge: TimeInterval) -> ReadingFreshness {
        guard freshness != .unavailable, source != .unavailable else { return .unavailable }
        guard maximumAge.isFinite, maximumAge >= 0, now >= timestamp,
              now.timeIntervalSince(timestamp) <= maximumAge, freshness != .stale else { return .stale }
        return .fresh
    }

    /// Availability is evidence, not a presentation mode or a cached numeric payload.
    var hasCurrentSample: Bool {
        mode != .noReading && source != .unavailable && freshness == .fresh
            && (try? validate()) != nil
    }

    // A disconnected charger falls back to battery delta, never a fabricated zero input.
    func value(for display: WattDisplayMode, chargerFallback: ChargerFallbackPolicy = .batteryDelta) -> Double? {
        guard hasCurrentSample else { return nil }
        switch display {
        case .delta: return capabilities.battery == .available ? watts : nil
        case .charger:
            // C04.5 opts in explicitly; legacy callers retain battery-delta fallback.
            if chargerFallback == .systemDrawWhenDisconnected && capabilities.charger == .disconnected {
                return freshness == .fresh && capabilities.systemDraw == .available ? systemWatts : nil
            }
            return capabilities.charger == .available ? chargerWatts :
            (capabilities.battery == .available ? watts : nil)
        case .draw: return capabilities.systemDraw == .available ? systemWatts : nil
        case .components, .iconOnly: return nil
        }
    }

    /// System timestamp and values remain tied to the system observation.
    func presenting(_ pair: ComponentEstimatePair?) -> PowerReading {
        var capabilities = capabilities
        capabilities.components = pair == nil ? .unknown : .available
        let componentOnly = mode == .noReading && pair != nil
        return PowerReading(mode: componentOnly ? .perComponent : mode, watts: watts,
            batteryPercentage: batteryPercentage, detail: detail, components: pair?.components ?? [],
            timestamp: componentOnly ? pair!.startedAt : timestamp, batteryState: batteryState,
            capabilities: capabilities, freshness: componentOnly ? .fresh : freshness,
            source: componentOnly ? .helper : source, chargerWatts: chargerWatts, systemWatts: systemWatts,
            chargingHoldReason: chargingHoldReason, chargerThreshold: chargerThreshold, componentEstimate: pair,
            adapterRatedWatts: adapterRatedWatts, adapterName: adapterName)
    }

    static let unavailable = PowerReading(mode: .noReading, watts: nil, timestamp: .distantPast,
                                         freshness: .unavailable)
    #if DEBUG
    static let sampleInsufficientCharger = PowerReading(
        mode: .onBattery, watts: -13, batteryPercentage: 64,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .discharging,
        capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
        source: .fixture, chargerWatts: 65, systemWatts: 78,
        chargerThreshold: .init(episodeID: "J6.4", observedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                sustainedDuration: 300))

    static let sampleFullOnAdapter = PowerReading(
        mode: .charged, watts: 0, batteryPercentage: 100,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .full,
        capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
        source: .fixture, chargerWatts: 19.8, systemWatts: 19.8)

    static let sampleChargingHold = PowerReading(
        mode: .charged, watts: 0, batteryPercentage: 80,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .chargingHold,
        capabilities: .init(battery: .available, charger: .available, systemDraw: .available),
        source: .fixture, chargerWatts: 21.4, systemWatts: 21.4,
        chargingHoldReason: .optimisedBatteryCharging)

    static let samplePerComponent = PowerReading(
        mode: .perComponent, watts: nil,
        components: [PowerComponent(name: "CPU", watts: 9.8),
                     PowerComponent(name: "GPU", watts: 4.1)],
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        capabilities: .init(components: .available), source: .fixture)
    static let sampleDesktopSystemDraw = PowerReading(
        mode: .systemDraw, watts: nil,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .noBattery,
        capabilities: .init(battery: .unsupported, charger: .unsupported, systemDraw: .available),
        source: .fixture, systemWatts: 38.2)
    static let sampleUnpluggedCharger = PowerReading(
        mode: .chargerInput, watts: -18.4, batteryPercentage: 64,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .discharging,
        capabilities: .init(battery: .available, charger: .disconnected, systemDraw: .available),
        source: .fixture, systemWatts: 18.4)
    static let sampleChargerInput = PowerReading(
        mode: .charging, watts: 42.1, batteryPercentage: 64,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .charging,
        capabilities: .init(battery: .available, charger: .available,
                            systemDraw: .unknown, components: .unknown),
        source: .fixture, chargerWatts: 65.0)
    static let sampleChargedOnAdapter = PowerReading(
        mode: .charged, watts: 0, batteryPercentage: 100,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .full,
        capabilities: .init(battery: .available, charger: .available,
                            systemDraw: .unknown, components: .unknown),
        source: .fixture)
    static let sampleOnBattery = PowerReading(
        mode: .onBattery, watts: -18.4, batteryPercentage: 64, detail: "about 4 h 10 min left",
        components: [PowerComponent(id: "cpu", name: "CPU", watts: 6.2),
                     PowerComponent(id: "gpu", name: "GPU", watts: 1.9),
                     PowerComponent(id: "display", name: "Display", watts: 4.8),
                     PowerComponent(id: "other", name: "Other", watts: 5.5)],
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .discharging,
        capabilities: .init(battery: .available, charger: .disconnected, systemDraw: .available, components: .available),
        source: .fixture, systemWatts: 18.4)
    #endif
    static let sampleCharging = PowerReading(
        mode: .charging, watts: 42.1, batteryPercentage: 64, detail: "full in about 38 min",
        components: [PowerComponent(name: "CPU", watts: 9.8), PowerComponent(name: "GPU", watts: 4.1),
                     PowerComponent(name: "Display", watts: 5.2), PowerComponent(name: "Other", watts: 3.8)],
        timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: .charging,
        capabilities: .init(battery: .available, charger: .available, systemDraw: .available, components: .available),
        source: .fixture, chargerWatts: 65, systemWatts: 22.9)
}

struct PowerComponent: Identifiable, Equatable, Sendable {
    // Adapter-supplied stable ID, never a UUID generated per sample. Names are legacy fixture IDs.
    let id: String
    let name: String
    let watts: Double
    init(id: String? = nil, name: String, watts: Double) {
        self.id = id ?? name
        self.name = name
        self.watts = watts
    }
}

enum PowerFormatter {
    static func watts(_ value: Double?, signed: Bool = true, precision: WattPrecision = .decimal) -> String {
        guard let value, value.isFinite else { return "—" }
        let scale = pow(10.0, Double(precision.decimalPlaces))
        let rounded = (value * scale).rounded() / scale
        guard rounded.isFinite else { return "—" }
        if rounded == 0 {
            return String(format: "%.*f W", locale: Locale(identifier: "en_US_POSIX"), precision.decimalPlaces, 0.0)
        } // Includes negative zero and sub-precision noise.
        let format = signed ? "%+.*f W" : "%.*f W"
        return String(format: format, locale: Locale(identifier: "en_US_POSIX"), precision.decimalPlaces, rounded)
    }
}

/// Short English copy for adapter identity and IOPS time estimates.
/// The rest of the panel uses the same literal-string style.
enum PowerSourceCopy {
    static let maximumRatedWatts = 500
    /// Two days. Longer values, including the 65535 firmware sentinel, are not estimates.
    static let maximumReportedMinutes = 48 * 60

    static func chargerSubtitle(ratedWatts: Int?, name: String?) -> String? {
        let watts = ratedWatts.flatMap { (1...maximumRatedWatts).contains($0) ? $0 : nil }
        let name = name.flatMap(normalizedAdapterName)
        if let watts, let name {
            if containsWattage(name, equalTo: watts) { return name }
            if containsWattage(name) { return "\(watts) W charger" }
            return "\(watts) W \(name)"
        }
        if let watts { return "\(watts) W charger" }
        return name
    }

    static func timeDetail(minutes: Int?, state: BatteryState) -> String? {
        guard let minutes, (1...maximumReportedMinutes).contains(minutes) else { return nil }
        let body = duration(minutes)
        switch state {
        case .charging: return "full in about \(body)"
        case .discharging: return "about \(body) left"
        default: return nil
        }
    }

    /// Known generic IOKit descriptions become the same short names the panel already uses.
    /// Anything else keeps its words, with "96W" spaced as "96 W".
    static func normalizedAdapterName(_ raw: String) -> String? {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty, collapsed.count <= 60,
              collapsed.contains(where: \.isLetter),
              collapsed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        switch collapsed.lowercased() {
        case "pd charger", "usb-c", "usb c", "usbc", "usb-pd", "usb pd", "usb-c charger", "usbc charger":
            return "USB-C charger"
        case "magsafe", "magsafe 3", "magsafe3", "mag safe", "magsafe charger":
            return "MagSafe charger"
        case "charger", "adapter", "power adapter", "ac", "battery", "ups", "internal", "external":
            return nil
        default:
            let spaced = spaceBeforeWattUnit(collapsed)
            guard spaced.count <= 60 else { return nil }
            return spaced
        }
    }

    private static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 { return "\(hours) h \(remainder) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(minutes) min"
    }

    private static func containsWattage(_ name: String, equalTo watts: Int? = nil) -> Bool {
        let scalars = Array(name)
        var index = 0
        while index < scalars.count {
            guard scalars[index].isNumber else { index += 1; continue }
            let start = index
            while index < scalars.count, scalars[index].isNumber { index += 1 }
            let digits = String(scalars[start..<index])
            if index < scalars.count, scalars[index] == " " { index += 1 }
            guard index < scalars.count, scalars[index] == "W" || scalars[index] == "w" else { continue }
            let next = index + 1
            guard next == scalars.count || !scalars[next].isLetter else { continue }
            if let watts { return digits == String(watts) }
            return true
        }
        return false
    }

    private static func spaceBeforeWattUnit(_ text: String) -> String {
        var result = ""
        let scalars = Array(text)
        var index = 0
        while index < scalars.count {
            guard scalars[index].isNumber else {
                result.append(scalars[index])
                index += 1
                continue
            }
            let start = index
            while index < scalars.count, scalars[index].isNumber { index += 1 }
            let unit = index
            let followedByWatt = unit < scalars.count && (scalars[unit] == "W" || scalars[unit] == "w")
            let wordContinues = unit + 1 < scalars.count && scalars[unit + 1].isLetter
            if followedByWatt && !wordContinues {
                result.append(contentsOf: scalars[start..<unit])
                result.append(" W")
                index = unit + 1
                continue
            }
            result.append(contentsOf: scalars[start..<index])
        }
        return result
    }
}
