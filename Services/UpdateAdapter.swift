import CryptoKit
import Foundation

// P04: detached release signature binds identity, build, minimum OS and exact bytes.
struct UpdateManifest: Codable, Equatable, Sendable {
    let identity: String
    let build: UInt64
    let sha256: Data
    let minimumSystemVersion: String
}
struct SignedUpdate: Codable, Equatable, Sendable {
    let payload: Data
    let signature: Data
}
struct UpdateTrust {
    let identity: String
    let currentBuild: UInt64
    let hostSystemVersion: OperatingSystemVersion
    let publicKey: Curve25519.Signing.PublicKey

    func authenticate(_ release: SignedUpdate) throws -> UpdateManifest {
        guard publicKey.isValidSignature(release.signature, for: release.payload) else {
            throw ServiceFailure.untrustedIdentity
        }
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: release.payload)
        guard manifest.identity == identity else { throw ServiceFailure.untrustedIdentity }
        guard manifest.build > 0 else { throw ServiceFailure.incompatibleVersion }
        guard manifest.sha256.count == SHA256.byteCount else { throw ServiceFailure.invalidData }
        return manifest
    }
    // Signed grammar: MAJOR.MINOR[.PATCH], ASCII decimal, no leading zeros,
    // positive major, nonnegative minor/patch, each representable by Int.
    // Kept separate from authentication so recovery/cleanup survives a host downgrade.
    func requireCompatible(_ manifest: UpdateManifest) throws {
        let parts = manifest.minimumSystemVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count) else { throw ServiceFailure.invalidData }
        let values = try parts.map { part -> Int in
            guard !part.isEmpty, part.utf8.allSatisfy({ (48...57).contains($0) }),
                  part.count == 1 || part.first != "0", let value = Int(part) else {
                throw ServiceFailure.invalidData
            }
            return value
        }
        guard values[0] > 0 else { throw ServiceFailure.invalidData }
        let minimum = [values[0], values[1], values.count == 3 ? values[2] : 0]
        let host = [hostSystemVersion.majorVersion, hostSystemVersion.minorVersion, hostSystemVersion.patchVersion]
        guard host[0] > 0, host.allSatisfy({ $0 >= 0 }), !host.lexicographicallyPrecedes(minimum) else {
            throw ServiceFailure.incompatibleVersion
        }
    }
    func authenticate(_ bytes: Data, manifest: UpdateManifest) throws {
        guard Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw ServiceFailure.invalidData }
    }
}

@MainActor
protocol UpdateSource {
    // Production source must enforce authenticated transport, bounds and deadlines.
    func check() async throws -> SignedUpdate?
    func download(_ release: SignedUpdate) async throws -> Data
    func download(_ release: SignedUpdate, progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async throws -> Data
}

extension UpdateSource {
    func download(_ release: SignedUpdate, progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async throws -> Data {
        try await download(release)
    }
}

enum UpdatePlacement { case original, replacement, uncertain }

@MainActor
protocol UpdateInstallationDriver {
    // All operations are receipt-scoped and idempotent; never accept arbitrary external paths.
    // Stage must validate platform code-signing identity/version and actual minimum OS
    // against the manifest in addition to the release digest.
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws
    func preflightReplacement(manifest: UpdateManifest, receipt: OperationReceipt) throws
    // Preserve a verified original backup BEFORE replacement. On error retain recovery evidence.
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement
    func rollback(receipt: OperationReceipt) throws
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws
    // Must authenticate the actual running binary/version/digest AND its exact transaction receipt.
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool
    func discard(receipt: OperationReceipt) throws
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool
}

extension UpdateInstallationDriver {
    func preflightReplacement(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
}

struct UpdateTransaction: Codable, Equatable {
    enum Phase: String, Codable { case downloading, staged, cancelled, discarded, replacing, awaitingRelaunch, completed, rolledBack, protectedHandoff }
    let receipt: OperationReceipt
    let release: SignedUpdate
    var phase: Phase
}

/// Storage must atomically commit a complete journal before returning; failed writes leave old data.
/// A single owner is required. No production storage, endpoint, install path or signing key is defaulted.
@MainActor
final class UpdateAdapter: UpdateService {
    private let source: any UpdateSource
    private let driver: any UpdateInstallationDriver
    private let storage: any PreferenceStorage
    private let trust: UpdateTrust
    private let protectedUpdates: (any ProtectedUpdateCoordinating)?
    private var offer: SignedUpdate?
    private var busy = false
    private var epoch = UUID()
    private var consent: OperationReceipt?
    private let key = "updater.transactions.v1"
    private(set) var state: UpdateState = .idle
    var administratorCommand: String? { protectedUpdates?.administratorCommand }
    var protectedPackageDirectory: URL? { protectedUpdates?.packageDirectory }

