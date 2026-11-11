import Foundation
import ServiceManagement
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Journals operation intent before ServiceManagement effects. A missing registration is
/// not enough to discard an interrupted unregister: process cessation needs separate proof.
struct HelperLifecycleJournal: Codable, Equatable {
    enum Action: String, Codable { case register, update, remove }
    enum Phase: String, Codable { case intent, unregistering, unregisterFailed, unregistered, registering, registerFailed, complete }
    let receipt: OperationReceipt
    let action: Action
    let targetBuild: String
    var phase: Phase
}

@MainActor
protocol HelperRegistrationSystem {
    var registrationStatus: SMAppService.Status { get }
    var unregisterInFlight: Bool { get }
    func register() throws
    func unregister() async throws
}

@MainActor
final class NativeHelperRegistrationSystem: HelperRegistrationSystem {
    private let service = SMAppService.daemon(plistName: HelperIdentity.daemonPlist)
    private(set) var unregisterInFlight = false
    var registrationStatus: SMAppService.Status { service.status }
    func register() throws {
        guard !unregisterInFlight else { throw ServiceFailure.unknownStatus }
        try service.register()
    }
    func unregister() async throws {
        guard !unregisterInFlight else { throw ServiceFailure.unknownStatus }
        unregisterInFlight = true
        let completion = UnregisterCompletion()
        try await withCheckedThrowingContinuation { continuation in
            completion.continuation = continuation
            Task { @MainActor in
                do {
                    try await service.unregister()
                    unregisterInFlight = false
                    completion.finish(.success(()))
                } catch {
                    unregisterInFlight = false
                    completion.finish(.failure(error))
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                completion.finish(.failure(ServiceFailure.timedOut))
            }
        }
    }
    private final class UnregisterCompletion {
        var continuation: CheckedContinuation<Void, Error>?
        func finish(_ result: Result<Void, Error>) {
            let pending = continuation; continuation = nil
            pending?.resume(with: result)
        }
    }
}

@MainActor
final class ProductionHelperLifecycle: HelperLifecycleDriver {
    var supportsOwnedOfflineUpdate: Bool { true }
    private let system: any HelperRegistrationSystem
    private let journalURL: URL
    private let candidate: () throws -> HelperPeer
    private let installedBuild: () async throws -> String?
    private let processesAbsent: () async throws -> Bool
    private let targetBuild: String
    private(set) var journal: HelperLifecycleJournal?

    init(system: any HelperRegistrationSystem, journalURL: URL, targetBuild: String,
         candidate: @escaping () throws -> HelperPeer,
         installedBuild: @escaping () async throws -> String?,
         processesAbsent: @escaping () async throws -> Bool,
         journalData: Data? = nil, journalAlreadyRead: Bool = false) throws {
        self.system = system; self.journalURL = journalURL; self.targetBuild = targetBuild
        self.candidate = candidate; self.installedBuild = installedBuild; self.processesAbsent = processesAbsent
        if journalAlreadyRead {
            if let journalData {
                journal = try JSONDecoder().decode(HelperLifecycleJournal.self, from: journalData)
            }
        } else if FileManager.default.fileExists(atPath: journalURL.path) {
            journal = try JSONDecoder().decode(HelperLifecycleJournal.self, from: Data(contentsOf: journalURL))
        }
    }

    static func map(_ status: SMAppService.Status) throws -> HelperRegistrationStatus {
        switch status {
        case .notRegistered: return .absent
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: throw ServiceFailure.invalidData
        @unknown default: return .unknown
        }
    }

    func removalReceipt() -> OperationReceipt {
        if let journal, journal.action == .remove, journal.phase != .complete { return journal.receipt }
        return OperationReceipt(createdAt: Date())
    }

    func updateReceipt() -> OperationReceipt {
        if let journal, journal.action == .update, journal.phase != .complete { return journal.receipt }
        return OperationReceipt(createdAt: Date())
    }

    func status() async throws -> HelperRegistrationStatus {
        guard !system.unregisterInFlight else { return .unknown }
        let status = try Self.map(system.registrationStatus)
        if case .absent = status {
            // Every absence claim includes process cessation, even without a journal.
            guard try await processesAbsent() else { return .unknown }
            if var value = journal, value.action == .register,
               value.phase == .registering || value.phase == .intent {
                value.phase = .registerFailed; try save(value)
            }
            if var value = journal, value.phase == .unregistering || value.phase == .unregistered {
                value.phase = value.action == .remove ? .complete : .unregistered
                try save(value)
            }
        }
        return status
    }

