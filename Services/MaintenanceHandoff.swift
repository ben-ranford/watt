import Foundation
import AppKit
import Security
import ServiceManagement
#if SWIFT_PACKAGE
import WattMaintenanceShared
import WattHelperShared
#endif

private struct RemovalInputs: Sendable {
    var identityDirectory: URL
    var record: ProtectedHelperRecord?
    var helperAbsent: Bool
}

private enum RemovalLaunchRoute: Sendable { case protectedGeneration, certificate, ordinary }

private struct RemovalSnapshot: Sendable {
    var installationID: UUID
    var generation: UInt64
    var companion: URL
    var hash: Data
    var protected: Bool
    var route: RemovalLaunchRoute
}

/// File work for uninstall identity. Not actor-isolated, so launch can run it off the main thread.
/// The writer lock is the same `LOCK_EX | LOCK_NB` lock the journal uses, and it is released
/// before this function returns. Signature checks are the production `SecStaticCode` checks.
private enum RemovalFiles {
    static func prepare(application: URL, certificateMode: Bool, signingTeam: String?, helperConnected: Bool,
                        inputs: RemovalInputs) throws -> RemovalSnapshot {
        if LaunchPathPolicy.isPrivacyProtected(application) { throw ServiceFailure.untrustedIdentity }
        let identity = try SecurityUpdateCodeValidator().verify(bundle: application)
        guard identity.identifier == HelperIdentity.appIdentifier, String(identity.build) == HelperIdentity.build else {
            throw ServiceFailure.untrustedIdentity
        }
        let companion = application.appendingPathComponent("Contents/MacOS/WattMaintenance")
        if LaunchPathPolicy.isPrivacyProtected(companion) { throw ServiceFailure.untrustedIdentity }
        let record = inputs.record
        let hashes: [Data]
        let route: RemovalLaunchRoute
        if let record {
            guard record.applicationURL == application else { throw ServiceFailure.untrustedIdentity }
            _ = try ExactCodeIdentity.verify(at: application,
                requirement: ExactCodeIdentity.requirement(hashes: record.appHashes, identifier: identity.identifier))
            hashes = record.maintenanceHashes
            route = .protectedGeneration
        } else if certificateMode {
            guard helperConnected else { throw ServiceFailure.unknownStatus }
            guard let signingTeam else { throw HelperSigningError.missingTeam }
            let policy = try HelperSigningPolicy(team: signingTeam)
            try policy.verifyExecutable(at: application, helper: false)
            _ = try ExactCodeIdentity.verify(at: companion, requirement: "anchor apple generic and identifier \"\(identity.identifier).maintenance\" and certificate leaf[subject.OU] = \"\(policy.team)\"")
            hashes = try ExactCodeIdentity.allHashes(at: companion, identifier: identity.identifier + ".maintenance")
            route = .certificate
        } else {
            guard inputs.helperAbsent else { throw ServiceFailure.unknownStatus }
            hashes = try ExactCodeIdentity.allHashes(at: companion, identifier: identity.identifier + ".maintenance")
            route = .ordinary
        }
        let hash = try ExactCodeIdentity.verify(at: companion,
            requirement: ExactCodeIdentity.requirement(hashes: hashes, identifier: identity.identifier + ".maintenance"))
        let installationID: UUID
        if let record { installationID = record.installationID }
        else { installationID = try loadOrCreateInstallationID(directory: inputs.identityDirectory) }
        return RemovalSnapshot(installationID: installationID, generation: record?.generation ?? 1, companion: companion,
                               hash: hash, protected: record != nil, route: route)
    }

    private static func loadOrCreateInstallationID(directory: URL) throws -> UUID {
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let lock = try HeldLock.acquire(directory: directory)
        defer { lock.release() }
        if let saved = try lock.read(key: "installation.v1", maximumBytes: 1024 * 1024) {
            return try JSONDecoder().decode(UUID.self, from: saved)
        }
        let installationID = UUID()
        try lock.write(JSONEncoder().encode(installationID), key: "installation.v1", maximumBytes: 1024 * 1024)
        return installationID
    }
}

/// The app can authenticate its fixed bundled companion independently of persisted receipts.
/// Protected mutation remains an administrator requirement; this handshake grants no effects.
@MainActor
final class MaintenanceHandoff {
    private let executable: URL
    private let expectedHash: Data
    private let installationID: UUID
    private let generation: UInt64
    private var active: (request: MaintenanceRequest, plan: MaintenanceRemovalPlan,
                         parent: MaintenanceProcessWitness.LiveObservation, worker: Process)?