    struct PendingProtectedUpdate: Equatable, Sendable {
        let receipt: OperationReceipt
        let version: String
        let handedOff: Bool
    }
    func pendingProtectedUpdates() throws -> [PendingProtectedUpdate] {
        guard protectedUpdates != nil else { return [] }
        return try journal().filter { $0.phase == .staged || $0.phase == .protectedHandoff }.map {
            PendingProtectedUpdate(receipt: $0.receipt, version: String(try trust.authenticate($0.release).build), handedOff: $0.phase == .protectedHandoff)
        }
    }
    /// Restores observation only. Install consent remains absent after every restart.
    func recoverProtectedStartup() async -> [PendingProtectedUpdate] {
        let pending: [PendingProtectedUpdate]
        do { pending = try pendingProtectedUpdates() }
        catch {
            state = .failed(error as? ServiceFailure ?? .persistence, nil)
            return []
        }
        for item in pending {
            _ = await recover(receipt: item.receipt)
        }
        do { return try pendingProtectedUpdates() }
        catch {
            state = .failed(error as? ServiceFailure ?? .persistence, nil)
            // Preserve the last authenticated receipt inventory for retry/diagnostics. A failed
            // rescan cannot establish that the operation disappeared or grant install consent.
            return pending
        }
    }

    init(source: any UpdateSource, driver: any UpdateInstallationDriver,
         storage: any PreferenceStorage, trust: UpdateTrust, protectedUpdates: (any ProtectedUpdateCoordinating)? = nil) {
        self.source = source; self.driver = driver; self.storage = storage; self.trust = trust
        self.protectedUpdates = protectedUpdates
    }

    private func journal() throws -> [UpdateTransaction] {
        do {
            let entries = try storage.read(key: key).map { try JSONDecoder().decode([UpdateTransaction].self, from: $0) } ?? []
            guard Set(entries.map { $0.receipt.id }).count == entries.count,
                  entries.allSatisfy({ $0.receipt.createdAt.timeIntervalSince1970.isFinite }) else {
                throw ServiceFailure.invalidData
            }
            return entries
        } catch let error as ServiceFailure { throw error }
        catch { throw ServiceFailure.persistence }
    }
    private func transaction(_ receipt: OperationReceipt) throws -> UpdateTransaction {
        guard let entry = try journal().first(where: { $0.receipt == receipt }) else { throw ServiceFailure.invalidData }
        _ = try trust.authenticate(entry.release)
        return entry
    }
    private func save(_ entry: UpdateTransaction) throws {
        var entries = try journal()
        if let index = entries.firstIndex(where: { $0.receipt.id == entry.receipt.id }) {
            guard entries[index].receipt == entry.receipt, entries[index].release == entry.release else {
                throw ServiceFailure.invalidData
            }
            entries[index] = entry
        } else { entries.append(entry) }
        do { try storage.write(JSONEncoder().encode(entries), key: key) }
        catch { throw ServiceFailure.persistence }
    }
    private func transition(_ entry: UpdateTransaction, to phase: UpdateTransaction.Phase) throws {
        var next = entry; next.phase = phase; try save(next)
    }
    private func failure<T>(_ error: Error, receipt: OperationReceipt? = nil) -> ServiceOutcome<T> {
        let reason = error as? ServiceFailure ?? (error is CancellationError ? .cancelled : .invalidData)
        if reason == .adminRequired, let receipt { state = .adminRequired(receipt) }
        else { state = .failed(reason, receipt) }
        return .failure(reason)
    }
    private func result(_ next: UpdateState) -> ServiceOutcome<UpdateState> {
        state = next; return .success(next)
    }
    private func requireIdle() throws {
        guard !busy else { throw ServiceFailure.interruptedUpdate }
        try Task.checkCancellation()
    }

