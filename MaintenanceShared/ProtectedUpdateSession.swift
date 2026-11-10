import Foundation
import CryptoKit
import Darwin
import Security
#if SWIFT_PACKAGE
import WattHelperShared
#endif

public struct ProtectedUpdateEnvelope: Codable, Equatable, Sendable {
    public let request: MaintenanceRequest
    public let binding: ProtectedMaintenanceBinding
    public let minimumSystemVersion: String
    public init(request: MaintenanceRequest, binding: ProtectedMaintenanceBinding, minimumSystemVersion: String) throws {
        self.request = request; self.binding = binding; self.minimumSystemVersion = minimumSystemVersion
        try validate()
    }
    public func validate() throws {
        try request.validate(); try binding.validate()
        guard request.operation == .update, binding.operation == .update,
              request.receipt.id == binding.receipt.id, request.receipt.createdAt == binding.receipt.createdAt,
              request.installationID == binding.installationID, request.generation == binding.previousGeneration,
              request.candidateSHA256 == binding.archiveSHA256 else { throw MaintenanceProtocolError.invalidRequest }
        _ = try UpdateLaunchRequest(receipt: request.receipt, identity: HelperIdentity.appIdentifier, build: binding.build,
            minimumSystemVersion: minimumSystemVersion, challenge: Data(repeating: 0, count: 32))
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 32 * 1024 else { throw MaintenanceProtocolError.oversized }
        let value = try JSONDecoder().decode(Self.self, from: data); try value.validate(); return value
    }
}

public enum ProtectedUpdatePackage {
    public static func userDirectory() throws -> URL {
        guard let user = getpwuid(getuid()), let home = user.pointee.pw_dir else { throw MaintenanceProtocolError.invalidRequest }
        return URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Library/Application Support/Watt", isDirectory: true)
    }
    public static func directory(receipt: MaintenanceReceipt) throws -> URL {
        try userDirectory().appendingPathComponent("update-staging", isDirectory: true)
            .appendingPathComponent(receipt.id.uuidString, isDirectory: true).appendingPathComponent("protected-package", isDirectory: true)
    }
    public static func writeFile(_ bytes: Data, named name: String, directory: URL) throws {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else { throw MaintenanceProtocolError.invalidRequest }
        let dir = try privateDirectory(directory); defer { close(dir) }
        let fd = openat(dir, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { close(fd) }
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, raw.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw MaintenanceProtocolError.invalidRequest }; offset += count
            }
        }
        guard fsync(fd) == 0, fsync(dir) == 0 else { throw MaintenanceProtocolError.invalidRequest }
    }
    public static func readFile(_ name: String, directory: URL, limit: Int) throws -> Data {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != "..", limit <= BoundedUSTAR.maximumBytes else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let dir = try privateDirectory(directory); defer { close(dir) }
        let fd = openat(dir, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }; defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFREG,
              info.st_nlink == 1, info.st_mode & 0o077 == 0, info.st_size >= 0, info.st_size <= limit else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0, count <= limit - bytes.count else { throw MaintenanceProtocolError.invalidRequest }
            if count == 0 { break }; bytes.append(contentsOf: buffer.prefix(count))
        }
        guard bytes.count == info.st_size else { throw MaintenanceProtocolError.invalidRequest }; return bytes
    }
    public static func privateDirectory(_ url: URL) throws -> Int32 {
        let fd = try BoundedUSTAR.openDirectory(url)
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            close(fd); throw MaintenanceProtocolError.invalidRequest
        }
        return fd
    }
    public static func validate(_ envelope: ProtectedUpdateEnvelope, at directory: URL) throws {
        try envelope.validate()
        let binding = try ProtectedMaintenanceBinding.decode(readFile("request.json", directory: directory, limit: 16384))
        guard binding == envelope.binding else { throw MaintenanceProtocolError.invalidRequest }
        struct Release: Decodable { let payload: Data; let signature: Data }
        struct Manifest: Decodable { let identity: String; let build: UInt64; let sha256: Data; let minimumSystemVersion: String }
        let release = try JSONDecoder().decode(Release.self, from: readFile("manifest.json", directory: directory, limit: 1024 * 1024))
        let manifest = try JSONDecoder().decode(Manifest.self, from: release.payload)
        let archive = try readFile("release.tar", directory: directory, limit: BoundedUSTAR.maximumBytes)
        guard Data(SHA256.hash(data: release.payload)) == binding.signedPayloadSHA256,
              Data(SHA256.hash(data: archive)) == binding.archiveSHA256, manifest.sha256 == binding.archiveSHA256,
              manifest.identity == HelperIdentity.appIdentifier, manifest.build == binding.build,
              manifest.minimumSystemVersion == envelope.minimumSystemVersion, release.signature.count == 64 else {
            throw MaintenanceProtocolError.invalidRequest
        }
        _ = try BoundedUSTAR(validating: archive)
    }
}