    init(executable: URL, expectedCodeHash: Data, installationID: UUID, generation: UInt64) throws {
        guard executable.isFileURL, expectedCodeHash.count == 20, generation > 0,
              executable.lastPathComponent == "WattMaintenance",
              executable.resolvingSymlinksInPath() == executable.standardizedFileURL else {
            throw ServiceFailure.untrustedIdentity
        }
        self.executable = executable; self.expectedHash = expectedCodeHash
        self.installationID = installationID; self.generation = generation
    }

    func submit(_ request: MaintenanceRequest) async -> MaintenanceProgress {
        do {
            try request.validate()
            guard request.installationID == installationID, request.generation == generation,
                  request.parent == (try MaintenanceProcessWitness.observe(pid: ProcessInfo.processInfo.processIdentifier)) else {
                throw ServiceFailure.untrustedIdentity
            }
            // Until administrator authorization completes, neither parent exit nor placement
            // is requested. Returning accepted here would falsely transfer transaction ownership.
            return .adminRequired(request.receipt)
        } catch { return .interrupted(request.receipt, "untrustedIdentity") }
    }

    /// The caller releases its existing AtomicMaintenanceStorage only after authenticated ready.
    func submitUninstall(_ request: MaintenanceRequest, plan: MaintenanceRemovalPlan,
                         releaseOwnership: () -> Void) async -> MaintenanceProgress {
        do {
            guard active == nil, request.installationID == installationID,
                  request.generation == generation,
                  request.parent.pid == ProcessInfo.processInfo.processIdentifier else { throw ServiceFailure.untrustedIdentity }
            try plan.validateLiveParent(request)
            let parent = try MaintenanceProcessWitness.observeLive(pid: request.parent.pid)
            let (process, input, output) = try launch(request)
            do {
                try MaintenanceChannel.write(plan.encoded(), to: input.fileHandleForWriting.fileDescriptor)
                let ready = try MaintenanceRequest.decode(MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor))
                guard ready == request else { throw ServiceFailure.untrustedIdentity }
                releaseOwnership()
                try MaintenanceChannel.write(Data("release".utf8), to: input.fileHandleForWriting.fileDescriptor)
                guard try MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor) == Data("accepted".utf8) else {
                    throw ServiceFailure.interruptedRemoval
                }
                let record = try MaintenanceRemovalSession.read(directory: MaintenanceRemovalSession.directory(installationID: installationID))
                guard record.request == request, record.plan == plan, record.phase == .accepted else { throw ServiceFailure.untrustedIdentity }
                active = (request, plan, parent, process)
                try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close()
                return .handoffAccepted(request.receipt)
            } catch {
                if process.isRunning { process.terminate() }
                throw error
            }
        } catch { return .interrupted(request.receipt, "interruptedRemoval") }
    }

    func inspect(_ receipt: MaintenanceReceipt) async -> MaintenanceProgress {
        do {
            guard let active, active.request.receipt == receipt else { throw ServiceFailure.unknownStatus }
            let record = try MaintenanceRemovalSession.read(directory: MaintenanceRemovalSession.directory(installationID: installationID))
            guard record.request == active.request, record.plan == active.plan else { throw ServiceFailure.untrustedIdentity }
            if record.phase == .completed, try active.parent.hasExited(), try active.plan.isAbsent() { return .completed(receipt) }
            if record.phase == .accepted, active.worker.isRunning { return .handoffAccepted(receipt) }
            return .interrupted(receipt, "interruptedRemoval")
        } catch { return .interrupted(receipt, "unknownStatus") }
    }

    /// Tests and diagnostic preflight may invoke the fixed executable without installation effects.
    func authenticateCompanion(for request: MaintenanceRequest) throws {
        try request.validate()
        guard request.installationID == installationID, request.generation == generation,
              request.parent == (try MaintenanceProcessWitness.observe(pid: ProcessInfo.processInfo.processIdentifier)) else {
            throw ServiceFailure.untrustedIdentity
        }
        let (process, input, output) = try launch(request)
        defer {
            try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close()
            if process.isRunning { process.terminate() }
        }
        let reply = try MaintenanceRequest.decode(MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor))
        guard reply == request else { throw ServiceFailure.untrustedIdentity }
    }

    private func launch(_ request: MaintenanceRequest) throws -> (Process, Pipe, Pipe) {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executable as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else { throw ServiceFailure.untrustedIdentity }
        var signing: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signing) == errSecSuccess,
              (signing as? [String: Any])?[kSecCodeInfoUnique as String] as? Data == expectedHash else {
            throw ServiceFailure.untrustedIdentity
        }
        let process = Process(); let input = Pipe(); let output = Pipe()
        process.executableURL = executable; process.arguments = []
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        do {
            let worker = try MaintenanceProcessWitness.observe(pid: process.processIdentifier)
            guard worker.uid == request.parent.uid, worker.codeDirectoryHash == expectedHash else { throw ServiceFailure.untrustedIdentity }
            try MaintenanceChannel.write(JSONEncoder().encode(request), to: input.fileHandleForWriting.fileDescriptor)
            return (process, input, output)
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
    }
}

