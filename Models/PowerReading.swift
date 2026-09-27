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

    init(mode: PowerMode, watts: Double?, batteryPercentage: Int? = nil,
         detail: String? = nil, components: [PowerComponent] = [],
         timestamp: Date = Date(), batteryState: BatteryState = .unknown,
         capabilities: PowerCapabilities = .init(), freshness: ReadingFreshness = .fresh,
         source: ReadingSource = .unavailable, chargerWatts: Double? = nil, systemWatts: Double? = nil,
         chargingHoldReason: BatteryChargingHoldReason? = nil,
         chargerThreshold: ChargerThresholdProvenance? = nil) {
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
    }

    // Validation binds the threshold decision to this sample and the Settings five-minute rule.
    var hasInsufficientCharger: Bool {
        guard let threshold = chargerThreshold,
              !threshold.episodeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              threshold.observedAt == timestamp,
              threshold.sustainedDuration.isFinite, threshold.sustainedDuration >= 300,
              source != .unavailable, freshness == .fresh,
              capabilities.battery == .available, capabilities.charger == .available,
              capabilities.systemDraw == .available, batteryState == .discharging,
              let watts, watts < 0, let chargerWatts, chargerWatts > 0,
              let systemWatts, systemWatts > chargerWatts,
              (try? validate()) != nil else { return false }
        return true
    }

    var insufficientChargerMessage: String? {
        guard hasInsufficientCharger else { return nil }
        let draw = PowerFormatter.watts(systemWatts, signed: false, precision: .whole)
        let input = PowerFormatter.watts(chargerWatts, signed: false, precision: .whole)
        return "Because your Mac draws \(draw) and this charger gives \(input). The battery covers the rest."
    }

    func validate() throws {
        guard timestamp.timeIntervalSince1970.isFinite,
              [watts, chargerWatts, systemWatts].compactMap({ $0 }).allSatisfy(\.isFinite),
              batteryPercentage.map({ (0...100).contains($0) }) ?? true,
              [chargerWatts, systemWatts].compactMap({ $0 }).allSatisfy({ $0 >= 0 }),
              Set(components.map(\.id)).count == components.count,
              components.allSatisfy({ !$0.id.isEmpty && $0.watts.isFinite && $0.watts >= 0 }),
              batteryState != .charging || (watts.map { $0 >= 0 } ?? true),
              batteryState != .discharging || (watts.map { $0 <= 0 } ?? true),
              batteryState != .noBattery || (watts == nil && batteryPercentage == nil)
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