    private func verifyNewer(_ manifest: UpdateManifest) throws {
        try trust.requireCompatible(manifest)
        let completed = try journal().filter { $0.phase == .completed }
        let builds = try completed.map { try trust.authenticate($0.release).build }
        guard manifest.build > max(trust.currentBuild, builds.max() ?? 0) else {
            throw ServiceFailure.incompatibleVersion
        }
    }

    func check() async -> ServiceOutcome<String?> {
        do {
            try requireIdle()
            guard try journal().allSatisfy({ [.discarded, .rolledBack, .completed].contains($0.phase) }) else {
                throw ServiceFailure.interruptedUpdate
            }
            busy = true; defer { busy = false }
            offer = nil; state = .checking
            let release = try await source.check()
            try Task.checkCancellation()
            guard let release else { state = .idle; return .success(nil) }
            let manifest = try trust.authenticate(release)
            try verifyNewer(manifest)
            offer = release; state = .available(version: String(manifest.build))
            return .success(String(manifest.build))
        } catch { state = .failed(error as? ServiceFailure ?? .network, nil); return failure(error) }
    }

    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        await download(version: version, receipt: receipt, progress: { _ in })
    }
    func download(version: String, receipt: OperationReceipt,
                  progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        let token = epoch
        do {
            try requireIdle()
            guard let release = offer, receipt.createdAt.timeIntervalSince1970.isFinite else { throw ServiceFailure.invalidData }
            let manifest = try trust.authenticate(release)
            try verifyNewer(manifest)
            guard version == String(manifest.build), try journal().allSatisfy({
                $0.receipt.id != receipt.id && [.discarded, .rolledBack, .completed].contains($0.phase)
            }) else { throw ServiceFailure.invalidData }
            let entry = UpdateTransaction(receipt: receipt, release: release, phase: .downloading)
            try save(entry)
            busy = true; defer { busy = false }
            state = .downloading(progress: 0)
            let bytes = try await source.download(release) { [weak self] value in
                guard let self, token == self.epoch, value.isValid else { return }
                progress(value)
            }
            try Task.checkCancellation()
            guard token == epoch, try transaction(receipt).phase == .downloading else { throw ServiceFailure.cancelled }
            try trust.authenticate(bytes, manifest: manifest)
            try driver.stage(bytes, manifest: manifest, receipt: receipt)
            try driver.verifyStaged(manifest: manifest, receipt: receipt)
            try transition(entry, to: .staged)
            return result(.staged(receipt))
        } catch {
            guard token == epoch else { return .failure(.cancelled) }
            return failure(error, receipt: receipt)
        }
    }

