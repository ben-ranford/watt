import Combine
import Foundation

@MainActor
protocol WattClock { var now: Date { get }; var uptime: TimeInterval { get } }
extension WattClock { var uptime: TimeInterval { now.timeIntervalSince1970 } }
@MainActor
struct SystemWattClock: WattClock {
    var now: Date { Date() }
    var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
@MainActor
final class FakeWattClock: WattClock {
    var now: Date
    private(set) var uptime: TimeInterval = 0
    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) { self.now = now }
    func advance(by interval: TimeInterval) { now = now.addingTimeInterval(interval); uptime += max(0, interval) }
}

@MainActor
final class PowerReadingStore: ObservableObject {
    @Published private(set) var currentReading: PowerReading
    @Published private(set) var failure: ServiceFailure?
    @Published private(set) var isRefreshing = false
    static let statusMaximumAge: TimeInterval = 5
    static let retryInterval: TimeInterval = 3
    // A configured five-second sample interval must not race the five-second
    // status expiry. Leave a small lead so scheduler jitter cannot turn a
    // healthy periodic sampler into a visible "No reading" state.
    static let samplingRefreshLeadTime: TimeInterval = 0.5
    // Full status must be recent even if an adapter leaves its snapshot marked fresh.
    static let fullStatusMaximumAge: TimeInterval = 5
    static let chargerStatusMaximumAge: TimeInterval = 5
    static let onBatteryStatusMaximumAge: TimeInterval = 5
    static let componentsStatusMaximumAge: TimeInterval = 5
    // Retain the last sample for diagnostics, but suppress qualified status after a failed update.
    var statusReading: PowerReading {
        if componentTelemetry != nil { return systemStatusReading.presenting(freshComponentEstimate) }
        return systemStatusReading
    }
    private var systemStatusReading: PowerReading {
        guard failure == nil, freshness(maximumAge: Self.statusMaximumAge) == .fresh else { return .unavailable }
        if currentReading.mode == .perComponent,
           failure != nil || freshness(maximumAge: Self.componentsStatusMaximumAge) != .fresh { return .unavailable }
        if currentReading.batteryState == .discharging,
           failure != nil || freshness(maximumAge: Self.onBatteryStatusMaximumAge) != .fresh { return .unavailable }
        if currentReading.chargerThreshold != nil,
           failure != nil || freshness(maximumAge: Self.chargerStatusMaximumAge) != .fresh { return .unavailable }
        if failure != nil && [.chargingHold, .full].contains(currentReading.batteryState) { return .unavailable }
        if currentReading.batteryState == .full,
           freshness(maximumAge: Self.fullStatusMaximumAge) != .fresh { return .unavailable }
        return currentReading
    }
    @Published private(set) var componentFailure: ServiceFailure?
    @Published private(set) var componentEstimate: ComponentEstimatePair?
    private var componentTelemetry: (any ComponentTelemetryService)?
    private var componentRequest: UUID?
    private var componentReceivedUptime: TimeInterval?
    private var componentInitialAge: TimeInterval = 0
    private var lastComponentStart: TimeInterval?
    private var componentExpiry: Task<Void, Never>?
    private var lastAcquisition: (id: UUID, startedAt: Date)?
    var freshComponentEstimate: ComponentEstimatePair? {
        guard componentFailure == nil, let pair = componentEstimate,
              let received = componentReceivedUptime,
              clock.uptime >= received,
              componentInitialAge + clock.uptime - received <= Self.componentsStatusMaximumAge,
              clock.now >= pair.startedAt,
              clock.now.timeIntervalSince(pair.startedAt) <= Self.componentsStatusMaximumAge else { return nil }
        return pair
    }
    private let clock: any WattClock
    private let telemetry: (any TelemetryService)?
    var observesSystemWake: Bool { clock is SystemWattClock && telemetry != nil }
    private var refreshRequest: UUID?
    private var onBatteryExpiry: Task<Void, Never>?
    private(set) var generation = UUID()
    init(currentReading: PowerReading, clock: (any WattClock)? = nil, telemetry: (any TelemetryService)? = nil,
         componentTelemetry: (any ComponentTelemetryService)? = nil) {
        self.clock = clock ?? SystemWattClock()
        self.telemetry = telemetry
        self.componentTelemetry = componentTelemetry
        do {
            try currentReading.validate()
            guard currentReading.timestamp <= self.clock.now else { throw ServiceFailure.invalidData }
            self.currentReading = currentReading
        }
        catch { self.currentReading = .unavailable; failure = .invalidData }
        scheduleOnBatteryExpiry()
    }
    deinit { onBatteryExpiry?.cancel(); componentExpiry?.cancel() }

