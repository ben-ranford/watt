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
@MainActor
final class UserDefaultsStorage: PreferenceStorage {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    func read(key: String) throws -> Data? { defaults.data(forKey: key) }
    func write(_ data: Data, key: String) throws { defaults.set(data, forKey: key) }
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
    var openAtLogin = false
    var checkForUpdatesAutomatically = true
    var selectedComponents = ["CPU", "GPU"]
    var onboarding = OnboardingState()
}

@MainActor
final class PreferencesStore: ObservableObject {
    private let storage: any PreferenceStorage
    private var loading = true
    @Published private(set) var persistenceFailure: ServiceFailure?
    @Published var displayMode: WattDisplayMode = .draw { didSet { save() } }
    @Published var precision: WattPrecision = .decimal { didSet { save() } }
    @Published var showSymbol = true { didSet { save() } }
    @Published var updateInterval = "Every 2 seconds" { didSet { save() } }
    @Published var smoothReadings = true { didSet { save() } }
    @Published var componentReadings = true { didSet { save() } }
    @Published var chargerNotification = true { didSet { save() } }
    @Published var fullyChargedNotification = false { didSet { save() } }
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
    init(storage: (any PreferenceStorage)? = nil) {
        self.storage = storage ?? InMemoryStorage()
        defer { loading = false }
        do {
            guard let data = try self.storage.read(key: "preferences.v1") else { return }
            let p = try JSONDecoder().decode(StoredPreferences.self, from: data)
            guard Self.validSelection(p.selectedComponents) else { throw ServiceFailure.invalidData }
            precision = p.precision ?? .decimal
            displayMode = p.displayMode; showSymbol = p.showSymbol; updateInterval = p.updateInterval
            smoothReadings = p.smoothReadings; componentReadings = p.componentReadings
            chargerNotification = p.chargerNotification; fullyChargedNotification = p.fullyChargedNotification
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
                                  openAtLogin: openAtLogin, checkForUpdatesAutomatically: checkForUpdatesAutomatically,
                                  selectedComponents: selectedComponents, onboarding: onboarding)
    }

    private func persist(_ p: StoredPreferences) -> Bool {
        do {
            try storage.write(JSONEncoder().encode(p), key: "preferences.v1")
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    static var preview: PreferencesStore { PreferencesStore(storage: InMemoryStorage()) }
}