/// Live evidence is retained in this object; serializing its identity never reconstitutes an ACK.
@MainActor
public final class SharedUpdateProcessLauncher {
    private var process: Process?
    private var startupInput: FileHandle?
    private var startupOutput: FileHandle?
    public private(set) var identity: MaintenanceProcessIdentity?
    public private(set) var acknowledgement: UpdateLaunchAcknowledgement?
    public init() {}
    public func launch(application: URL, request: UpdateLaunchRequest, allowedHashes: [Data]) throws {
        try request.validate()
        guard process == nil, !allowedHashes.isEmpty, allowedHashes.count <= 16,
              allowedHashes.allSatisfy({ $0.count == 20 }), let bundle = Bundle(url: application), let executable = bundle.executableURL,
              bundle.bundleIdentifier == request.identity,
              bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String == String(request.build),
              bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String == request.minimumSystemVersion else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let requirement = try ExactCodeIdentity.requirement(hashes: allowedHashes, identifier: request.identity)
        let hash = try ExactCodeIdentity.verify(at: application, requirement: requirement)
        let child = Process(), input = Pipe(), output = Pipe()
        child.executableURL = executable; child.arguments = ["--watt-update-handshake"]
        child.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
        child.standardInput = input; child.standardOutput = output; child.standardError = FileHandle.nullDevice
        try child.run()
        try input.fileHandleForReading.close(); try output.fileHandleForWriting.close()
        var retained = false
        defer { if !retained { try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close() } }
        do {
            let before = try MaintenanceProcessWitness.observe(pid: child.processIdentifier)
            guard before.uid == getuid(), before.codeDirectoryHash == hash else { throw MaintenanceProtocolError.invalidRequest }
            try MaintenanceChannel.write(JSONEncoder().encode(request), to: input.fileHandleForWriting.fileDescriptor)
            let acknowledgement = try UpdateLaunchAcknowledgement.decode(MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor))
            guard acknowledgement.request == request, child.isRunning,
                  try MaintenanceProcessWitness.matches(before),
                  try ExactCodeIdentity.verify(at: application, requirement: requirement) == hash else { throw MaintenanceProtocolError.invalidRequest }
            process = child; identity = before; self.acknowledgement = acknowledgement
            startupInput = input.fileHandleForWriting; startupOutput = output.fileHandleForReading; retained = true
        } catch { if child.isRunning { child.terminate() }; throw error }
    }
    public func isAuthenticated(receipt: MaintenanceReceipt) throws -> Bool {
        guard let process, process.isRunning, let identity, acknowledgement?.request.receipt == receipt else { return false }
        return try MaintenanceProcessWitness.matches(identity)
    }
    public func acceptStartup() throws {
        guard let startupInput, let startupOutput, let acknowledgement,
              try isAuthenticated(receipt: acknowledgement.request.receipt) else { throw MaintenanceProtocolError.invalidRequest }
        defer {
            try? startupInput.close(); try? startupOutput.close()
            self.startupInput = nil; self.startupOutput = nil
        }
        try MaintenanceChannel.write(Data("launch-accepted".utf8), to: startupInput.fileDescriptor)
        guard try MaintenanceChannel.read(from: startupOutput.fileDescriptor, timeout: 5) == Data("startup-confirmed".utf8),
              try isAuthenticated(receipt: acknowledgement.request.receipt) else { throw MaintenanceProtocolError.invalidRequest }
    }
}

/// Owns both pre-existing updater locks before accepting the continuation. No privileged effects.
@MainActor
public final class ProtectedUpdateSession {
    /// Internal fixture boundary; the command-line companion always uses the production initializer.
    struct Environment {
        let directory: URL
        let validate: @MainActor (ProtectedUpdateEnvelope) throws -> Void
        let installed: @MainActor () throws -> ProtectedHelperRecord
        let coherent: @MainActor (ProtectedHelperRecord, ProtectedUpdateEnvelope) throws -> Void
        let application: @MainActor (ProtectedHelperRecord) -> URL
    }
    public struct Record: Codable, Sendable {
        public enum Phase: String, Codable, Sendable { case accepted, awaitingAdministrator, launching, completed, interrupted }
        public let envelope: ProtectedUpdateEnvelope
        public var phase: Phase
        public var replacement: MaintenanceProcessIdentity?
    }
    private var journal: Int32
    private var staging: Int32
    private var locks: [Int32]
    private let parent: MaintenanceProcessWitness.LiveObservation
    private let launcher = SharedUpdateProcessLauncher()
    private let environment: Environment
    public private(set) var record: Record