    private func scheduleOnBatteryExpiry() {
        onBatteryExpiry?.cancel()
        // Frozen test/fixture clocks advance explicitly; never attach wall-clock work to them.
        guard clock is SystemWattClock else { return }
        let maximumAge = Self.statusMaximumAge
        guard freshness(maximumAge: maximumAge) == .fresh else { return }
        let delay = max(0, maximumAge - clock.now.timeIntervalSince(currentReading.timestamp)) + 0.01
        onBatteryExpiry = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            // Invalidate already-visible panel/status views even if no later sample arrives.
            self.objectWillChange.send()
        }
    }
    // A restart/disconnect invalidates outstanding requests even if their timestamps are newer.
    @discardableResult
    func restart() -> UUID {
        generation = UUID()
        invalidateComponents()
        refreshRequest = nil
        isRefreshing = false
        return generation
    }
    /// Wake invalidates pre-sleep observations and any request still in flight.
    func handleWake() {
        onBatteryExpiry?.cancel()
        restart()
        currentReading = .unavailable
        failure = nil
    }

    /// Manual retry and periodic sampling share validation and generation ownership.
    func refresh() async {
        guard !Task.isCancelled, let telemetry, refreshRequest == nil else { return }
        let request = UUID()
        let expectedGeneration = generation
        refreshRequest = request
        isRefreshing = true
        defer {
            if refreshRequest == request { refreshRequest = nil; isRefreshing = false }
        }
        let outcome = await telemetry.sample()
        guard !Task.isCancelled, expectedGeneration == generation, refreshRequest == request else { return }
        switch outcome {
        case .success(let reading):
            _ = accept(reading, generation: expectedGeneration)
        case .failure(let reason):
            failure = reason
        }
    }

    /// The status item's task owns cancellation; frozen fixture clocks never poll the host.
    func runSampling(interval: @escaping @MainActor () -> TimeInterval = { PowerReadingStore.retryInterval }) async {
        guard observesSystemWake else { return }
        async let components: Void = runComponentSampling()
        while !Task.isCancelled {
            await refresh()
            let delay = Self.samplingDelay(for: interval())
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { break }
        }
        _ = await components
    }

    /// A helper installed after launch starts component sampling without replacing the system sampler.
    func attachComponentTelemetry(_ service: any ComponentTelemetryService) {
        guard componentTelemetry == nil else { return }
        componentTelemetry = service
        componentFailure = nil
        Task { await runComponentSampling() }
    }

    private var componentSamplerRunning = false
    private func runComponentSampling() async {
        guard componentTelemetry != nil, !componentSamplerRunning else { return }
        componentSamplerRunning = true
        defer { componentSamplerRunning = false }
        while !Task.isCancelled {
            let started = clock.uptime
            await refreshComponents()
            let delay = max(0.05, Self.retryInterval - (clock.uptime - started))
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        }
    }

    func invalidateComponents() {
        componentRequest = nil
        componentExpiry?.cancel()
        componentEstimate = nil
        componentReceivedUptime = nil
        componentFailure = .disconnected
    }

    func refreshComponents() async {
        guard !Task.isCancelled, let componentTelemetry, componentRequest == nil else { return }
        let started = clock.uptime
        guard lastComponentStart.map({ started - $0 >= Self.retryInterval }) ?? true else { return }
        lastComponentStart = started
        let request = UUID(), expectedGeneration = generation
        componentRequest = request
        defer { if componentRequest == request { componentRequest = nil } }
        let outcome = await componentTelemetry.sampleComponents()
        guard !Task.isCancelled, generation == expectedGeneration, componentRequest == request else { return }
        switch outcome {
        case .failure(let failure):
            componentEstimate = nil
            componentFailure = failure
        case .success(let pair):
            let elapsed = clock.uptime - started
            let age = clock.now.timeIntervalSince(pair.startedAt)
            guard (try? pair.validate()) != nil, elapsed >= 0, elapsed <= 5,
                  age >= pair.duration, age <= Self.componentsStatusMaximumAge,
                  lastAcquisition.map({ pair.acquisitionID != $0.id && pair.startedAt > $0.startedAt }) ?? true else {
                componentEstimate = nil; componentFailure = .invalidData; return
            }
            lastAcquisition = (pair.acquisitionID, pair.startedAt)
            componentInitialAge = max(age, elapsed)
            componentReceivedUptime = clock.uptime
            componentEstimate = pair
            componentFailure = nil
            componentExpiry?.cancel()
            if clock is SystemWattClock {
                let delay = max(0, Self.componentsStatusMaximumAge - componentInitialAge) + 0.01
                componentExpiry = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                    self?.objectWillChange.send()
                }
            }
        }
    }

    /// Keep scheduled samples inside the visible status freshness window.
    /// Preference intervals shorter than the window remain unchanged; only an
    /// interval that would expire the current reading is brought forward.
    static func samplingDelay(for requestedInterval: TimeInterval) -> TimeInterval {
        let normalized = requestedInterval.isFinite && requestedInterval > 0
            ? requestedInterval : retryInterval
        let maximum = max(0.1, statusMaximumAge - samplingRefreshLeadTime)
        return min(normalized, maximum)
    }
    func disconnect() {
        onBatteryExpiry?.cancel()
        restart()
        currentReading = .unavailable
        failure = .disconnected
    }
    @discardableResult
    func accept(_ reading: PowerReading, generation: UUID) -> Bool {
        guard generation == self.generation else { return false }
        do { try reading.validate() } catch { failure = .invalidData; return false }
        guard reading.timestamp <= clock.now else { failure = .invalidData; return false }
        guard reading.timestamp >= currentReading.timestamp else { return false }
        currentReading = reading; failure = nil
        scheduleOnBatteryExpiry()
        return true
    }
    func freshness(maximumAge: TimeInterval) -> ReadingFreshness {
        currentReading.freshness(at: clock.now, maximumAge: maximumAge)
    }

    var availableComponentIDs: [String] {
        if componentTelemetry != nil { return freshComponentEstimate?.components.map(\.id) ?? [] }
        let ids = currentReading.components.map(\.id)
        guard failure == nil, currentReading.capabilities.components == .available,
              freshness(maximumAge: Self.componentsStatusMaximumAge) == .fresh,
              (try? currentReading.validate()) != nil,
              Set(ids.map { $0.lowercased() }).count == ids.count,
              ids.allSatisfy({ PreferencesStore.validSelection([$0]) }) else { return [] }
        return ids
    }
    static var preview: PowerReadingStore {
        PowerReadingStore(currentReading: .sampleCharging, clock: FakeWattClock())
    }
}

@MainActor
protocol ComponentTelemetryService {
    func sampleComponents() async -> ServiceOutcome<ComponentEstimatePair>
}

