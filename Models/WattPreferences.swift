import Combine
import Foundation
#if SWIFT_PACKAGE
import WattMaintenanceShared
#endif

enum WattDisplayMode: String, CaseIterable, Hashable, Codable, Sendable {
    case delta = "Delta", charger = "Charger", draw = "Draw", components = "Components", iconOnly = "Icon Only"

    /// Menu bar and Settings label. Raw values stay the stored identifiers.
    var title: String {
        switch self {
        case .delta: return "Battery Delta"
        case .charger: return "Charger Input"
        case .draw: return "System Draw"
        case .components: return "Per Component"
        case .iconOnly: return "Icon Only"
        }
    }
}

enum ServiceFailure: String, Error, Codable, Sendable {
    case denied, timedOut, disconnected, network, interruptedUpdate, interruptedRemoval
    case cancelled, invalidData, persistence, untrustedIdentity, incompatibleVersion, unknownStatus
    case adminRequired
}
enum ServiceOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(ServiceFailure)
}

typealias OperationReceipt = MaintenanceReceipt

enum HelperState: Equatable, Codable, Sendable {
    case unknown, absent, awaitingApproval, disabled, connected, updateRequired, disconnected
    case failed(ServiceFailure)
}
enum ApprovalOrigin: String, CaseIterable, Codable, Sendable { case onboarding, settings }
struct ApprovalInterest: Equatable, Codable, Sendable {
    var interested = false
    var failure: ServiceFailure?
}
struct HelperCheckpoint: Equatable, Codable, Sendable {
    var desiredOn = false
    var receipt: OperationReceipt?
    var origins: [ApprovalOrigin: ApprovalInterest] = [:]
}
struct ApprovalToken: Equatable, Sendable {
    let origin: ApprovalOrigin
    let operationID: UUID
    let generation: UUID
    let presentationID: UUID
}
// OS status plus an authenticated connection is required for .connected. Unknown is not absence proof.
enum HelperReconciliation: Sendable { case pending, connected, absent, unknown, failed(ServiceFailure) }

enum UpdateState: Equatable, Codable, Sendable {
    case idle, checking, available(version: String), downloading(progress: Double)
    case staged(OperationReceipt), installing(OperationReceipt), awaitingRelaunch(OperationReceipt)
    case completed(OperationReceipt), failed(ServiceFailure, OperationReceipt?)
    case adminRequired(OperationReceipt), handoffAccepted(OperationReceipt)
}
enum RemovalOutcome: Equatable, Sendable {
    case verifiedAbsent, cancelled, failed(ServiceFailure), interrupted(OperationReceipt)
    case adminRequired(OperationReceipt), handoffAccepted(OperationReceipt)
}
enum NotificationAuthorization: String, Sendable { case notDetermined, denied, authorized }
enum OnboardingCheckpoint: String, Codable, Sendable { case welcome, picker, helperOffer, approval, preview, allSet, coachMark, livePanel, welcomeClosed, runningDefaults }
struct OnboardingState: Equatable, Codable, Sendable {
    var checkpoint: OnboardingCheckpoint = .welcome
    var completed = false
    var helperOptIn = false
    // Optional for backwards-compatible decoding; each deferred prompt has its own authority.
    var deferredSetupID: UUID?
}

@MainActor
protocol PreferenceStorage {
    func read(key: String) throws -> Data?
    func write(_ data: Data, key: String) throws
}

@MainActor
final class InMemoryStorage: PreferenceStorage {
    var values: [String: Data] = [:]
    var failReads = false
    var failWrites = false
    func read(key: String) throws -> Data? {
        if failReads { throw ServiceFailure.persistence }
        return values[key]
    }
    func write(_ data: Data, key: String) throws {
        if failWrites { throw ServiceFailure.persistence }
        values[key] = data
    }
}