@MainActor
final class ProductionRemovalComposition: UninstallCoordinator {
    private let installationID: UUID
    private let generation: UInt64
    private let helper: (any HelperService)?
    private let helperAbsent: (@MainActor () throws -> Bool)?
    private let protectedInstallation: Bool
    private let executable: URL
    private let companionHash: Data
    private var handoff: MaintenanceHandoff?
    private var busy = false

    /// Values come from the validated running bundle or protected installation record,
    /// independently of update endpoints and release keys.
    init(installationID: UUID, generation: UInt64, helper: (any HelperService)?,
         protectedInstallation: Bool, companion: URL, companionHash: Data,
         helperAbsent: (@MainActor () throws -> Bool)? = nil) throws {
        guard generation > 0, companionHash.count == 20,
              protectedInstallation || helper != nil || helperAbsent != nil else { throw ServiceFailure.invalidData }
        self.installationID = installationID; self.generation = generation; self.helper = helper
        self.helperAbsent = helperAbsent
        self.protectedInstallation = protectedInstallation; executable = companion; self.companionHash = companionHash
    }

    /// Explicit fixture roots/witnesses; ordinary composition always uses the fixed production defaults.
    struct Environment {
        let identityDirectory: URL
        let protectedRecord: @MainActor (URL) throws -> ProtectedHelperRecord?
        let helperAbsent: @MainActor () throws -> Bool
    }
    enum Route: Equatable { case protectedGeneration, certificate, ordinary }
    private(set) var route: Route = .ordinary

    static func administratorArguments(installationID: UUID, generation: UInt64, request: URL) -> [String] {
        ["--uninstall", "--installation", installationID.uuidString, "--generation", String(generation), "--request", request.path]
    }

    static func configured(bundle: Bundle = .main, helper: (any HelperService)?,
                           environment fixture: Environment? = nil) throws -> ProductionRemovalComposition {
        let application = bundle.bundleURL
        if LaunchPathPolicy.isPrivacyProtected(application) { throw ServiceFailure.untrustedIdentity }
        let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Watt")
        let environment = fixture ?? Environment(identityDirectory: support.appendingPathComponent("uninstall-identity"),
            protectedRecord: { try MaintenanceRemovalPlan.readProtectedRecord(application: $0) },
            helperAbsent: { try MaintenanceRemovalPlan.fixedHelperAbsent() })
        let certificateMode = bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String == "certificate"
        let record = try environment.protectedRecord(application)
        let absent = record == nil && !certificateMode ? try environment.helperAbsent() : true
        let snapshot = try RemovalFiles.prepare(application: application,
            certificateMode: certificateMode,
            signingTeam: bundle.object(forInfoDictionaryKey: "WATTSigningTeam") as? String,
            helperConnected: helper != nil,
            inputs: RemovalInputs(identityDirectory: environment.identityDirectory, record: record, helperAbsent: absent))
        return try assemble(snapshot, helper: helper, helperAbsent: environment.helperAbsent)
    }

    /// Launch path. Bundle signature checks and the uninstall-identity lock run off the main thread.
    static func configuredOffMain(bundle: Bundle = .main, helper: (any HelperService)?) async throws -> ProductionRemovalComposition {
        let application = bundle.bundleURL
        if LaunchPathPolicy.isPrivacyProtected(application) { throw ServiceFailure.untrustedIdentity }
        let certificateMode = bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String == "certificate"
        let signingTeam = bundle.object(forInfoDictionaryKey: "WATTSigningTeam") as? String
        let helperConnected = helper != nil
        let snapshot = try await LaunchFileAccess.require {
            let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Watt")
            let record = try MaintenanceRemovalPlan.readProtectedRecord(application: application)
            let absent = record == nil && !certificateMode ? try MaintenanceRemovalPlan.fixedHelperAbsent() : true
            return try RemovalFiles.prepare(application: application, certificateMode: certificateMode, signingTeam: signingTeam,
                helperConnected: helperConnected,
                inputs: RemovalInputs(identityDirectory: support.appendingPathComponent("uninstall-identity"),
                                      record: record, helperAbsent: absent))
        }
        return try assemble(snapshot, helper: helper, helperAbsent: { try MaintenanceRemovalPlan.fixedHelperAbsent() })
    }

    private static func assemble(_ snapshot: RemovalSnapshot, helper: (any HelperService)?,
                                 helperAbsent: @escaping @MainActor () throws -> Bool) throws -> ProductionRemovalComposition {
        let route: Route
        switch snapshot.route {
        case .protectedGeneration: route = .protectedGeneration
        case .certificate: route = .certificate
        case .ordinary: route = .ordinary
        }
        let result = try ProductionRemovalComposition(installationID: snapshot.installationID, generation: snapshot.generation,
            helper: helper, protectedInstallation: snapshot.protected, companion: snapshot.companion, companionHash: snapshot.hash,
            helperAbsent: helperAbsent)
        result.route = route
        return result
    }