// Adapters must return outcomes, not throw permission/network failures through view code.
// Cancellation stops app work, never implies OS revocation or rollback of an acknowledged effect.
@MainActor
protocol TelemetryService {
    func sample() async -> ServiceOutcome<PowerReading>
}
@MainActor
protocol HelperService {
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation
    // Repeated registration with the same receipt must be idempotent. No root operations.
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState>
    func remove(receipt: OperationReceipt) async -> RemovalOutcome
}
@MainActor
protocol UpdateService {
    func check() async -> ServiceOutcome<String?>
    /// Notes carried in the signed manifest for `version`. Nil when that manifest has none.
    func releaseNotes(for version: String) -> String?
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState>
    func download(version: String, receipt: OperationReceipt,
                  progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState>
    // Must authenticate signed manifest/artifact before staging, and require user confirmation.
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState>
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState>
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState>
    // Success proves pre-install resources are absent and this exact receipt cannot install.
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt>
}
struct UpdateDownloadProgress: Equatable, Sendable {
    let received: Int64
    let total: Int64
    var isValid: Bool { total > 0 && received >= 0 && received <= total }
    var fraction: Double { isValid ? Double(received) / Double(total) : 0 }
    var label: String {
        String(format: "%.1f MB of %.1f MB", locale: Locale(identifier: "en_US_POSIX"),
               Double(received) / 1_000_000, Double(total) / 1_000_000)
    }
}

extension UpdateService {
    func releaseNotes(for version: String) -> String? { nil }
    func download(version: String, receipt: OperationReceipt,
                  progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        await download(version: version, receipt: receipt)
    }
}

@MainActor
protocol NotificationBridge {
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async -> ServiceOutcome<NotificationAuthorization>
    func deliver(identifier: String, title: String, body: String) async -> ServiceOutcome<Bool>
    func deliver(identifier: String, title: String, body: String,
                 isEligible: () -> Bool) async -> ServiceOutcome<Bool>
}

extension NotificationBridge {
    func deliver(identifier: String, title: String, body: String,
                 isEligible: () -> Bool) async -> ServiceOutcome<Bool> {
        guard isEligible() else { return .failure(.invalidData) }
        return await deliver(identifier: identifier, title: title, body: body)
    }
}
@MainActor
protocol LoginItemService {
    func effectiveEnabled() async -> ServiceOutcome<Bool>
    func setEnabled(_ enabled: Bool) async -> ServiceOutcome<Bool>
}
@MainActor
protocol UninstallCoordinator {
    // Only the approved owned-resource inventory; no path supplied by presentation code.
    func removeOwnedResources(receipt: OperationReceipt) async -> RemovalOutcome
    func reconcile(receipt: OperationReceipt) async -> RemovalOutcome
}

struct ApprovalRequest: Equatable, Sendable {
    let token: ApprovalToken
    let receipt: OperationReceipt
    let registrationRequired: Bool
}

// Serialized shared intent; this store never opens a scene or installs a helper.
@MainActor
final class HelperApprovalStore: ObservableObject {
    @Published private(set) var checkpoint = HelperCheckpoint()
    @Published private(set) var effectiveState: HelperState = .unknown
    @Published private(set) var persistenceFailure: ServiceFailure?
    private(set) var generation: UUID?
    private var tokens: [ApprovalOrigin: ApprovalToken] = [:]
    private let storage: any PreferenceStorage
    private let clock: any WattClock

    init(storage: (any PreferenceStorage)? = nil, clock: (any WattClock)? = nil) {
        self.storage = storage ?? InMemoryStorage(); self.clock = clock ?? SystemWattClock()
        do {
            if let data = try self.storage.read(key: "helper.v1") {
                checkpoint = try JSONDecoder().decode(HelperCheckpoint.self, from: data)
                guard checkpoint.desiredOn == checkpoint.origins.values.contains(where: \.interested),
                      !checkpoint.desiredOn || checkpoint.receipt != nil else { throw ServiceFailure.invalidData }
            }
        } catch { persistenceFailure = .persistence; checkpoint = HelperCheckpoint() }
        // Restart restores intent only, never tokens, effective availability or registration authority.
    }

    private func persist(_ next: HelperCheckpoint) throws {
        do {
            try storage.write(JSONEncoder().encode(next), key: "helper.v1")
            checkpoint = next; persistenceFailure = nil
        } catch { persistenceFailure = .persistence; throw ServiceFailure.persistence }
    }

    // Call only with a fresh authoritative status query; .absent includes no-in-flight proof.
    // Retry always reconciles first. .unknown never permits a registration.
    func join(_ origin: ApprovalOrigin, reconciled status: HelperReconciliation) throws -> ApprovalRequest {
        tokens[origin] = nil // Even failed retry cannot retain stale presentation authority.
        var next = checkpoint
        let registrationRequired: Bool
        switch status {
        case .unknown: throw ServiceFailure.unknownStatus
        case .failed(let reason): throw reason
        case .absent:
            registrationRequired = generation == nil
            if registrationRequired { next.receipt = OperationReceipt(createdAt: clock.now) }
        case .pending, .connected:
            registrationRequired = false
            // Reconciliation of a discovered registration still needs a durable local receipt.
            if next.receipt == nil { next.receipt = OperationReceipt(createdAt: clock.now) }
        }
        guard let receipt = next.receipt else { throw ServiceFailure.unknownStatus }
        next.origins[origin] = ApprovalInterest(interested: true, failure: nil)
        next.desiredOn = true
        try persist(next)
        let wait = generation ?? UUID()
        generation = wait
        let token = ApprovalToken(origin: origin, operationID: receipt.id, generation: wait, presentationID: UUID())
        tokens[origin] = token
        reconcileEffective(status)
        return ApprovalRequest(token: token, receipt: receipt, registrationRequired: registrationRequired)
    }

    // Closing hides only presentation. It deliberately retains interest and shared wait generation.
    func close(_ origin: ApprovalOrigin) { tokens[origin] = nil }

    func withdraw(_ origin: ApprovalOrigin, reason: ServiceFailure = .cancelled) throws {
        tokens[origin] = nil
        var next = checkpoint
        next.origins[origin] = ApprovalInterest(interested: false, failure: reason)
        next.desiredOn = next.origins.values.contains(where: \.interested)
        if !next.desiredOn { generation = nil }
        try persist(next) // Failure stays visible; no successful cancellation acknowledgement.
    }

    func canNavigate(_ token: ApprovalToken) -> Bool {
        token == tokens[token.origin] && token.generation == generation &&
        token.operationID == checkpoint.receipt?.id && checkpoint.origins[token.origin]?.interested == true
    }

    // Stale callbacks may not update effective state. Independently query status, then use reconcileEffective.
    func receive(_ status: HelperReconciliation, operationID: UUID, generation: UUID,
                 origin: ApprovalOrigin? = nil) throws -> [ApprovalToken] {
        guard self.generation == generation, checkpoint.receipt?.id == operationID else { return [] }
        reconcileEffective(status)
        switch status {
        case .connected:
            let eligible = ApprovalOrigin.allCases.compactMap { tokens[$0] }
                .filter { canNavigate($0) && (origin == nil || $0.origin == origin) }
            // Single delivery; intent/checkpoint remain separate from onboarding completion.
            for token in eligible { tokens[token.origin] = nil }
            if tokens.isEmpty { self.generation = nil } // Preserve other origins’ undelivered authority.
            return eligible
        case .failed(let reason):
            let eligible = ApprovalOrigin.allCases.compactMap { tokens[$0] }.filter(canNavigate)
            tokens.removeAll(); self.generation = nil
            var next = checkpoint
            for origin in ApprovalOrigin.allCases where next.origins[origin]?.interested == true {
                next.origins[origin] = ApprovalInterest(interested: false, failure: reason)
            }
            next.desiredOn = false
            try persist(next)
            return eligible
        case .pending, .unknown, .absent: return []
        }
    }