    func verifyCandidate() throws -> HelperPeer { try candidate() }

    private func save(_ value: HelperLifecycleJournal) throws {
        do {
            try FileManager.default.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: journalURL, options: .atomic)
            journal = value
        } catch { throw ServiceFailure.persistence }
    }

    private func begin(_ receipt: OperationReceipt, action: HelperLifecycleJournal.Action) throws -> HelperLifecycleJournal {
        if let prior = journal, prior.receipt.id == receipt.id {
            guard prior.receipt == receipt, prior.action == action, prior.targetBuild == targetBuild else { throw ServiceFailure.invalidData }
            return prior
        }
        if let prior = journal, prior.phase != .complete && prior.phase != .registerFailed && prior.phase != .unregisterFailed {
            guard action == .remove, prior.phase != .unregistering else { throw ServiceFailure.unknownStatus }
        }
        let value = HelperLifecycleJournal(receipt: receipt, action: action, targetBuild: targetBuild, phase: .intent)
        try save(value)
        return value
    }

    func register(receipt: OperationReceipt) async throws {
        guard !system.unregisterInFlight else { throw ServiceFailure.unknownStatus }
        _ = try verifyCandidate()
        var value = try begin(receipt, action: .register)
        if value.phase == .complete { return }
        let current = try Self.map(system.registrationStatus)
        if case .absent = current {
            guard try await processesAbsent() else { throw ServiceFailure.unknownStatus }
            value.phase = .registering; try save(value)
            do { try system.register() }
            catch { value.phase = .registerFailed; try save(value); throw error }
        } else if case .unknown = current { throw ServiceFailure.unknownStatus }
        value.phase = .complete; try save(value)
    }

    private func unregister(_ value: inout HelperLifecycleJournal) async throws {
        guard !system.unregisterInFlight else { throw ServiceFailure.unknownStatus }
        if value.phase == .unregistering {
            // Across restart no native call remains in this process; reconcile OS evidence.
            if case .absent = try Self.map(system.registrationStatus) {
                guard try await processesAbsent() else { throw ServiceFailure.interruptedRemoval }
                value.phase = .unregistered; try save(value)
            } else {
                value.phase = .unregisterFailed; try save(value)
            }
        }
        if value.phase == .intent || value.phase == .unregisterFailed {
            if case .absent = try Self.map(system.registrationStatus) {
                guard try await processesAbsent() else { throw ServiceFailure.interruptedRemoval }
                value.phase = .unregistered; try save(value)
            }
        }
        if value.phase == .intent || value.phase == .unregisterFailed {
            value.phase = .unregistering; try save(value)
            do { try await system.unregister() }
            catch {
                if !system.unregisterInFlight { value.phase = .unregisterFailed; try save(value) }
                throw error
            }
            value.phase = .unregistered; try save(value)
        }
        guard value.phase == .unregistered,
              case .absent = try Self.map(system.registrationStatus),
              try await processesAbsent() else { throw ServiceFailure.interruptedRemoval }
    }

    func unregister(receipt: OperationReceipt) async throws {
        guard !system.unregisterInFlight else { throw ServiceFailure.unknownStatus }
        _ = try verifyCandidate()
        var value = try begin(receipt, action: .remove)
        if value.phase == .complete {
            guard case .absent = try await status() else { throw ServiceFailure.interruptedRemoval }
            return
        }
        try await unregister(&value)
        value.phase = .complete; try save(value)
    }

    func update(receipt: OperationReceipt) async throws {
        guard !system.unregisterInFlight else { throw ServiceFailure.unknownStatus }
        _ = try verifyCandidate()
        var value = try begin(receipt, action: .update)
        if value.phase == .complete { return }
        if value.phase != .registering && value.phase != .registerFailed {
            try await unregister(&value)
            value.phase = .registering; try save(value)
        }
        if case .absent = try Self.map(system.registrationStatus) {
            guard try await processesAbsent() else { throw ServiceFailure.interruptedUpdate }
            value.phase = .registering; try save(value)
            do { try system.register() }
            catch { value.phase = .registerFailed; try save(value); throw error }
        }
        guard try await installedBuild() == targetBuild else { throw ServiceFailure.interruptedUpdate }
        value.phase = .complete; try save(value)
    }