// Explicit injection only: no implicit .standard domain, including previews and tests.
/// Launch reads these keys off the main thread, then serves them from memory.
/// A key that was not in that read falls through to `UserDefaults` later, so a
/// follow-up claim is not treated as missing just because launch did not ask for it.
@MainActor
final class PrimedUserDefaults: PreferenceStorage {
    static let launchKeys = ["preferences.v1", "update.v1", "update.automatic-install.v1", "update.helper-follow-up.v1"]
    private let defaults: UserDefaults
    private var values: [String: Data] = [:]
    private var written = Set<String>()
    private var prefetched = Set<String>()
    private var primed = false
    init(defaults: UserDefaults) { self.defaults = defaults }
    func prime(keys: [String], values incoming: [String: Data]) {
        var next = incoming
        for key in written {
            if let kept = values[key] { next[key] = kept }
        }
        values = next
        prefetched = Set(keys)
        primed = true
    }
    func read(key: String) throws -> Data? {
        if let value = values[key] { return value }
        if prefetched.contains(key) || !primed { return nil }
        return defaults.data(forKey: key)
    }
    func write(_ data: Data, key: String) throws {
        values[key] = data
        written.insert(key)
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class UserDefaultsStorage: PreferenceStorage {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    func read(key: String) throws -> Data? { defaults.data(forKey: key) }
    func write(_ data: Data, key: String) throws { defaults.set(data, forKey: key) }
}

private enum NotificationPreferenceDefaults {
    static let insufficientChargerMinutes = 5
    static let fullyChargedPercentage = 100
    static let lowBatteryPercentage = 20
}

enum WattPrecision: String, CaseIterable, Codable, Sendable {
    case decimal = "42.1 W", whole = "42 W", hundredths = "42.10 W"

    var decimalPlaces: Int {
        switch self {
        case .whole: return 0
        case .decimal: return 1
        case .hundredths: return 2
        }
    }
}

private struct StoredPreferences: Codable {
    var precision: WattPrecision? = nil
    var displayMode: WattDisplayMode = .draw
    var showSymbol = true
    var updateInterval = "Every 2 seconds"
    var smoothReadings = true
    var componentReadings = true
    var chargerNotification = true
    var fullyChargedNotification = false
    // Optional so a preferences file written before these thresholds still decodes.
    var lowBatteryNotification: Bool? = nil
    var lowBatteryPercentage: Int? = nil
    var insufficientChargerMinutes: Int? = nil
    var fullyChargedPercentage: Int? = nil
    var openAtLogin = false
    var checkForUpdatesAutomatically = true
    var selectedComponents = ["CPU", "GPU"]
    var onboarding = OnboardingState()
}

@MainActor
final class PreferencesStore: ObservableObject {
    private let storage: any PreferenceStorage
    private var loading = true
    private var userEdited = false
    /// Production launch sets this false until preferences have been read off the main thread.
    /// Tests and fixtures load immediately, so they stay ready.
    private(set) var launchFilesReady = true
    @Published private(set) var persistenceFailure: ServiceFailure?
    @Published var displayMode: WattDisplayMode = .draw { didSet { save() } }
    @Published var precision: WattPrecision = .decimal { didSet { save() } }
    @Published var showSymbol = true { didSet { save() } }
    @Published var updateInterval = "Every 2 seconds" { didSet { save() } }
    @Published var smoothReadings = true { didSet { save() } }
    @Published var componentReadings = true { didSet { save() } }
    @Published var chargerNotification = true { didSet { save() } }
    @Published var fullyChargedNotification = false { didSet { save() } }
    @Published var lowBatteryNotification = false { didSet { save() } }
    @Published private var storedLowBatteryPercentage = NotificationPreferenceDefaults.lowBatteryPercentage
    @Published private var storedInsufficientChargerMinutes = NotificationPreferenceDefaults.insufficientChargerMinutes
    @Published private var storedFullyChargedPercentage = NotificationPreferenceDefaults.fullyChargedPercentage
    @Published var openAtLogin = false { didSet { save() } }
    @Published var checkForUpdatesAutomatically = true { didSet { save() } }
    @Published var onboarding = OnboardingState() { didSet { save() } }
    @Published private var validatedComponents = ["CPU", "GPU"]
    // Validate before @Published emits; direct assignments and SwiftUI bindings remain supported.
    var selectedComponents: [String] {
        get { validatedComponents }
        set {
            guard Self.validSelection(newValue) else {
                persistenceFailure = .invalidData
                return
            }
            if !loading {
                var candidate = snapshot
                candidate.selectedComponents = newValue
                guard persist(candidate) else { return }
            }
            validatedComponents = newValue
        }
    }
    var selectedComponentsPublisher: Published<[String]>.Publisher { $validatedComponents }
    static func validSelection(_ ids: [String]) -> Bool {
        ids.count <= 2 && Set(ids.map { $0.lowercased() }).count == ids.count
            && ids.allSatisfy { !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static let defaultInsufficientChargerMinutes = NotificationPreferenceDefaults.insufficientChargerMinutes
    static let defaultFullyChargedPercentage = NotificationPreferenceDefaults.fullyChargedPercentage
    static let defaultLowBatteryPercentage = NotificationPreferenceDefaults.lowBatteryPercentage
    static let insufficientChargerMinuteChoices = [1, 2, 5, 10, 15]
    static let fullyChargedPercentageChoices = [80, 90, 95, 100]
    static let lowBatteryPercentageChoices = [10, 15, 20, 25, 30]

    static func isValidInsufficientChargerMinutes(_ minutes: Int) -> Bool { (1...60).contains(minutes) }
    static func isValidFullyChargedPercentage(_ percentage: Int) -> Bool { (1...100).contains(percentage) }
    static func isValidLowBatteryPercentage(_ percentage: Int) -> Bool { (1...99).contains(percentage) }

    static func chargerDurationLabel(minutes: Int) -> String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private static func accepted(_ value: Int?, fallback: Int, isValid: (Int) -> Bool) -> Int {
        guard let value, isValid(value) else { return fallback }
        return value
    }

    var lowBatteryPercentage: Int {
        get { storedLowBatteryPercentage }
        set { assign(newValue, isValid: Self.isValidLowBatteryPercentage, store: { storedLowBatteryPercentage = $0 }, write: { $0.lowBatteryPercentage = $1 }) }
    }
    var insufficientChargerMinutes: Int {
        get { storedInsufficientChargerMinutes }
        set { assign(newValue, isValid: Self.isValidInsufficientChargerMinutes, store: { storedInsufficientChargerMinutes = $0 }, write: { $0.insufficientChargerMinutes = $1 }) }
    }
    var fullyChargedPercentage: Int {
        get { storedFullyChargedPercentage }
        set { assign(newValue, isValid: Self.isValidFullyChargedPercentage, store: { storedFullyChargedPercentage = $0 }, write: { $0.fullyChargedPercentage = $1 }) }
    }
    var insufficientChargerDuration: TimeInterval { TimeInterval(insufficientChargerMinutes * 60) }

    /// Persist the candidate before publishing. A rejected value leaves the previous setting in place.
    private func assign(_ value: Int, isValid: (Int) -> Bool, store: (Int) -> Void, write: (inout StoredPreferences, Int) -> Void) {
        guard isValid(value) else {
            persistenceFailure = .invalidData
            return
        }
        if !loading {
            var candidate = snapshot
            write(&candidate, value)
            guard persist(candidate) else { return }
        }
        store(value)
    }

    static func seconds(for updateInterval: String) -> TimeInterval {
        switch updateInterval {
        case "Every second": return 1
        case "Every 2 seconds": return 2
        case "Every 5 seconds": return 5
        default: return 2
        }
    }

    var updateIntervalSeconds: TimeInterval { Self.seconds(for: updateInterval) }

    /// Available identities are re-read by the caller at invocation, never cached menu state.
    @discardableResult
    func toggleComponent(_ id: String, availableIDs: [String]) -> Bool {
        guard componentReadings, availableIDs.contains(id),
              Set(availableIDs.map { $0.lowercased() }).count == availableIDs.count,
              availableIDs.allSatisfy({ Self.validSelection([$0]) }) else { return false }
        var next = selectedComponents
        if let index = next.firstIndex(where: { $0.lowercased() == id.lowercased() }) {
            next.remove(at: index)
        } else {
            next.append(id)
        }
        guard Self.validSelection(next) else { return false }
        selectedComponents = next
        return selectedComponents == next && persistenceFailure == nil
    }
    init(storage: (any PreferenceStorage)? = nil, load: Bool = true) {
        self.storage = storage ?? InMemoryStorage()
        guard load else {
            launchFilesReady = false
            loading = false
            return
        }
        defer { loading = false }
        loadPreferences()
    }

    /// Applies bytes already read from disk. Does nothing after the user has edited a setting.
    func reloadFromStorage() {
        guard !userEdited else {
            launchFilesReady = true
            return
        }
        loading = true
        defer { loading = false; launchFilesReady = true }
        loadPreferences()
    }

    private func loadPreferences() {
        do {
            guard let data = try storage.read(key: "preferences.v1") else { return }
            let p = try JSONDecoder().decode(StoredPreferences.self, from: data)
            guard Self.validSelection(p.selectedComponents) else { throw ServiceFailure.invalidData }
            precision = p.precision ?? .decimal
            displayMode = p.displayMode; showSymbol = p.showSymbol; updateInterval = p.updateInterval
            smoothReadings = p.smoothReadings; componentReadings = p.componentReadings
            chargerNotification = p.chargerNotification; fullyChargedNotification = p.fullyChargedNotification
            lowBatteryNotification = p.lowBatteryNotification ?? false
            lowBatteryPercentage = Self.accepted(p.lowBatteryPercentage, fallback: Self.defaultLowBatteryPercentage, isValid: Self.isValidLowBatteryPercentage)
            insufficientChargerMinutes = Self.accepted(p.insufficientChargerMinutes, fallback: Self.defaultInsufficientChargerMinutes, isValid: Self.isValidInsufficientChargerMinutes)
            fullyChargedPercentage = Self.accepted(p.fullyChargedPercentage, fallback: Self.defaultFullyChargedPercentage, isValid: Self.isValidFullyChargedPercentage)
            openAtLogin = p.openAtLogin; checkForUpdatesAutomatically = p.checkForUpdatesAutomatically
            selectedComponents = p.selectedComponents; onboarding = p.onboarding
        } catch { persistenceFailure = .persistence }
    }
    @discardableResult
    func save() -> Bool {
        guard !loading else { return false }
        return persist(snapshot)
    }

    /// Commit before publishing or navigating. Failed writes never require a second rollback write.
    @discardableResult
    func transitionOnboarding(from expected: OnboardingState, to next: OnboardingState,
                              displayMode nextMode: WattDisplayMode? = nil) -> Bool {
        guard !loading, onboarding == expected else { return false }
        var candidate = snapshot
        candidate.onboarding = next
        if let nextMode { candidate.displayMode = nextMode }
        guard persist(candidate) else { return false }
        loading = true
        onboarding = next
        if let nextMode { displayMode = nextMode }
        loading = false
        return true
    }

    private var snapshot: StoredPreferences {
        StoredPreferences(precision: precision, displayMode: displayMode, showSymbol: showSymbol, updateInterval: updateInterval,
                                  smoothReadings: smoothReadings, componentReadings: componentReadings,
                                  chargerNotification: chargerNotification, fullyChargedNotification: fullyChargedNotification,
                                  lowBatteryNotification: lowBatteryNotification, lowBatteryPercentage: lowBatteryPercentage,
                                  insufficientChargerMinutes: insufficientChargerMinutes, fullyChargedPercentage: fullyChargedPercentage,
                                  openAtLogin: openAtLogin, checkForUpdatesAutomatically: checkForUpdatesAutomatically,
                                  selectedComponents: selectedComponents, onboarding: onboarding)
    }

    private func persist(_ p: StoredPreferences) -> Bool {
        userEdited = true
        do {
            try storage.write(JSONEncoder().encode(p), key: "preferences.v1")
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    static var preview: PreferencesStore { PreferencesStore(storage: InMemoryStorage()) }
}