    func reconcileEffective(_ status: HelperReconciliation) {
        switch status {
        case .connected: effectiveState = .connected
        case .pending: effectiveState = .awaitingApproval
        case .absent: effectiveState = .absent
        case .unknown: effectiveState = .unknown
        case .failed(let reason): effectiveState = .failed(reason)
        }
    }
}

@MainActor
final class FakeTelemetryService: TelemetryService {
    var outcome: ServiceOutcome<PowerReading>
    init(outcome: ServiceOutcome<PowerReading> = .success(.sampleCharging)) { self.outcome = outcome }
    func sample() async -> ServiceOutcome<PowerReading> {
        Task.isCancelled ? .failure(.cancelled) : outcome
    }
}

@MainActor
final class FakeHelperService: HelperService {
    var status: HelperReconciliation = .absent
    var registrationOutcome: ServiceOutcome<HelperState> = .success(.awaitingApproval)
    var removalOutcome: RemovalOutcome = .verifiedAbsent
    private(set) var registeredReceipts: Set<UUID> = []
    private var removals: [UUID: RemovalOutcome] = [:]
    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation { status }
    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        registeredReceipts.insert(receipt.id)
        return registrationOutcome
    }
    func remove(receipt: OperationReceipt) async -> RemovalOutcome {
        if let prior = removals[receipt.id] { return prior }
        guard !Task.isCancelled else { return .cancelled }
        if removalOutcome == .verifiedAbsent { removals[receipt.id] = removalOutcome; status = .absent }
        return removalOutcome
    }
}

