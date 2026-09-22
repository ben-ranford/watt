import Foundation

/// Explicit installation-owned entries, never presentation-supplied paths or recursive roots.
struct RemovalManifest: Equatable, Codable, Sendable {
    enum Kind: Int, Codable, CaseIterable, Sendable { case login, helper, configuration, application }
    struct Resource: Equatable, Codable, Sendable {
        let path: String
        let kind: Kind
    }
    let installationID: UUID
    let resources: [Resource]

    func validate() throws {
        guard !resources.isEmpty, Set(resources.map(\.path)).count == resources.count else {
            throw ServiceFailure.invalidData
        }
        for resource in resources {
            let path = resource.path
            guard path.hasPrefix("/"), path != "/", !path.contains("\0"),
                  URL(fileURLWithPath: path).standardizedFileURL.path == path else {
                throw ServiceFailure.invalidData
            }
            // Nested roots would authorize accidental recursive removal of another entry.
            guard !resources.contains(where: { $0.path != path && path.hasPrefix($0.path + "/") }) else {
                throw ServiceFailure.invalidData
            }
        }
    }
}

struct RemovalInventory: Equatable, Codable, Sendable {
    let presentPaths: Set<String>
    let helperRunning: Bool
    let appRunning: Bool
}

struct RemovalTransaction: Equatable, Codable, Sendable {
    enum Scope: String, Codable, Sendable { case helper, uninstall }
    enum Phase: String, Codable, Sendable { case removing, rollingBack, rolledBack }
    let receipt: OperationReceipt
    let manifest: RemovalManifest
    let scope: Scope
    let baseline: RemovalInventory
    var phase: Phase
}

struct ScopedRemovalReport: Equatable, Sendable {
    let outcome: RemovalOutcome
    /// Unknown inventory conservatively reports every scoped path.
    let remainingPaths: [String]
    let inventory: RemovalInventory?
    let failedStep: RemovalManifest.Kind?
    let failure: ServiceFailure?
}