    // Explicit user action; never restored from disk or inferred from automatic-check preferences.
    func confirmInstall(receipt: OperationReceipt) throws {
        do {
            try requireIdle()
            let phase = try transaction(receipt).phase
            guard phase == .staged || (phase == .protectedHandoff && protectedUpdates != nil) else { throw ServiceFailure.invalidData }
            consent = receipt
        } catch {
            state = .failed(error as? ServiceFailure ?? .invalidData, receipt)
            throw error
        }
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        do {
            try requireIdle()
            let entry = try transaction(receipt)
            guard (entry.phase == .staged || (entry.phase == .protectedHandoff && protectedUpdates != nil)), consent == receipt else { throw ServiceFailure.denied }
            let manifest = try trust.authenticate(entry.release)
            try trust.requireCompatible(manifest)
            try driver.verifyStaged(manifest: manifest, receipt: receipt)
            if let protectedUpdates {
                consent = nil
                let next = try await protectedUpdates.install(release: entry.release, manifest: manifest, receipt: receipt) {
                    try self.transition(entry, to: .protectedHandoff)
                }
                return result(next)
            }
            try driver.preflightReplacement(manifest: manifest, receipt: receipt)
            try transition(entry, to: .replacing) // write-ahead: crash cannot become fresh install
            consent = nil; state = .installing(receipt)
            try driver.replace(manifest: manifest, receipt: receipt)
            guard try driver.placement(manifest: manifest, receipt: receipt) == .replacement else {
                throw ServiceFailure.interruptedUpdate
            }
            try transition(entry, to: .awaitingRelaunch)
            return result(.awaitingRelaunch(receipt))
        } catch { return failure(error, receipt: receipt) }
    }
    // Separate explicit relaunch action; recover never starts a process.
    func relaunch(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        do {
            try requireIdle()
            let entry = try transaction(receipt)
            guard entry.phase == .awaitingRelaunch else { throw ServiceFailure.invalidData }
            let manifest = try trust.authenticate(entry.release)
            try trust.requireCompatible(manifest)
            guard try driver.placement(manifest: manifest, receipt: receipt) == .replacement else {
                throw ServiceFailure.untrustedIdentity
            }
            if try !driver.launched(manifest: manifest, receipt: receipt) {
                try driver.launch(manifest: manifest, receipt: receipt)
            }
            return await recover(receipt: receipt)
        } catch { return failure(error, receipt: receipt) }
    }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        do {
            try requireIdle()
            let entry = try transaction(receipt)
            let manifest = try trust.authenticate(entry.release)
            switch entry.phase {
            case .protectedHandoff:
                guard let protectedUpdates else { throw ServiceFailure.interruptedUpdate }
                let next = try protectedUpdates.recover(release: entry.release, manifest: manifest, receipt: receipt)
                if case .completed = next { try transition(entry, to: .completed) }
                return result(next)
            case .replacing, .awaitingRelaunch, .completed:
                switch try driver.placement(manifest: manifest, receipt: receipt) {
                case .replacement:
                    if try driver.launched(manifest: manifest, receipt: receipt) {
                        try transition(entry, to: .completed)
                        return result(.completed(receipt))
                    }
                    try transition(entry, to: .awaitingRelaunch)
                    return result(.awaitingRelaunch(receipt))
                case .original:
                    try transition(entry, to: .rolledBack)
                    return result(.failed(.interruptedUpdate, receipt))
                case .uncertain:
                    try driver.rollback(receipt: receipt)
                    guard try driver.placement(manifest: manifest, receipt: receipt) == .original else {
                        throw ServiceFailure.interruptedUpdate
                    }
                    try transition(entry, to: .rolledBack)
                    return result(.failed(.interruptedUpdate, receipt))
                }
            case .staged:
                try driver.verifyStaged(manifest: manifest, receipt: receipt)
                return result(.staged(receipt))
            case .cancelled: return result(.failed(.cancelled, receipt))
            case .downloading, .rolledBack: return result(.failed(.interruptedUpdate, receipt))
            case .discarded: throw ServiceFailure.invalidData
            }
        } catch { return failure(error, receipt: receipt) }
    }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> {
        do {
            let entry = try transaction(receipt)
            guard [.downloading, .staged, .cancelled].contains(entry.phase) else { throw ServiceFailure.interruptedUpdate }
            epoch = UUID(); consent = nil
            try transition(entry, to: .cancelled)
            return result(.failed(.cancelled, receipt))
        } catch { return failure(error, receipt: receipt) }
    }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> {
        do {
            try requireIdle()
            let entry = try transaction(receipt)
            guard [.downloading, .staged, .cancelled, .discarded].contains(entry.phase) else { throw ServiceFailure.interruptedUpdate }
            // Cancel durably first: failed cleanup must not leave an installable transaction.
            if entry.phase != .discarded { try transition(entry, to: .cancelled) }
            consent = nil
            try driver.discard(receipt: receipt)
            guard try driver.stagingAbsent(receipt: receipt) else { throw ServiceFailure.interruptedUpdate }
            try transition(entry, to: .discarded) // permanent receipt tombstone
            state = .idle
            return .success(receipt)
        } catch { return failure(error, receipt: receipt) }
    }
}
