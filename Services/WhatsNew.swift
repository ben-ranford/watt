import Foundation

/// Remembers which version has already shown What's New.
/// `launchedVersion` is the last version this Mac started.
/// `presentedVersion` is set when the window appears, not when it is dismissed.
struct WhatsNewRecord: Codable, Equatable, Sendable {
    var launchedVersion: String
    var presentedVersion: String?
}

enum WhatsNewAction: Equatable, Sendable {
    case show
    case suppress
}

struct WhatsNewEvaluation: Equatable, Sendable {
    var action: WhatsNewAction
    /// Written immediately for a fresh install or a same-version launch.
    /// Nil when the window itself must record that it appeared.
    var persist: WhatsNewRecord?
}

enum WhatsNewCenter {
    static func evaluate(current: String, record: WhatsNewRecord?) -> WhatsNewEvaluation {
        let version = current.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else {
            return WhatsNewEvaluation(action: .suppress, persist: nil)
        }
        guard let record else {
            return WhatsNewEvaluation(
                action: .suppress,
                persist: WhatsNewRecord(launchedVersion: version, presentedVersion: nil)
            )
        }
        if record.launchedVersion == version || record.presentedVersion == version {
            let persist = record.launchedVersion == version
                ? nil
                : WhatsNewRecord(launchedVersion: version, presentedVersion: record.presentedVersion)
            return WhatsNewEvaluation(action: .suppress, persist: persist)
        }
        return WhatsNewEvaluation(action: .show, persist: nil)
    }

    static func appearedRecord(current: String) -> WhatsNewRecord {
        WhatsNewRecord(launchedVersion: current, presentedVersion: current)
    }
}

/// Local record of the What's New window. Nothing here is sent off the Mac.
@MainActor
final class WhatsNewStore {
    static let storageKey = "whatsNew.v1"
    private let storage: any PreferenceStorage

    init(storage: any PreferenceStorage) {
        self.storage = storage
    }

    func record() -> WhatsNewRecord? {
        guard let data = try? storage.read(key: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(WhatsNewRecord.self, from: data)
    }

    func evaluate(current: String) -> WhatsNewEvaluation {
        WhatsNewCenter.evaluate(current: current, record: record())
    }

    func write(_ record: WhatsNewRecord) throws {
        do { try storage.write(JSONEncoder().encode(record), key: Self.storageKey) }
        catch { throw ServiceFailure.persistence }
    }

    /// First launch of a version that is not the one we last started.
    /// A missing record is a fresh install and stays quiet.
    func launch(_ current: String) throws -> WhatsNewAction {
        let evaluation = evaluate(current: current)
        if let record = evaluation.persist { try write(record) }
        return evaluation.action
    }

    /// Call when the window is on screen. Dismissal does not call this again.
    func markAppeared(current: String) throws {
        try write(WhatsNewCenter.appearedRecord(current: current))
    }
}