    func updateApplied(receipt: OperationReceipt) async throws -> Bool {
        guard let journal, journal.receipt == receipt, journal.action == .update,
              journal.phase == .complete, journal.targetBuild == targetBuild else { return false }
        return try await installedBuild() == targetBuild
    }
}

struct HelperLaunchFiles: Sendable {
    let peer: HelperPeer
    let protectedRecord: ProtectedHelperRecord?
    let team: String?
    let journalURL: URL?
    let journalData: Data?
}

@MainActor
struct ProductionHelperComposition {
    let service: HelperLifecycleAdapter
    let transport: ProductionHelperIPC
    let removalReceipt: () -> OperationReceipt
    let updateReceipt: () -> OperationReceipt
    let hasPendingUpdate: () -> Bool

    static func configured(bundle: Bundle = .main) throws -> Self {
        try make(try readLaunchFiles(bundle: bundle), bundle: bundle)
    }

    /// Launch path. File reads, code-signature checks and the helper journal run off the main thread.
    static func configuredOffMain(bundle: Bundle = .main) async throws -> Self {
        if LaunchPathPolicy.isPrivacyProtected(bundle.bundleURL) { throw ServiceFailure.untrustedIdentity }
        let bundleURL = bundle.bundleURL
        let executable = bundle.executableURL
        let trustMode = bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String
        let team = bundle.object(forInfoDictionaryKey: "WATTSigningTeam") as? String
        let files = try await LaunchFileAccess.require {
            try readLaunchFiles(bundleURL: bundleURL, executable: executable, trustMode: trustMode, team: team)
        }
        return try make(files, bundle: bundle)
    }

    nonisolated private static func readLaunchFiles(bundle: Bundle) throws -> HelperLaunchFiles {
        try readLaunchFiles(bundleURL: bundle.bundleURL, executable: bundle.executableURL,
                            trustMode: bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String,
                            team: bundle.object(forInfoDictionaryKey: "WATTSigningTeam") as? String)
    }

    nonisolated private static func readLaunchFiles(bundleURL: URL, executable: URL?, trustMode: String?, team: String?) throws -> HelperLaunchFiles {
        if LaunchPathPolicy.isPrivacyProtected(bundleURL) { throw ServiceFailure.untrustedIdentity }
        if trustMode == "certificate" {
            guard let team else { throw HelperSigningError.missingTeam }
            let policy = try HelperSigningPolicy(team: team)
            let helper = bundleURL.appendingPathComponent("Contents/MacOS/" + HelperIdentity.executableName)
            let plist = bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/" + HelperIdentity.daemonPlist)
            let peer = try certificatePeer(policy: policy, executable: executable, helper: helper, plist: plist)
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            let journalURL = directory.appendingPathComponent("Watt/helper-lifecycle.json")
            let journalData = FileManager.default.fileExists(atPath: journalURL.path) ? try Data(contentsOf: journalURL) : nil
            return HelperLaunchFiles(peer: peer, protectedRecord: nil, team: policy.team, journalURL: journalURL, journalData: journalData)
        }
        let record = try ProtectedHelperRecord.read()
        let trust = HelperTrustPolicy.protectedInstallation(record)
        let peer = try protectedPeer(record: record, trust: trust, executable: executable)
        return HelperLaunchFiles(peer: peer, protectedRecord: record, team: nil, journalURL: nil, journalData: nil)
    }

    nonisolated private static func protectedPeer(record: ProtectedHelperRecord, trust: HelperTrustPolicy, executable: URL?) throws -> HelperPeer {
        let protectedFile = try ProtectedHelperRecord.openProtectedFile(at: ProtectedHelperRecord.helperURL)
        close(protectedFile)
        guard try ProtectedHelperRecord.read(expectedInstallationID: record.installationID) == record,
              let executable,
              let hash = try trust.verifyExecutable(at: ProtectedHelperRecord.helperURL, helper: true) else {
            throw ServiceFailure.untrustedIdentity
        }
        if LaunchPathPolicy.isPrivacyProtected(executable) { throw ServiceFailure.untrustedIdentity }
        _ = try trust.verifyExecutable(at: executable, helper: false)
        return HelperPeer(identifier: HelperIdentity.helperIdentifier,
                          identity: .protectedCodeHash(installationID: record.installationID,
                                                      generation: record.generation, cdhash: hash), protocolVersion: 1)
    }