// Transaction state is local evidence, not proof that the relaunched binary is trusted/running.
@MainActor
final class UpdateStore: ObservableObject {
    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var persistenceFailure: ServiceFailure?
    @Published private(set) var installFutureUpdatesAutomatically = false
    private(set) var generation = UUID()
    private(set) var downloadReceipt: OperationReceipt?
    private let storage: any PreferenceStorage
    init(storage: (any PreferenceStorage)? = nil) {
        self.storage = storage ?? InMemoryStorage()
        do {
            if let data = try self.storage.read(key: "update.automatic-install.v1") {
                installFutureUpdatesAutomatically = try JSONDecoder().decode(Bool.self, from: data)
            }
        } catch { persistenceFailure = .persistence }
        do {
            if let data = try self.storage.read(key: "update.v1") {
                let restored = try JSONDecoder().decode(UpdateState.self, from: data)
                switch restored {
                case .staged(let receipt), .installing(let receipt), .awaitingRelaunch(let receipt), .handoffAccepted(let receipt):
                    state = .failed(.interruptedUpdate, receipt)
                case .checking, .downloading, .available: state = .failed(.interruptedUpdate, nil)
                default: state = restored
                }
            }
        } catch { persistenceFailure = .persistence }
    }
    /// A saved preference is not consent to install a staged or restored update.
    @discardableResult
    func saveAutomaticInstallChoice(_ enabled: Bool) -> Bool {
        do {
            try storage.write(JSONEncoder().encode(enabled), key: "update.automatic-install.v1")
            installFutureUpdatesAutomatically = enabled
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }

    /// One helper-update alert per completed app-update receipt. A failed write can retry.
    @discardableResult
    func claimHelperFollowUp(_ receipt: OperationReceipt) -> Bool {
        guard receipt.isValid else { return false }
        let key = "update.helper-follow-up.v1"
        do {
            if let data = try storage.read(key: key),
               let existing = String(data: data, encoding: .utf8), existing == receipt.id.uuidString {
                return false
            }
            guard let data = receipt.id.uuidString.data(using: .utf8) else { return false }
            try storage.write(data, key: key)
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }

    // Persist a recovery marker BEFORE starting a service; restart never loses receipt ownership.
    func beginDownload(version: String, receipt: OperationReceipt, generation: UUID) -> Bool {
        guard generation == self.generation, state == .available(version: version) else { return false }
        do {
            try storage.write(JSONEncoder().encode(UpdateState.failed(.interruptedUpdate, receipt)), key: "update.v1")
            downloadReceipt = receipt
            state = .downloading(progress: 0)
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    // Preserve exact staged ownership on write failure. Intents themselves are never restored consent.
    func checkpointStaged(_ receipt: OperationReceipt, generation: UUID) -> Bool {
        guard generation == self.generation, downloadReceipt == receipt,
              state == .staged(receipt) else { return false }
        do {
            try storage.write(JSONEncoder().encode(state), key: "update.v1")
            persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    // Retry/recovery gets a new token; an interrupted receipt is retained for adapter reconciliation.
    @discardableResult
    func renewGeneration() -> UUID { generation = UUID(); return generation }
    @discardableResult
    func accept(_ next: UpdateState, generation: UUID) -> Bool {
        guard generation == self.generation, validTransition(to: next) else { return false }
        do {
            let durable: UpdateState
            if case .downloading = next, let downloadReceipt {
                durable = .failed(.interruptedUpdate, downloadReceipt)
            } else { durable = next }
            try storage.write(JSONEncoder().encode(durable), key: "update.v1")
            state = next; persistenceFailure = nil; return true
        } catch { persistenceFailure = .persistence; return false }
    }
    // Only pre-install work is cancellable locally. Installation needs explicit adapter recovery.
    @discardableResult
    func cancel() -> Bool {
        switch state {
        case .checking, .available, .downloading, .staged:
            renewGeneration()
            return accept(.failed(.cancelled, receipt(in: state)), generation: generation)
        default: return false
        }
    }
    // Call only with the adapter's successful discard acknowledgement for this exact receipt.
    // A failed write retains the receipt and generation so the acknowledgement can be retried.
    @discardableResult
    func acknowledgeDiscard(_ receipt: OperationReceipt, generation: UUID) -> Bool {
        guard generation == self.generation,
              case .failed(_, .some(let retained)) = state, retained == receipt else { return false }
        do {
            try storage.write(JSONEncoder().encode(UpdateState.idle), key: "update.v1")
            state = .idle
            downloadReceipt = nil
            persistenceFailure = nil
            renewGeneration()
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    private func receipt(in state: UpdateState) -> OperationReceipt? {
        switch state {
        case .staged(let r), .installing(let r), .awaitingRelaunch(let r), .completed(let r),
             .adminRequired(let r), .handoffAccepted(let r): return r
        case .failed(_, let r): return r
        case .downloading: return downloadReceipt
        default: return nil
        }
    }
    /// The ordinary composition calls this only with fresh adapter recovery evidence.
    /// This restores observation; install consent stays in the adapter's ephemeral state.
    @discardableResult
    func restoreVerifiedTransaction(_ next: UpdateState) -> Bool {
        guard let incoming = receipt(in: next), incoming.isValid,
              receipt(in: state) == nil || receipt(in: state) == incoming else { return false }
        switch next {
        case .staged, .failed(.interruptedUpdate, .some), .completed: break
        default: return false
        }
        do {
            try storage.write(JSONEncoder().encode(next), key: "update.v1")
            state = next; downloadReceipt = incoming; persistenceFailure = nil
            return true
        } catch { persistenceFailure = .persistence; return false }
    }
    private func validTransition(to next: UpdateState) -> Bool {
        if case .downloading(let progress) = next {
            guard progress.isFinite, (0...1).contains(progress) else { return false }
            if case .downloading(let previous) = state, progress < previous { return false }
        }
        if let current = receipt(in: state), let incoming = receipt(in: next), current != incoming { return false }
        switch (state, next) {
        case (.idle, .checking), (.completed, .checking), (.checking, .idle), (.checking, .available),
             (.available, .idle), (.available, .downloading), (.downloading, .downloading), (.downloading, .staged),
             (.staged, .installing), (.installing, .awaitingRelaunch), (.awaitingRelaunch, .completed): return true
        case (.staged, .adminRequired), (.adminRequired, .staged), (.adminRequired, .installing),
             (.staged, .handoffAccepted), (.handoffAccepted, .awaitingRelaunch),
             (.handoffAccepted, .completed): return true
        case (.failed(_, nil), .checking): return true
        // Only an adapter's authoritative recovery result may resume a retained transaction.
        case (.failed(_, .some), .staged), (.failed(_, .some), .awaitingRelaunch), (.failed(_, .some), .completed): return true
        case (.failed(_, .some), .handoffAccepted): return true
        case (_, .failed(_, let incoming)): return incoming == receipt(in: state)
        default: return false
        }
    }
}

@MainActor
final class FakeUpdateService: UpdateService {
    var availableVersion: ServiceOutcome<String?> = .success(nil)
    var offeredNotes: String?
    var failure: ServiceFailure?
    private(set) var transactions: [UUID: UpdateState] = [:]
    private var receipts: [UUID: OperationReceipt] = [:]
    private var discarded: Set<UUID> = []
    func check() async -> ServiceOutcome<String?> { Task.isCancelled ? .failure(.cancelled) : availableVersion }
    func releaseNotes(for version: String) -> String? {
        guard case .success(let available) = availableVersion, available == version else { return nil }
        return offeredNotes
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        if let failure { return .failure(failure) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard !discarded.contains(receipt.id) else { return .failure(.invalidData) }
        if let prior = transactions[receipt.id] {
            guard receipts[receipt.id] == receipt else { return .failure(.invalidData) }
            return .success(prior)
        }
        receipts[receipt.id] = receipt
        let state = UpdateState.staged(receipt)
        transactions[receipt.id] = state
        return .success(state)
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        if let failure { return .failure(failure) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard receipts[receipt.id] == receipt, !discarded.contains(receipt.id),
              let prior = transactions[receipt.id] else { return .failure(.invalidData) }
        if case .awaitingRelaunch = prior { return .success(prior) }
        guard case .staged = prior else { return .failure(.invalidData) }
        let state = UpdateState.awaitingRelaunch(receipt)
        transactions[receipt.id] = state
        return .success(state)
    }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        if let failure { return .failure(failure) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard receipts[receipt.id] == receipt, !discarded.contains(receipt.id) else {
            return .failure(.interruptedUpdate)
        }
        return transactions[receipt.id].map { .success($0) } ?? .failure(.interruptedUpdate)
    }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        if let failure { return .failure(failure) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard receipts[receipt.id] == receipt, !discarded.contains(receipt.id),
              let prior = transactions[receipt.id] else { return .failure(.invalidData) }
        if case .failed(.cancelled, receipt) = prior { return .success(prior) }
        guard case .staged = prior else { return .failure(.interruptedUpdate) }
        let cancelled = UpdateState.failed(.cancelled, receipt)
        transactions[receipt.id] = cancelled
        return .success(cancelled)
    }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> {
        if let failure { return .failure(failure) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard receipts[receipt.id] == receipt else { return .failure(.invalidData) }
        if discarded.contains(receipt.id) { return .success(receipt) }
        switch transactions[receipt.id] {
        case .staged, .failed(.cancelled, .some):
            discarded.insert(receipt.id)
            transactions[receipt.id] = nil
            return .success(receipt)
        default: return .failure(.interruptedUpdate)
        }
    }
}

@MainActor
final class FakeNotificationBridge: NotificationBridge {
    var permission: NotificationAuthorization = .notDetermined
    var requestedPermission: NotificationAuthorization = .denied
    private(set) var deliveredIDs: Set<String> = []
    func authorization() async -> NotificationAuthorization { permission }
    func requestAuthorization() async -> ServiceOutcome<NotificationAuthorization> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        permission = requestedPermission
        return .success(permission)
    }
    func deliver(identifier: String, title: String, body: String) async -> ServiceOutcome<Bool> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard permission == .authorized else { return .failure(.denied) }
        return .success(deliveredIDs.insert(identifier).inserted)
    }
}

@MainActor
final class FakeLoginItemService: LoginItemService {
    var enabled = false
    var failure: ServiceFailure?
    func effectiveEnabled() async -> ServiceOutcome<Bool> {
        failure.map { .failure($0) } ?? .success(enabled)
    }
    func setEnabled(_ enabled: Bool) async -> ServiceOutcome<Bool> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        if let failure { return .failure(failure) }
        self.enabled = enabled
        return .success(enabled)
    }
}

@MainActor
final class FakeUninstallCoordinator: UninstallCoordinator {
    var outcome: RemovalOutcome = .verifiedAbsent
    private(set) var completed: Set<UUID> = []
    func removeOwnedResources(receipt: OperationReceipt) async -> RemovalOutcome {
        if completed.contains(receipt.id) { return .verifiedAbsent }
        guard !Task.isCancelled else { return .cancelled }
        if outcome == .verifiedAbsent { completed.insert(receipt.id) }
        return outcome
    }
    func reconcile(receipt: OperationReceipt) async -> RemovalOutcome {
        completed.contains(receipt.id) ? .verifiedAbsent : .interrupted(receipt)
    }
}

// MARK: - P02 isolated helper lifecycle adapter
// No default OS driver: packaging/signing and a peer-authenticated transport are
// production prerequisites. Payload identity strings are never authentication.
enum HelperRegistrationStatus: Sendable {
    case absent, requiresApproval, enabled, disabled, unknown
}

enum HelperPeerIdentity: Equatable, Sendable {
    case appleTeam(String)
    case protectedCodeHash(installationID: UUID, generation: UInt64, cdhash: Data)
    var valid: Bool {
        switch self {
        case .appleTeam(let team): return !team.isEmpty
        case .protectedCodeHash(_, let generation, let hash): return generation > 0 && hash.count == 20
        }
    }
}

struct HelperPeer: Equatable, Sendable {
    let identifier: String
    let identity: HelperPeerIdentity
    let protocolVersion: Int
    init(identifier: String, identity: HelperPeerIdentity, protocolVersion: Int) {
        self.identifier = identifier; self.identity = identity; self.protocolVersion = protocolVersion
    }
    init(identifier: String, team: String, protocolVersion: Int) {
        self.init(identifier: identifier, identity: .appleTeam(team), protocolVersion: protocolVersion)
    }
}

struct HelperMessage: Equatable, Sendable {
    let requestID: UUID
    let generation: UUID
    let receiptID: UUID?
    let command: Command
    enum Command: Sendable { case ping, prepareUpdate }
}

@MainActor
protocol HelperLifecycleDriver {
    var supportsOwnedOfflineUpdate: Bool { get }
    // .absent must include proof that no registration/removal is in flight.
    func status() async throws -> HelperRegistrationStatus
    // Authenticate the bundled candidate before register/update, not after execution.
    func verifyCandidate() throws -> HelperPeer
    func register(receipt: OperationReceipt) async throws
    func update(receipt: OperationReceipt) async throws
    func unregister(receipt: OperationReceipt) async throws
    // Receipt-specific installed-version proof; connection alone is not update success.
    func updateApplied(receipt: OperationReceipt) async throws -> Bool
}

extension HelperLifecycleDriver {
    var supportsOwnedOfflineUpdate: Bool { false }
}

@MainActor
protocol HelperIPCTransport {
    // Must authenticate the actual peer (e.g. audit-token/code requirement), never
    // helper-supplied claims. A production implementation must also authorize clients.
    func connect() async throws -> HelperPeer
    func send(_ request: HelperMessage) async throws -> HelperMessage
    func invalidate()
}

@MainActor
final class HelperLifecycleAdapter: HelperService, ObservableObject {
    private let driver: any HelperLifecycleDriver
    private let transport: any HelperIPCTransport
    private let expectedPeer: HelperPeer
    @Published private(set) var state: HelperState = .unknown
    @Published private(set) var registrationPresent = false
    private(set) var generation = UUID()
    private var busy = false
    private var ownsRegistrationMutation = false
    private var registrations: Set<UUID> = []
    private var updates: Set<UUID> = []

    init(driver: any HelperLifecycleDriver, transport: any HelperIPCTransport, expectedPeer: HelperPeer) {
        self.driver = driver; self.transport = transport; self.expectedPeer = expectedPeer
    }

    func connectionLost() {
        // Update/removal deliberately end the old IPC session. Their OS operation and
        // receipt remain authoritative until completion; transport loss must not cancel them.
        guard !ownsRegistrationMutation else { return }
        generation = UUID()
        state = .disconnected
    }

    func disconnect() {
        generation = UUID()
        transport.invalidate()
        state = .disconnected
    }

    private func authenticate(_ peer: HelperPeer) throws {
        guard !expectedPeer.identifier.isEmpty, expectedPeer.identity.valid,
              peer.identifier == expectedPeer.identifier, peer.identity == expectedPeer.identity else {
            throw ServiceFailure.untrustedIdentity
        }
        guard peer.protocolVersion == expectedPeer.protocolVersion else { throw ServiceFailure.incompatibleVersion }
    }

    private func check(_ captured: UUID) throws {
        guard !Task.isCancelled else { throw ServiceFailure.cancelled }
        guard captured == generation else { throw ServiceFailure.disconnected }
    }

    private func failure(_ error: Error, generation captured: UUID) -> ServiceFailure {
        let reason = (error as? ServiceFailure) ?? .disconnected
        if captured == generation {
            disconnect()
            state = .failed(reason)
        }
        return reason
    }

    private func query(_ captured: UUID) async throws -> HelperReconciliation {
        let status = try await driver.status()
        try check(captured)
        switch status {
        case .enabled, .disabled, .requiresApproval: registrationPresent = true
        case .absent: registrationPresent = false
        case .unknown: break
        }
        switch status {
        case .absent: transport.invalidate(); state = .absent; return .absent
        case .requiresApproval: transport.invalidate(); state = .awaitingApproval; return .pending
        case .disabled: transport.invalidate(); state = .disabled; return .failed(.denied)
        case .unknown: transport.invalidate(); state = .unknown; return .unknown
        case .enabled:
            // Even an operation-owned registration must authenticate a live session.
            // Invalidation while awaiting this handshake cannot be treated as old-session teardown.
            let mutationOwnership = ownsRegistrationMutation
            ownsRegistrationMutation = false
            defer { ownsRegistrationMutation = mutationOwnership }
            let peer = try await transport.connect()
            try check(captured)
            try authenticate(peer)
            let request = HelperMessage(requestID: UUID(), generation: captured, receiptID: nil, command: .ping)
            let response = try await transport.send(request)
            try check(captured)
            guard response == request else { throw ServiceFailure.invalidData }
            state = .connected
            return .connected
        }
    }

    func reconcile(receipt: OperationReceipt?) async -> HelperReconciliation {
        guard !busy else { return .unknown }
        busy = true; defer { busy = false }
        let captured = generation
        do { try check(captured); return try await query(captured) }
        catch { return .failed(failure(error, generation: captured)) }
    }

    func register(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> {
        guard !busy else { return .failure(.unknownStatus) }
        busy = true
        ownsRegistrationMutation = true
        defer { busy = false; ownsRegistrationMutation = false }
        disconnect()
        let captured = generation
        do {
            try check(captured)
            let status = try await query(captured)
            switch status {
            case .absent:
                // Acknowledged receipts never execute twice; retry uses fresh OS evidence.
                if !registrations.contains(receipt.id) || driver.supportsOwnedOfflineUpdate {
                    try authenticate(driver.verifyCandidate())
                    registrations.insert(receipt.id) // Ambiguous failures must reconcile, not blindly replay.
                    try await driver.register(receipt: receipt)
                    try check(captured)
                }
            case .pending, .connected: return .success(state)
            case .unknown: throw ServiceFailure.unknownStatus
            case .failed(let reason): throw reason
            }
            ownsRegistrationMutation = false
            let result = try await query(captured)
            if case .failed(let reason) = result { throw reason }
            if case .unknown = result { throw ServiceFailure.unknownStatus }
            return .success(state)
        } catch { return .failure(failure(error, generation: captured)) }
    }

    func request(_ command: HelperMessage.Command, receipt: OperationReceipt? = nil) async -> ServiceOutcome<HelperMessage> {
        guard !busy, state == .connected else { return .failure(.disconnected) }
        busy = true; defer { busy = false }
        let captured = generation
        do {
            try check(captured)
            let request = HelperMessage(requestID: UUID(), generation: captured, receiptID: receipt?.id, command: command)
            let response = try await transport.send(request)
            try check(captured)
            guard response == request else { throw ServiceFailure.invalidData }
            return .success(response)
        } catch { return .failure(failure(error, generation: captured)) }
    }

    func update(receipt: OperationReceipt) async -> ServiceOutcome<HelperState> {
        guard !busy else { return .failure(.unknownStatus) }
        busy = true
        ownsRegistrationMutation = true
        defer { busy = false; ownsRegistrationMutation = false }
        disconnect()
        let captured = generation
        do {
            try check(captured)
            try authenticate(driver.verifyCandidate())
            if !updates.contains(receipt.id) || driver.supportsOwnedOfflineUpdate {
                if driver.supportsOwnedOfflineUpdate {
                    // Candidate authentication and exact OS registration own replacement;
                    // an incompatible or crashed old process must not prevent recovery.
                    let status = try await driver.status()
                    if case .unknown = status { throw ServiceFailure.unknownStatus }
                } else {
                    guard case .connected = try await query(captured) else { throw ServiceFailure.disconnected }
                    let request = HelperMessage(requestID: UUID(), generation: captured, receiptID: receipt.id, command: .prepareUpdate)
                    let reply = try await transport.send(request)
                    try check(captured)
                    guard request == reply else { throw ServiceFailure.invalidData }
                }
                updates.insert(receipt.id)
                transport.invalidate()
                state = .updateRequired
                try await driver.update(receipt: receipt)
                try check(captured)
            }
            let applied = try await driver.updateApplied(receipt: receipt)
            try check(captured)
            guard applied else { throw ServiceFailure.interruptedUpdate }
            ownsRegistrationMutation = false
            switch try await query(captured) {
            case .connected: return .success(.connected)
            case .pending: return .success(.awaitingApproval)
            default: throw ServiceFailure.interruptedUpdate
            }
        } catch { return .failure(failure(error, generation: captured)) }
    }

    func remove(receipt: OperationReceipt) async -> RemovalOutcome {
        // Invalidate pending reconnect/IPC immediately; never let its late reply resurrect state.
        disconnect()
        guard !busy else { return .interrupted(receipt) }
        busy = true
        ownsRegistrationMutation = true
        defer { busy = false; ownsRegistrationMutation = false }
        let captured = generation
        do {
            try check(captured)
            let before = try await driver.status()
            try check(captured)
            if case .unknown = before { throw ServiceFailure.unknownStatus }
            if case .absent = before { state = .absent; return .verifiedAbsent }
            try await driver.unregister(receipt: receipt)
            try check(captured)
            let after = try await driver.status()
            try check(captured)
            guard case .absent = after else { throw ServiceFailure.interruptedRemoval }
            state = .absent
            registrationPresent = false
            return .verifiedAbsent
        } catch {
            let reason = failure(error, generation: captured)
            return reason == .cancelled ? .cancelled : .failed(reason)
        }
    }
}

// MARK: - P03 notification and login adapters (explicit injection; no production composition)
import UserNotifications
import ServiceManagement

/// Limited/unknown system authorization fails closed in the narrower F03 contract.
enum NotificationPermission: CaseIterable, Sendable {
    case notDetermined, denied, authorized, provisional, unknown
    var contract: NotificationAuthorization {
        switch self {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        default: .denied
        }
    }
}

@MainActor
protocol NotificationSystemDriver {
    func permission() async -> NotificationPermission
    func requestPermission() async throws
    func enqueue(identifier: String, title: String, body: String) async throws
}

@MainActor
final class NativeNotificationDriver: NotificationSystemDriver {
    private let center: UNUserNotificationCenter
    init(center: UNUserNotificationCenter) { self.center = center }
    static func map(_ status: UNAuthorizationStatus) -> NotificationPermission {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        @unknown default: .unknown
        }
    }
    func permission() async -> NotificationPermission {
        Self.map(await center.notificationSettings().authorizationStatus)
    }
    func requestPermission() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
    }
    func enqueue(identifier: String, title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }
}

@MainActor
final class SystemNotificationBridge: NotificationBridge {
    private let driver: any NotificationSystemDriver
    private var requesting = false
    private var pendingIDs: Set<String> = []
    private var acceptedIDs: Set<String> = []
    init(driver: any NotificationSystemDriver) { self.driver = driver }
    func authorization() async -> NotificationAuthorization { await driver.permission().contract }
    func requestAuthorization() async -> ServiceOutcome<NotificationAuthorization> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard !requesting else { return .failure(.unknownStatus) }
        requesting = true
        defer { requesting = false }
        let current = await driver.permission()
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard current == .notDetermined else { return .success(current.contract) }
        do {
            try await driver.requestPermission()
            // The Boolean completion is not authority; always re-read OS settings.
            let updated = await driver.permission()
            return Task.isCancelled ? .failure(.cancelled) : .success(updated.contract)
        } catch { return .failure(Task.isCancelled ? .cancelled : .unknownStatus) }
    }
    func deliver(identifier: String, title: String, body: String) async -> ServiceOutcome<Bool> {
        await deliver(identifier: identifier, title: title, body: body, isEligible: { true })
    }
    func deliver(identifier: String, title: String, body: String,
                 isEligible: () -> Bool) async -> ServiceOutcome<Bool> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failure(.invalidData) }
        guard !pendingIDs.contains(identifier), !acceptedIDs.contains(identifier) else { return .success(false) }
        pendingIDs.insert(identifier)
        defer { pendingIDs.remove(identifier) }
        guard await driver.permission() == .authorized else { return .failure(.denied) }
        guard !Task.isCancelled else { return .failure(.cancelled) }
        // Permission queries suspend; telemetry and preference intent must still be valid at enqueue.
        guard isEligible() else { return .failure(.invalidData) }
        do {
            try await driver.enqueue(identifier: identifier, title: title, body: body)
            acceptedIDs.insert(identifier)
            // Acceptance is not proof that Focus/settings allowed a visible banner.
            return .success(true)
        } catch { return .failure(Task.isCancelled ? .cancelled : .unknownStatus) }
    }
}

enum PowerNotificationEvent: CaseIterable, Sendable { case fullyCharged, insufficientCharger }
enum NotificationEffect: Equatable, Sendable {
    case preferenceOff, requestPermission, openNotificationSettings, accepted, duplicate
    case failed(ServiceFailure)
}

/// Gate E: callers supply a validated transition/episode ID, not every telemetry sample.
/// No notification result grants helper approval, changes readings, or navigates AppRouter.
@MainActor
final class PowerNotificationEffects {
    private let bridge: any NotificationBridge
    private let preferences: PreferencesStore
    init(bridge: any NotificationBridge, preferences: PreferencesStore) {
        self.bridge = bridge; self.preferences = preferences
    }
    /// Semantic entry point for charger telemetry. Revalidate after authorization suspends.
    func handleInsufficientCharger(store: PowerReadingStore) async -> NotificationEffect {
        let reading = store.statusReading
        let generation = store.generation
        guard reading.hasInsufficientCharger, let threshold = reading.chargerThreshold,
              let message = reading.insufficientChargerMessage else { return .failed(.invalidData) }
        return await handle(.insufficientCharger, episodeID: threshold.episodeID, body: message) {
            store.generation == generation && store.statusReading == reading && store.statusReading.hasInsufficientCharger
        }
    }

    func handle(_ event: PowerNotificationEvent, episodeID: String) async -> NotificationEffect {
        await handle(event, episodeID: episodeID, body: nil, isEligible: { true })
    }

    private func handle(_ event: PowerNotificationEvent, episodeID: String, body: String?,
                        isEligible: () -> Bool) async -> NotificationEffect {
        guard !Task.isCancelled else { return .failed(.cancelled) }
        guard enabled(event) else { return .preferenceOff }
        let authorization = await bridge.authorization()
        guard !Task.isCancelled else { return .failed(.cancelled) }
        // Recheck after suspension: turning a preference off must suppress pending work.
        guard enabled(event) else { return .preferenceOff }
        guard isEligible() else { return .failed(.invalidData) }
        switch authorization {
        case .notDetermined: return .requestPermission
        case .denied: return .openNotificationSettings
        case .authorized: break
        }
        guard !episodeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .failed(.invalidData) }
        let key = event == .fullyCharged ? "fully-charged" : "insufficient-charger"
        let title = event == .fullyCharged ? "Battery fully charged" : "Charger can’t keep up"
        let body = body ?? (event == .fullyCharged ? "Your battery is fully charged." : "Your Mac is using more power than the charger supplies.")
        switch await bridge.deliver(identifier: "watt.\(key).\(episodeID)", title: title, body: body,
                                    isEligible: { self.enabled(event) && isEligible() }) {
        case .success(true): return .accepted
        case .success(false): return .duplicate
        case .failure(let failure): return .failed(failure)
        }
    }
    private func enabled(_ event: PowerNotificationEvent) -> Bool {
        event == .fullyCharged ? preferences.fullyChargedNotification : preferences.chargerNotification
    }
}

enum LoginRegistrationStatus: CaseIterable, Sendable {
    case notRegistered, enabled, requiresApproval, notFound, unknown
}
struct LoginReconciliation: Equatable, Sendable {
    let desiredEnabled: Bool
    let status: LoginRegistrationStatus
    var effectiveEnabled: Bool { status == .enabled }
    var needsSystemSettings: Bool { desiredEnabled && status == .requiresApproval }
    var matchesPreference: Bool { desiredEnabled ? status == .enabled : status == .notRegistered }
}
@MainActor
protocol LoginRegistrationDriver {
    var status: LoginRegistrationStatus { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class NativeLoginRegistrationDriver: LoginRegistrationDriver {
    private let service: SMAppService
    init(service: SMAppService) { self.service = service }
    static func map(_ status: SMAppService.Status) -> LoginRegistrationStatus {
        switch status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .unknown
        }
    }
    var status: LoginRegistrationStatus { Self.map(service.status) }
    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
}

@MainActor
final class SystemLoginItemService: LoginItemService {
    private let driver: any LoginRegistrationDriver
    // An ambiguous effect is never blindly replayed within this adapter lifetime.
    private var unresolvedTarget: Bool?
    init(driver: any LoginRegistrationDriver) { self.driver = driver }
    func reconcile(desiredEnabled: Bool) -> LoginReconciliation {
        LoginReconciliation(desiredEnabled: desiredEnabled, status: driver.status)
    }
    func effectiveEnabled() async -> ServiceOutcome<Bool> {
        switch driver.status {
        case .enabled: .success(true)
        case .notRegistered, .requiresApproval: .success(false)
        case .notFound, .unknown: .failure(.unknownStatus)
        }
    }
    func setEnabled(_ enabled: Bool) async -> ServiceOutcome<Bool> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let before = driver.status
        guard before != .unknown, before != .notFound else { return .failure(.unknownStatus) }
        if enabled && before == .enabled { unresolvedTarget = nil; return .success(true) }
        if !enabled && before == .notRegistered { unresolvedTarget = nil; return .success(false) }
        if enabled && before == .requiresApproval { unresolvedTarget = nil; return .success(false) }
        guard unresolvedTarget != enabled else { return .failure(.unknownStatus) }
        unresolvedTarget = enabled
        do {
            if enabled { try driver.register() } else { try driver.unregister() }
        } catch {
            // Even if the driver threw after committing, report failure; reconciliation is separate.
            return .failure((error as? ServiceFailure) ?? .unknownStatus)
        }
        let after = driver.status
        if enabled && (after == .enabled || after == .requiresApproval) {
            unresolvedTarget = nil
            return .success(after == .enabled)
        }
        if !enabled && after == .notRegistered { unresolvedTarget = nil; return .success(false) }
        return .failure(.unknownStatus)
    }
    func remove() async -> ServiceOutcome<Bool> { await setEnabled(false) }
    // Preferences express intent only. This never persists effective OS success.
    func apply(_ preferences: PreferencesStore) async -> ServiceOutcome<Bool> {
        guard preferences.persistenceFailure == nil else { return .failure(.persistence) }
        return await setEnabled(preferences.openAtLogin)
    }
}