    func removeOwnedResources(receipt: OperationReceipt) async -> RemovalOutcome {
        guard !busy else { return .interrupted(receipt) }
        busy = true; defer { busy = false }
        do {
            // A nonresponsive helper is unknown, never absence proof.
            if !protectedInstallation, let helper {
                switch await helper.reconcile(receipt: receipt) {
                case .absent: break
                case .connected:
                    guard case .verifiedAbsent = await helper.remove(receipt: receipt) else { return .interrupted(receipt) }
                case .failed(let failure): return .failed(failure)
                default: return .failed(.unknownStatus)
                }
            } else if !protectedInstallation {
                guard try helperAbsent?() == true else { return .failed(.unknownStatus) }
            }
            let parent = try MaintenanceProcessWitness.observe(pid: ProcessInfo.processInfo.processIdentifier)
            let plan = try MaintenanceRemovalPlan.enroll(installationID: installationID, generation: generation, parent: parent)
            let request = try MaintenanceRequest(receipt: receipt, installationID: installationID,
                generation: generation, operation: .uninstall, parent: parent, removalPlanSHA256: plan.digest)
            let storage = try AtomicMaintenanceStorage(directory: MaintenanceRemovalSession.directory(installationID: installationID))
            try storage.write(JSONEncoder().encode(request), key: "uninstall-handoff.v1")
            if let binding = try plan.administratorBinding(receipt: receipt) {
                try storage.write(JSONEncoder().encode(binding), key: "administrator-request.json")
                func quote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
                let directory = try MaintenanceRemovalSession.directory(installationID: installationID)
                let installer = URL(fileURLWithPath: plan.applicationPath).appendingPathComponent("Contents/MacOS/WattHelperInstaller")
                let command = (["sudo", installer.path] + Self.administratorArguments(installationID: plan.installationID,
                    generation: plan.generation, request: directory.appendingPathComponent("administrator-request.json")))
                    .map(quote).joined(separator: " ") + "\n"
                try storage.write(Data(command.utf8), key: "administrator-command.txt")
                // A durable, byte-identical user-owned companion survives removal of the protected
                // bundle and supplies the explicitly invoked recovery entry point.
                let savedCompanion = directory.appendingPathComponent("WattMaintenance")
                if !FileManager.default.fileExists(atPath: savedCompanion.path) {
                    try FileManager.default.copyItem(at: executable, to: savedCompanion)
                }
                _ = try ExactCodeIdentity.verify(at: savedCompanion,
                    requirement: ExactCodeIdentity.requirement(hashes: [companionHash], identifier: HelperIdentity.appIdentifier + ".maintenance"))
                let directoryFD = try BoundedUSTAR.openDirectory(directory)
                defer { Darwin.close(directoryFD) }
                let executableFD = openat(directoryFD, "WattMaintenance", O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
                guard executableFD >= 0 else { throw ServiceFailure.persistence }
                defer { Darwin.close(executableFD) }
                guard fsync(executableFD) == 0, fsync(directoryFD) == 0 else { throw ServiceFailure.persistence }
                NSWorkspace.shared.open(directory)
            }
            let login = SMAppService.mainApp
            try storage.write(JSONEncoder().encode(login.status.rawValue), key: "uninstall-login-intent.v1")
            if login.status != .notRegistered { try await login.unregister() }
            guard login.status == .notRegistered else { return .failed(.unknownStatus) }
            let continuation = try MaintenanceHandoff(executable: executable, expectedCodeHash: companionHash,
                installationID: installationID, generation: generation)
            handoff = continuation
            switch await continuation.submitUninstall(request, plan: plan, releaseOwnership: { storage.close() }) {
            case .handoffAccepted: return .handoffAccepted(receipt)
            case .adminRequired: return .adminRequired(receipt)
            case .completed: return .failed(.unknownStatus) // caller is still alive
            case .interrupted: return .interrupted(receipt)
            }
        } catch { return .failed((error as? ServiceFailure) ?? .interruptedRemoval) }
    }

    func reconcile(receipt: OperationReceipt) async -> RemovalOutcome {
        guard let handoff else { return protectedInstallation ? .adminRequired(receipt) : .interrupted(receipt) }
        switch await handoff.inspect(receipt) {
        case .adminRequired: return .adminRequired(receipt)
        case .handoffAccepted: return .handoffAccepted(receipt)
        case .completed: return .verifiedAbsent
        case .interrupted: return .interrupted(receipt)
        }
    }
}