    public static func validateLive(_ envelope: ProtectedUpdateEnvelope) throws {
        try envelope.validate()
        guard getuid() != 0, envelope.request.parent.uid == getuid(),
              try MaintenanceProcessWitness.matches(envelope.request.parent) else { throw MaintenanceProtocolError.invalidRequest }
        let previousURL = ProtectedHelperRecord.directory.appendingPathComponent("generations")
            .appendingPathComponent("\(envelope.binding.installationID.uuidString)-\(envelope.binding.previousGeneration)")
            .appendingPathComponent("record.json")
        let previous = try ProtectedHelperRecord.read(at: previousURL, expectedInstallationID: envelope.binding.installationID)
        guard previous.generation == envelope.binding.previousGeneration else { throw MaintenanceProtocolError.invalidRequest }
        let own = try MaintenanceProcessWitness.observe(pid: getpid())
        let current = try ProtectedHelperRecord.read(expectedInstallationID: previous.installationID)
        let priorCaller = previous.appHashes.contains(envelope.request.parent.codeDirectoryHash) && previous.maintenanceHashes.contains(own.codeDirectoryHash)
        let recoveryCaller = current.maintenanceBinding == envelope.binding && current.appHashes.contains(envelope.request.parent.codeDirectoryHash)
            && current.maintenanceHashes.contains(own.codeDirectoryHash)
        guard priorCaller || recoveryCaller else { throw MaintenanceProtocolError.invalidRequest }
        try ProtectedUpdatePackage.validate(envelope, at: ProtectedUpdatePackage.directory(receipt: envelope.request.receipt))
    }
    public convenience init(envelope: ProtectedUpdateEnvelope) throws {
        try self.init(envelope: envelope, environment: Environment(directory: ProtectedUpdatePackage.userDirectory(),
            validate: Self.validateLive, installed: { try ProtectedHelperRecord.read(expectedInstallationID: envelope.binding.installationID) },
            coherent: Self.requireCoherent, application: { $0.applicationURL }))
    }
    init(envelope: ProtectedUpdateEnvelope, environment: Environment) throws {
        try environment.validate(envelope)
        self.environment = environment
        parent = try MaintenanceProcessWitness.observeLive(pid: envelope.request.parent.pid)
        let root = environment.directory
        let journal = try ProtectedUpdatePackage.privateDirectory(root.appendingPathComponent("update-journal"))
        var descriptors = [journal], acquired: [Int32] = []
        var staging: Int32 = -1
        do {
            staging = try ProtectedUpdatePackage.privateDirectory(root.appendingPathComponent("update-staging")); descriptors.append(staging)
            for fd in descriptors {
                let lock = openat(fd, ".writer.lock", O_RDWR | O_NOFOLLOW | O_CLOEXEC)
                guard lock >= 0 else { throw MaintenanceProtocolError.invalidRequest }
                acquired.append(lock)
                var info = stat()
                guard fstat(lock, &info) == 0, info.st_uid == getuid(), info.st_mode & S_IFMT == S_IFREG,
                      info.st_nlink == 1, info.st_mode & 0o077 == 0, flock(lock, LOCK_EX | LOCK_NB) == 0 else {
                    throw MaintenanceProtocolError.invalidRequest
                }
            }
            struct JournalRelease: Decodable { let payload: Data; let signature: Data }
            struct JournalEntry: Decodable { let receipt: MaintenanceReceipt; let release: JournalRelease; let phase: String }
            let entries = try JSONDecoder().decode([JournalEntry].self, from: ProtectedUpdatePackage.readFile("updater.transactions.v1",
                directory: root.appendingPathComponent("update-journal"), limit: 1024 * 1024))
            guard let entry = entries.first(where: { $0.receipt == envelope.request.receipt }),
                  entries.filter({ $0.receipt.id == envelope.request.receipt.id }).count == 1,
                  entry.phase == "protectedHandoff", entry.release.signature.count == 64,
                  Data(SHA256.hash(data: entry.release.payload)) == envelope.binding.signedPayloadSHA256 else {
                throw MaintenanceProtocolError.invalidRequest
            }
        } catch { acquired.forEach { close($0) }; descriptors.forEach { close($0) }; throw error }
        self.journal = journal; self.staging = staging; locks = acquired
        record = Record(envelope: envelope, phase: .accepted, replacement: nil)
        try persist()
    }
    deinit { locks.forEach { close($0) }; close(journal); close(staging) }