    nonisolated private static func certificatePeer(policy: HelperSigningPolicy, executable: URL?, helper: URL, plist: URL) throws -> HelperPeer {
        guard let executable,
              helper.resolvingSymlinksInPath() == helper,
              plist.resolvingSymlinksInPath() == plist else { throw ServiceFailure.untrustedIdentity }
        if LaunchPathPolicy.isPrivacyProtected(executable) || LaunchPathPolicy.isPrivacyProtected(helper)
            || LaunchPathPolicy.isPrivacyProtected(plist) { throw ServiceFailure.untrustedIdentity }
        try policy.verifyExecutable(at: executable, helper: false)
        try policy.verifyExecutable(at: helper, helper: true)
        let object: Any
        do { object = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) }
        catch { throw ServiceFailure.invalidData }
        guard let fields = object as? [String: Any],
              Set(fields.keys) == Set(["Label", "AssociatedBundleIdentifiers", "BundleProgram", "MachServices", "ProcessType", "AbandonProcessGroup"]),
              fields["Label"] as? String == HelperIdentity.helperIdentifier,
              fields["AssociatedBundleIdentifiers"] as? [String] == [HelperIdentity.appIdentifier],
              fields["BundleProgram"] as? String == "Contents/MacOS/" + HelperIdentity.executableName,
              fields["Program"] == nil, fields["ProgramArguments"] == nil,
              fields["ProcessType"] as? String == "Background",
              fields["AbandonProcessGroup"] as? Bool == false,
              fields["MachServices"] as? [String: Bool] == [HelperIdentity.machService: true] else {
            throw ServiceFailure.invalidData
        }
        return HelperPeer(identifier: HelperIdentity.helperIdentifier, team: policy.team, protocolVersion: 1)
    }

    private static func make(_ files: HelperLaunchFiles, bundle: Bundle) throws -> Self {
        if let record = files.protectedRecord {
            let trust = HelperTrustPolicy.protectedInstallation(record)
            let executable = bundle.executableURL
            let verify: () throws -> HelperPeer = {
                try protectedPeer(record: record, trust: trust, executable: executable)
            }
            let transport = ProductionHelperIPC(trust: trust)
            let driver = ProtectedHelperLifecycle(record: record, candidate: verify)
            return Self(service: HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: files.peer),
                        transport: transport, removalReceipt: { OperationReceipt(createdAt: Date()) },
                        updateReceipt: { OperationReceipt(createdAt: Date()) }, hasPendingUpdate: { false })
        }
        guard let team = files.team, let journalURL = files.journalURL else { throw ServiceFailure.untrustedIdentity }
        let policy = try HelperSigningPolicy(team: team)
        let helper = bundle.bundleURL.appendingPathComponent("Contents/MacOS/" + HelperIdentity.executableName)
        let plist = bundle.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/" + HelperIdentity.daemonPlist)
        let executable = bundle.executableURL
        let verify: () throws -> HelperPeer = {
            try certificatePeer(policy: policy, executable: executable, helper: helper, plist: plist)
        }
        let transport = ProductionHelperIPC(policy: policy)
        let driver = try ProductionHelperLifecycle(system: NativeHelperRegistrationSystem(),
            journalURL: journalURL, targetBuild: HelperIdentity.build,
            candidate: verify, installedBuild: {
                _ = try await transport.connect()
                return transport.daemonBuild
            }, processesAbsent: {
                await Task.detached { HelperProcessInventory.absent(helperPath: helper.path) }.value
            }, journalData: files.journalData, journalAlreadyRead: true)
        return Self(service: HelperLifecycleAdapter(driver: driver, transport: transport, expectedPeer: files.peer), transport: transport,
                    removalReceipt: { driver.removalReceipt() }, updateReceipt: { driver.updateReceipt() },
                    hasPendingUpdate: { driver.journal?.action == .update && driver.journal?.phase != .complete })
    }

    /// A helper installed after launch needs its own composition. Startup still uses one `configured()` result.
    static func adoptInstalled(bundle: Bundle = .main) throws -> Self {
        try configured(bundle: bundle)
    }
}