@MainActor
protocol OwnedRemovalDriver {
    // Must verify installation ownership, exact objects (no symlink following), registrations,
    // process identity and no pending effects. A directory entry is not recursive authority.
    func inventory(manifest: RemovalManifest) async throws -> RemovalInventory
    // Durable before effects; bind the entire receipt, manifest and scope, not UUID alone.
    func transaction() throws -> RemovalTransaction?
    func save(_ transaction: RemovalTransaction) throws
    // Idempotent by receipt/resource; journal intent before effect and reconcile ambiguous
    // acknowledgement. Helper removal must reauthenticate actual peer at the effect boundary.
    // Application removal must prove process exit, not merely missing bundle bytes.
    func remove(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws
    // Restore only this receipt's removed objects from verified backups, without overwriting
    // intervening/unrelated data or silently granting OS approval. Retain recovery material.
    func restore(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws
}

/// Isolated adapter: intentionally has no default filesystem, ServiceManagement or process driver.
@MainActor
final class ScopedRemovalAdapter: UninstallCoordinator {
    let manifest: RemovalManifest
    private let driver: any OwnedRemovalDriver
    let helper: any HelperService // Shared authenticated P02 service, never a presentation-created replacement.
    private var busy = false
    private(set) var report: ScopedRemovalReport?

    init(manifest: RemovalManifest, driver: any OwnedRemovalDriver, helper: any HelperService) throws {
        try manifest.validate()
        self.manifest = manifest; self.driver = driver; self.helper = helper
    }

    /// The installation manifest is supplied by the trusted installer, not UI paths.
    func hasLeftoverHelper(currentInstallationID: UUID) async throws -> Bool {
        guard !busy, manifest.installationID != currentInstallationID else { return false }
        busy = true; defer { busy = false }
        let value = try await inventory()
        return value.helperRunning || resources(.helper).contains { value.presentPaths.contains($0.path) }
    }

    func reconnect() async -> HelperReconciliation {
        guard !busy else { return .unknown }
        busy = true; defer { busy = false }
        // P02 reconcile authenticates actual peer and correlated handshake on every call.
        return await helper.reconcile(receipt: nil)
    }

    private func resources(_ scope: RemovalTransaction.Scope) -> [RemovalManifest.Resource] {
        manifest.resources.filter { scope == .uninstall || $0.kind == .helper }
            .sorted { ($0.kind.rawValue, $0.path) < ($1.kind.rawValue, $1.path) }
    }

    private func inventory() async throws -> RemovalInventory {
        let value = try await driver.inventory(manifest: manifest)
        guard value.presentPaths.isSubset(of: Set(manifest.resources.map(\.path))) else {
            throw ServiceFailure.invalidData
        }
        return value
    }

    private func absent(_ value: RemovalInventory, scope: RemovalTransaction.Scope) -> Bool {
        Set(resources(scope).map(\.path)).isDisjoint(with: value.presentPaths)
            && !value.helperRunning && (scope == .helper || !value.appRunning)
    }

    @discardableResult
    private func publish(_ outcome: RemovalOutcome, scope: RemovalTransaction.Scope,
                         inventory: RemovalInventory?, step: RemovalManifest.Kind? = nil,
                         failure: ServiceFailure? = nil) -> RemovalOutcome {
        let paths = resources(scope).map(\.path).filter { inventory?.presentPaths.contains($0) ?? true }
        report = ScopedRemovalReport(outcome: outcome, remainingPaths: paths,
                                     inventory: inventory, failedStep: step, failure: failure)
        return outcome
    }

    private func bound(_ receipt: OperationReceipt) throws -> RemovalTransaction? {
        guard let transaction = try driver.transaction() else { return nil }
        guard transaction.receipt == receipt, transaction.manifest == manifest else {
            throw ServiceFailure.invalidData
        }
        return transaction
    }

    func removeOwnedResources(receipt: OperationReceipt) async -> RemovalOutcome {
        await remove(receipt: receipt, scope: .uninstall)
    }

    func removeHelper(receipt: OperationReceipt) async -> RemovalOutcome {
        await remove(receipt: receipt, scope: .helper)
    }

    private func remove(receipt: OperationReceipt, scope: RemovalTransaction.Scope) async -> RemovalOutcome {
        guard !busy else { return .interrupted(receipt) }
        busy = true; defer { busy = false }
        var step: RemovalManifest.Kind?
        do {
            try Task.checkCancellation()
            let before = try await inventory()
            let transaction: RemovalTransaction
            if let prior = try bound(receipt) {
                guard prior.scope == scope, prior.phase == .removing else { throw ServiceFailure.interruptedRemoval }
                transaction = prior
            } else {
                transaction = RemovalTransaction(receipt: receipt, manifest: manifest, scope: scope,
                                                 baseline: before, phase: .removing)
                try driver.save(transaction)
            }
            for resource in resources(scope) {
                try Task.checkCancellation()
                step = resource.kind
                let current = try await inventory()
                let running = resource.kind == .helper ? current.helperRunning
                    : resource.kind == .application && current.appRunning
                guard current.presentPaths.contains(resource.path) || running else { continue }
                if resource.kind == .helper {
                    let authentication = await helper.reconcile(receipt: receipt)
                    guard case .connected = authentication else {
                        if case .failed(let reason) = authentication { throw reason }
                        throw ServiceFailure.untrustedIdentity
                    }
                }
                try await driver.remove(resource, transaction: transaction)
                try Task.checkCancellation()
                let after = try await inventory()
                guard !after.presentPaths.contains(resource.path),
                      resource.kind != .helper || !after.helperRunning,
                      resource.kind != .application || !after.appRunning else {
                    throw ServiceFailure.interruptedRemoval
                }
            }
            let after = try await inventory()
            guard absent(after, scope: scope), scope != .helper || after.appRunning == transaction.baseline.appRunning else {
                throw ServiceFailure.interruptedRemoval
            }
            return publish(.verifiedAbsent, scope: scope, inventory: after)
        } catch {
            let reason = error is CancellationError ? ServiceFailure.cancelled
                : (error as? ServiceFailure) ?? .interruptedRemoval
            return publish(reason == .cancelled ? .cancelled : .failed(reason), scope: scope,
                           inventory: try? await inventory(), step: step, failure: reason)
        }
    }

    func reconcile(receipt: OperationReceipt) async -> RemovalOutcome {
        guard !busy else { return .interrupted(receipt) }
        busy = true; defer { busy = false }
        var scope = RemovalTransaction.Scope.uninstall
        do {
            guard let transaction = try bound(receipt) else { throw ServiceFailure.unknownStatus }
            scope = transaction.scope
            let value = try await inventory()
            let complete = transaction.phase == .removing && absent(value, scope: scope)
                && (scope != .helper || value.appRunning == transaction.baseline.appRunning)
            return publish(complete ? .verifiedAbsent : .interrupted(receipt), scope: scope, inventory: value)
        } catch {
            let reason = (error as? ServiceFailure) ?? .unknownStatus
            return publish(.failed(reason), scope: scope, inventory: nil, failure: reason)
        }
    }

    /// Explicit recovery, never automatic restoration of helper/login approval on removal failure.
    func rollback(receipt: OperationReceipt) async -> ServiceOutcome<RemovalInventory> {
        guard !busy else { return .failure(.interruptedRemoval) }
        busy = true; defer { busy = false }
        var scope = RemovalTransaction.Scope.uninstall
        do {
            guard var transaction = try bound(receipt) else { throw ServiceFailure.unknownStatus }
            scope = transaction.scope
            transaction.phase = .rollingBack
            try driver.save(transaction)
            for resource in resources(scope).reversed() where transaction.baseline.presentPaths.contains(resource.path) {
                try Task.checkCancellation()
                try await driver.restore(resource, transaction: transaction)
            }
            let restored = try await inventory()
            guard restored == transaction.baseline else { throw ServiceFailure.interruptedRemoval }
            transaction.phase = .rolledBack
            try driver.save(transaction)
            publish(.interrupted(receipt), scope: scope, inventory: restored)
            return .success(restored)
        } catch {
            let reason = error is CancellationError ? ServiceFailure.cancelled
                : (error as? ServiceFailure) ?? .interruptedRemoval
            publish(.failed(reason), scope: scope, inventory: try? await inventory(), failure: reason)
            return .failure(reason)
        }
    }
}