    public func finish(timeout: TimeInterval = 300) async throws {
        guard timeout > 0, timeout <= 300 else { throw MaintenanceProtocolError.invalidRequest }
        do {
            guard try await parent.waitForExit(timeout: min(timeout, 60)) else { throw MaintenanceProtocolError.invalidRequest }
            record.phase = .awaitingAdministrator; try persist()
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(Int64(timeout * 1000)))
            var installed: ProtectedHelperRecord?
            while ContinuousClock.now < deadline {
                try Task.checkCancellation()
                let current = try environment.installed()
                if current.generation == record.envelope.binding.nextGeneration {
                    try environment.coherent(current, record.envelope); installed = current; break
                }
                guard current.generation == record.envelope.binding.previousGeneration else { throw MaintenanceProtocolError.invalidRequest }
                try await Task.sleep(for: .milliseconds(250))
            }
            guard let installed else { throw MaintenanceProtocolError.invalidRequest }
            record.phase = .launching; try persist()
            var challenge = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, challenge.count, &challenge) == errSecSuccess else { throw MaintenanceProtocolError.invalidRequest }
            let request = try UpdateLaunchRequest(receipt: record.envelope.request.receipt, identity: HelperIdentity.appIdentifier,
                build: installed.build, minimumSystemVersion: record.envelope.minimumSystemVersion, challenge: Data(challenge))
            try launcher.launch(application: environment.application(installed), request: request, allowedHashes: installed.appHashes)
            guard try launcher.isAuthenticated(receipt: request.receipt), try parent.hasExited() else { throw MaintenanceProtocolError.invalidRequest }
            try environment.coherent(environment.installed(), record.envelope)
            record.replacement = launcher.identity; record.phase = .completed; try persist()
            releaseOwnership()
            try launcher.acceptStartup()
        } catch { record.phase = .interrupted; try? persist(); throw error }
    }
    private func releaseOwnership() {
        locks.forEach { close($0) }; locks = []
        close(journal); journal = -1; close(staging); staging = -1
    }
    public static func requireCoherent(_ installed: ProtectedHelperRecord, envelope: ProtectedUpdateEnvelope) throws {
        try installed.validate(); try envelope.validate()
        guard installed.maintenanceBinding == envelope.binding, installed.generation == envelope.binding.nextGeneration,
              installed.installationID == envelope.binding.installationID else { throw MaintenanceProtocolError.invalidRequest }
        _ = try ExactCodeIdentity.verify(at: installed.applicationURL,
            requirement: ExactCodeIdentity.requirement(hashes: installed.appHashes, identifier: HelperIdentity.appIdentifier))
        _ = try ExactCodeIdentity.verify(at: ProtectedHelperRecord.helperURL,
            requirement: ExactCodeIdentity.requirement(hashes: installed.helperHashes, identifier: HelperIdentity.helperIdentifier))
        _ = try ExactCodeIdentity.verify(at: installed.applicationURL.appendingPathComponent("Contents/MacOS/WattMaintenance"),
            requirement: ExactCodeIdentity.requirement(hashes: installed.maintenanceHashes, identifier: HelperIdentity.appIdentifier + ".maintenance"))
    }
    private func persist() throws {
        for (index, item) in [(journal, "update-journal"), (staging, "update-staging")].enumerated() {
            guard index < locks.count else { throw MaintenanceProtocolError.invalidRequest }
            let visible = try ProtectedUpdatePackage.privateDirectory(environment.directory.appendingPathComponent(item.1))
            defer { close(visible) }
            var held = stat(), current = stat(), heldLock = stat(), currentLock = stat()
            guard fstat(item.0, &held) == 0, fstat(visible, &current) == 0,
                  held.st_dev == current.st_dev, held.st_ino == current.st_ino,
                  fstat(locks[index], &heldLock) == 0,
                  fstatat(visible, ".writer.lock", &currentLock, AT_SYMLINK_NOFOLLOW) == 0,
                  heldLock.st_dev == currentLock.st_dev, heldLock.st_ino == currentLock.st_ino else {
                throw MaintenanceProtocolError.invalidRequest
            }
        }
        let bytes = try JSONEncoder().encode(record), temporary = ".protected-update-" + UUID().uuidString
        guard bytes.count <= 65536 else { throw MaintenanceProtocolError.oversized }
        let fd = openat(journal, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }; defer { close(fd); unlinkat(journal, temporary, 0) }
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < bytes.count {
                let count = Darwin.write(fd, raw.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw MaintenanceProtocolError.invalidRequest }; offset += count
            }
        }
        guard fsync(fd) == 0, renameat(journal, temporary, journal, "protected-update-" + record.envelope.request.receipt.id.uuidString + ".json") == 0,
              fsync(journal) == 0 else { throw MaintenanceProtocolError.invalidRequest }
    }
}