/// Read-only process inventory after the awaited ServiceManagement removal. No
/// signals or subprocesses are used. An unrelated powermetrics conservatively
/// prevents proof of absence; it is never identified as an owned descendant.
enum HelperProcessInventory {
    static func unrelatedName(_ name: String?, helperPath: String) -> Bool {
        guard let name, !name.isEmpty, !name.contains("/"), !name.contains("\0") else { return false }
        return name != "WattHelper" && name != "powermetrics"
            && name != URL(fileURLWithPath: helperPath).lastPathComponent
    }

    static func terminatedUTF8(_ bytes: [CChar]) -> String? {
        guard let end = bytes.firstIndex(of: 0), end > 0 else { return nil }
        return String(bytes: bytes[..<end].map { UInt8(bitPattern: $0) }, encoding: .utf8)
    }

    static func absent(helperPath: String) -> Bool {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0, estimate < 32_640 else { return false }
        let capacity = Int(estimate) + 128
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { bytes in
            proc_listallpids(bytes.baseAddress, Int32(bytes.count))
        }
        guard count > 0, count < capacity else { return false }
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var bytes = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
            errno = 0
            let length = bytes.withUnsafeMutableBytes {
                proc_pidpath(pid, $0.baseAddress, UInt32($0.count))
            }
            if length <= 0 {
                // Executables removed/replaced on disk can lack a retrievable path
                // while their kernel process name remains available. A pid that
                // exits during the scan is ENOENT on macOS 27, not only ESRCH.
                if errno == ESRCH { continue }
                let pathErrno = errno
                var nameBytes = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
                let nameLength = nameBytes.withUnsafeMutableBytes {
                    proc_name(pid, $0.baseAddress, UInt32($0.count))
                }
                if nameLength <= 0 {
                    if errno == ESRCH || errno == ENOENT || pathErrno == ENOENT { continue }
                    return false
                }
                guard nameLength < nameBytes.count - 1,
                      unrelatedName(terminatedUTF8(nameBytes), helperPath: helperPath) else { return false }
                continue
            }
            guard let path = terminatedUTF8(bytes) else { return false }
            if path == helperPath || path == "/usr/bin/powermetrics" { return false }
        }
        return true
    }
}

/// Conventional launchd installation is owned exclusively by the administrator tool.
/// The application observes it but cannot mutate it through ServiceManagement.
@MainActor
final class ProtectedHelperLifecycle: HelperLifecycleDriver {
    private let record: ProtectedHelperRecord
    private let candidate: () throws -> HelperPeer
    init(record: ProtectedHelperRecord, candidate: @escaping () throws -> HelperPeer) {
        self.record = record; self.candidate = candidate
    }
    func verifyCandidate() throws -> HelperPeer { try candidate() }
    func status() async throws -> HelperRegistrationStatus {
        guard try ProtectedHelperRecord.read(expectedInstallationID: record.installationID) == record else {
            throw ServiceFailure.untrustedIdentity
        }
        _ = try candidate()
        let data = try ProtectedHelperRecord.readProtectedFile(at: ProtectedHelperRecord.plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["Label"] as? String == HelperIdentity.helperIdentifier,
              plist["ProgramArguments"] as? [String] == [ProtectedHelperRecord.helperURL.path],
              plist["MachServices"] as? [String: Bool] == [HelperIdentity.machService: true],
              plist["UserName"] as? String == "root", plist["BundleProgram"] == nil,
              plist["Program"] == nil else { throw ServiceFailure.invalidData }
        // The next adapter step requires a code-authenticated live Mach-service ping;
        // a plist alone never results in HelperState.connected.
        return .enabled
    }
    func register(receipt: OperationReceipt) async throws { throw ServiceFailure.adminRequired }
    func update(receipt: OperationReceipt) async throws { throw ServiceFailure.adminRequired }
    func unregister(receipt: OperationReceipt) async throws { throw ServiceFailure.adminRequired }
    func updateApplied(receipt: OperationReceipt) async throws -> Bool { false }
}
