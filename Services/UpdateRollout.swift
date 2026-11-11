import Foundation

/// How a check was started. A manual check skips a running or paused schedule.
/// It does not skip a halted release.
enum UpdateCheckInitiator: String, Equatable, Sendable {
    case automatic
    case manual
}

/// Staged rollout carried inside the signed manifest. Missing on older manifests.
/// The key order matches `rollout_manifest.canonical`.
struct UpdateRollout: Codable, Equatable, Sendable {
    var basis: Int
    var interval: Int
    var steps: [Int]
    var paused: Bool
    var percent: Int
    var critical: Bool
    var halted: Bool

    static let minimumInterval = 3_600
    static let maximumInterval = 366 * 86_400
    static let maximumBasis = 4_102_444_800

    enum CodingKeys: String, CodingKey {
        case basis, interval, steps, paused, percent, critical, halted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(basis, forKey: .basis)
        try container.encode(interval, forKey: .interval)
        try container.encode(steps, forKey: .steps)
        try container.encode(paused, forKey: .paused)
        try container.encode(percent, forKey: .percent)
        try container.encode(critical, forKey: .critical)
        try container.encode(halted, forKey: .halted)
    }

    init(basis: Int, interval: Int, steps: [Int], paused: Bool, percent: Int, critical: Bool, halted: Bool) {
        self.basis = basis
        self.interval = interval
        self.steps = steps
        self.paused = paused
        self.percent = percent
        self.critical = critical
        self.halted = halted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        basis = try container.decode(Int.self, forKey: .basis)
        interval = try container.decode(Int.self, forKey: .interval)
        steps = try container.decode([Int].self, forKey: .steps)
        paused = try container.decode(Bool.self, forKey: .paused)
        percent = try container.decode(Int.self, forKey: .percent)
        critical = try container.decode(Bool.self, forKey: .critical)
        halted = try container.decode(Bool.self, forKey: .halted)
        try Self.validate(self)
    }

    /// Cohort size at `now`. A halted release is rejected by the gate before this is used.
    func share(at now: Date) -> Int {
        if critical { return 100 }
        if paused { return percent }
        guard interval > 0, !steps.isEmpty else { return 0 }
        let nowSeconds = Int(now.timeIntervalSince1970)
        guard nowSeconds >= basis else { return 0 }
        let index = min(steps.count - 1, (nowSeconds - basis) / interval)
        return steps[index]
    }

    static func validate(_ rollout: UpdateRollout) throws {
        guard (0...maximumBasis).contains(rollout.basis) else { throw ServiceFailure.invalidData }
        guard (minimumInterval...maximumInterval).contains(rollout.interval) else { throw ServiceFailure.invalidData }
        guard (1...16).contains(rollout.steps.count) else { throw ServiceFailure.invalidData }
        var previous = 0
        for step in rollout.steps {
            guard (1...100).contains(step), step > previous else { throw ServiceFailure.invalidData }
            previous = step
        }
        guard rollout.steps.last == 100 else { throw ServiceFailure.invalidData }
        guard (0...100).contains(rollout.percent) else { throw ServiceFailure.invalidData }
        guard !(rollout.critical && rollout.halted) else { throw ServiceFailure.invalidData }
    }
}

enum UpdateRolloutGate {
    /// `bucket` is private to this install and is never sent anywhere.
    /// Values outside 0..<100 fail closed.
    static func admits(rollout: UpdateRollout?, initiator: UpdateCheckInitiator, bucket: Int, now: Date) -> Bool {
        guard let rollout else { return true }
        if rollout.halted { return false }
        if initiator == .manual || rollout.critical { return true }
        guard (0..<RolloutBucket.count).contains(bucket) else { return false }
        return bucket < rollout.share(at: now)
    }
}

/// One random cohort, stored on this Mac. It is not a network identifier.
enum RolloutBucket {
    static let count = 100
    static let storageKey = "updater.rollout-bucket.v1"

    @MainActor
    static func stableValue(in storage: any PreferenceStorage) throws -> Int {
        if let data = try storage.read(key: storageKey),
           let value = try? JSONDecoder().decode(Int.self, from: data),
           (0..<count).contains(value) {
            return value
        }
        let value = Int.random(in: 0..<count)
        try storage.write(JSONEncoder().encode(value), key: storageKey)
        return value
    }
}
