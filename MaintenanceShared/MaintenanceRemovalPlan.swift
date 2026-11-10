import CryptoKit
import Darwin
import Foundation
import ServiceManagement
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Exact bundle inventory authorized by the actual live parent's executable path.
/// The only external configuration is the preference file derived from its signed identifier.
public struct MaintenanceRemovalPlan: Codable, Equatable, Sendable {
    public enum HelperRoute: String, Codable, Sendable { case fixedInstallation, certificate }
    public struct Entry: Codable, Equatable, Sendable {
        public let relative: String
        public let device: UInt64
        public let inode: UInt64
        public let mode: UInt16
        public let digest: Data?
    }
    public let installationID: UUID
    public let generation: UInt64
    public let applicationPath: String
    public let entries: [Entry]
    public let parent: MaintenanceProcessIdentity
    public let configurationPath: String?
    public let configurationEntries: [Entry]?
    public let protectedRecord: ProtectedHelperRecord?
    public let helperRoute: HelperRoute

    public static func protectedCoordinates(application: URL) throws -> (UUID, UInt64)? {
        let prefix = ProtectedHelperRecord.directory.appendingPathComponent("generations").path + "/"
        guard application.path.hasPrefix(prefix) else { return nil }
        let parts = application.path.dropFirst(prefix.count).split(separator: "/")
        guard parts.count == 2, parts[1] == "Watt.app", let separator = parts[0].lastIndex(of: "-"),
              let identifier = UUID(uuidString: String(parts[0][..<separator])),
              let generation = UInt64(parts[0][parts[0].index(after: separator)...]), generation > 0,
              String(generation) == parts[0][parts[0].index(after: separator)...] else { throw MaintenanceProtocolError.invalidRequest }
        return (identifier, generation)
    }

    /// A helper-only removal leaves immutable root-established generation ownership.
    /// Missing public pins are usable only with fixed-file and actual process absence.
    public static func readProtectedRecord(application: URL) throws -> ProtectedHelperRecord? {
        guard let (installation, generation) = try protectedCoordinates(application: application) else { return nil }
        var status = stat()
        let record: ProtectedHelperRecord
        if lstat(ProtectedHelperRecord.publicURL.path, &status) == 0 {
            record = try ProtectedHelperRecord.read(expectedInstallationID: installation)
        } else {
            guard errno == ENOENT, try fixedHelperAbsent() else { throw MaintenanceProtocolError.invalidRequest }
            record = try ProtectedHelperRecord.readGenerationRecord(installationID: installation, generation: generation)
        }
        guard record.generation == generation, record.applicationURL == application else { throw MaintenanceProtocolError.invalidRequest }
        return record
    }

    public static func fixedHelperAbsent() throws -> Bool {
        for url in [ProtectedHelperRecord.publicURL, ProtectedHelperRecord.helperURL, ProtectedHelperRecord.plistURL] {
            var status = stat()
            if lstat(url.path, &status) == 0 { return false }
            guard errno == ENOENT else { throw MaintenanceProtocolError.invalidRequest }
        }
        return MaintenanceProcessWitness.helperProcessesAbsent()
    }

    public static func enroll(installationID: UUID, generation: UInt64,
                              parent: MaintenanceProcessIdentity) throws -> Self {
        guard generation > 0, try MaintenanceProcessWitness.matches(parent), parent.uid == getuid() else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(parent.pid, &buffer, UInt32(buffer.count)) > 0 else { throw MaintenanceProtocolError.invalidRequest }
        guard let end = buffer.firstIndex(of: 0), end > 0,
              let executable = String(bytes: buffer[..<end].map { UInt8(bitPattern: $0) }, encoding: .utf8) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let url = URL(fileURLWithPath: executable)
        guard url.deletingLastPathComponent().lastPathComponent == "MacOS",
              url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent == "Contents" else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let app = url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let protectedRecord: ProtectedHelperRecord?
        if app.path.hasPrefix(ProtectedHelperRecord.directory.path + "/generations/") {
            guard let record = try readProtectedRecord(application: app), record.installationID == installationID,
                  record.generation == generation else { throw MaintenanceProtocolError.invalidRequest }
            _ = try HelperTrustPolicy.protectedInstallation(record).verifyExecutable(at: url, helper: false)
            protectedRecord = record
        } else { protectedRecord = nil }
        guard app.pathExtension == "app", let entries = try snapshot(app.path, uid: protectedRecord == nil ? parent.uid : 0) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var configuration: String?
        var configurationEntries: [Entry]?
        var helperRoute = HelperRoute.fixedInstallation
        if let values = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
           let identifier = values["CFBundleIdentifier"] as? String {
            if protectedRecord == nil, values["WATTHelperTrustMode"] as? String == "certificate" { helperRoute = .certificate }
            guard !identifier.isEmpty, identifier.utf8.count <= 128,
                  identifier.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 46 || $0 == 45 }),
                  let user = getpwuid(parent.uid), let home = user.pointee.pw_dir else { throw MaintenanceProtocolError.invalidRequest }
            configuration = URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Library/Preferences")
                .appendingPathComponent(identifier + ".plist").path
            configurationEntries = try snapshot(configuration!, uid: parent.uid)
            guard configurationEntries == nil || (configurationEntries!.count == 1 && configurationEntries![0].digest != nil) else {
                throw MaintenanceProtocolError.invalidRequest
            }
        }
        return Self(installationID: installationID, generation: generation, applicationPath: app.path,
                    entries: entries, parent: parent, configurationPath: configuration, configurationEntries: configurationEntries,
                    protectedRecord: protectedRecord, helperRoute: helperRoute)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 1_048_576 else { throw MaintenanceProtocolError.oversized }
        return data
    }
    public var digest: Data { get throws { Data(SHA256.hash(data: try encoded())) } }

    public func validateLiveParent(_ request: MaintenanceRequest) throws {
        guard request.installationID == installationID, request.generation == generation,
              request.parent == parent, request.operation == .uninstall,
              request.removalPlanSHA256 == (try digest),
              self == (try Self.enroll(installationID: installationID, generation: generation, parent: parent)) else {
            throw MaintenanceProtocolError.invalidRequest
        }
    }

    public func isAbsent() throws -> Bool {
        guard try Self.snapshot(applicationPath, uid: protectedRecord == nil ? parent.uid : 0) == nil else { return false }
        if let configurationPath { return try Self.snapshot(configurationPath, uid: parent.uid) == nil }
        return true
    }

    @MainActor public func helperIsAbsent() throws -> Bool {
        switch helperRoute {
        case .fixedInstallation: return try Self.fixedHelperAbsent()
        case .certificate:
            // Unknown/notFound status is not registration absence. The companion is
            // independently responsible for verifying the certificate route again.
            return SMAppService.daemon(plistName: HelperIdentity.daemonPlist).status == .notRegistered
                && MaintenanceProcessWitness.helperProcessesAbsent()
        }
    }

    /// Parent exit must be established by a previously authenticated opaque observation.
    public func removeAfterExit(_ observation: MaintenanceProcessWitness.LiveObservation,
                                receipt: MaintenanceReceipt) throws {
        guard observation.identity == parent, try observation.hasExited(),
              try Self.snapshot(applicationPath, uid: protectedRecord == nil ? parent.uid : 0) == entries else {
            throw MaintenanceProtocolError.invalidRequest
        }
        if let configurationPath, let configurationEntries {
            try move(configurationPath, expected: configurationEntries, receipt: receipt)
        } else if let configurationPath, try Self.snapshot(configurationPath, uid: parent.uid) != nil {
            throw MaintenanceProtocolError.invalidRequest
        }
        if protectedRecord == nil {
            try move(applicationPath, expected: entries, receipt: receipt)
            guard try isAbsent() else { throw MaintenanceProtocolError.invalidRequest }
        }
    }

    public func administratorBinding(receipt: MaintenanceReceipt) throws -> ProtectedMaintenanceBinding? {
        guard let record = protectedRecord else { return nil }
        return try ProtectedMaintenanceBinding(receipt: ProtectedMaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt),
            installationID: installationID, previousGeneration: generation, nextGeneration: generation,
            operation: .uninstall, build: record.build, removalPlanSHA256: digest)
    }

    public func protectedRemovalVerified(receipt: MaintenanceReceipt) throws -> Bool {
        guard protectedRecord != nil, let expected = try administratorBinding(receipt: receipt) else { return false }
        let bytes = try ProtectedHelperRecord.readProtectedFile(at: ProtectedHelperRecord.maintenanceResultURL)
        let binding = try JSONDecoder().decode(ProtectedMaintenanceBinding.self, from: bytes)
        try binding.validate()
        if binding != expected {
            guard binding.receipt.id != expected.receipt.id else { throw MaintenanceProtocolError.invalidRequest }
            return false // A valid prior installation/transaction result is pending, never success.
        }
        for url in [ProtectedHelperRecord.publicURL, ProtectedHelperRecord.helperURL, ProtectedHelperRecord.plistURL] {
            var status = stat()
            if lstat(url.path, &status) == 0 { return false }
            guard errno == ENOENT else { throw MaintenanceProtocolError.invalidRequest }
        }
        return try isAbsent() && MaintenanceProcessWitness.helperProcessesAbsent()
    }

    private func move(_ path: String, expected: [Entry], receipt: MaintenanceReceipt) throws {
        guard try Self.snapshot(path, uid: parent.uid) == expected else { throw MaintenanceProtocolError.invalidRequest }
        let url = URL(fileURLWithPath: path)
        let directory = try BoundedUSTAR.openDirectory(url.deletingLastPathComponent())
        defer { close(directory) }
        let backup = ".\(url.lastPathComponent).watt-removal-\(receipt.id.uuidString)"
        guard renameatx_np(directory, url.lastPathComponent, directory, backup, UInt32(RENAME_EXCL)) == 0,
              fsync(directory) == 0 else { throw MaintenanceProtocolError.invalidRequest }
        let backupPath = url.deletingLastPathComponent().appendingPathComponent(backup).path
        guard try Self.snapshot(backupPath, uid: parent.uid) == expected,
              try Self.snapshot(path, uid: parent.uid) == nil else {
            throw MaintenanceProtocolError.invalidRequest
        }
    }

    /// A restarted companion must re-establish authority from its actual OS-observed code
    /// and location. The persisted PID/plan is never itself a recovery capability.
    public func restore(receipt: MaintenanceReceipt, observer: MaintenanceProcessWitness.LiveObservation) throws {
        try validateRecoveryAuthority(receipt: receipt, observer: observer)
        if protectedRecord == nil { try restoreObject(applicationPath, expected: entries, receipt: receipt) }
        if let path = configurationPath, let expected = configurationEntries {
            try restoreObject(path, expected: expected, receipt: receipt)
        }
    }

    public func validateRecoveryAuthority(receipt: MaintenanceReceipt,
                                          observer: MaintenanceProcessWitness.LiveObservation) throws {
        guard observer.identity.uid == parent.uid, observer.identity.uid == getuid(),
              try MaintenanceProcessWitness.matches(observer.identity) else { throw MaintenanceProtocolError.invalidRequest }
        if let record = protectedRecord {
            guard record.applicationURL.path == applicationPath,
                  record.installationID == installationID, record.generation == generation,
                  record.maintenanceHashes.contains(observer.identity.codeDirectoryHash) else { throw MaintenanceProtocolError.invalidRequest }
            // The root record or the exact protected tombstone authenticates this saved plan.
            var status = stat()
            if lstat(ProtectedHelperRecord.publicURL.path, &status) == 0 {
                guard try ProtectedHelperRecord.read(expectedInstallationID: installationID) == record else { throw MaintenanceProtocolError.invalidRequest }
            } else {
                guard errno == ENOENT else { throw MaintenanceProtocolError.invalidRequest }
                let generationRecord = ProtectedHelperRecord.generationRecordURL(installationID: installationID, generation: generation)
                if lstat(generationRecord.path, &status) == 0 {
                    guard try Self.fixedHelperAbsent(),
                          try ProtectedHelperRecord.readGenerationRecord(installationID: installationID, generation: generation) == record else {
                        throw MaintenanceProtocolError.invalidRequest
                    }
                } else {
                    guard errno == ENOENT,
                          try ProtectedMaintenanceBinding.readResult() == administratorBinding(receipt: receipt) else {
                        throw MaintenanceProtocolError.invalidRequest
                    }
                }
            }
            if let path = configurationPath {
                guard let user = getpwuid(parent.uid), let home = user.pointee.pw_dir,
                      path == URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Library/Preferences")
                        .appendingPathComponent(HelperIdentity.appIdentifier + ".plist").path else { throw MaintenanceProtocolError.invalidRequest }
            }
            return
        }
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(observer.identity.pid, &buffer, UInt32(buffer.count)) > 0,
              let end = buffer.firstIndex(of: 0), end > 0,
              let path = String(bytes: buffer[..<end].map({ UInt8(bitPattern: $0) }), encoding: .utf8) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let original = applicationPath + "/Contents/MacOS/"
        let backup = backupURL(applicationPath, receipt: receipt).path + "/Contents/MacOS/"
        let root: String
        if path.hasPrefix(original) { root = applicationPath }
        else if path.hasPrefix(backup) { root = backupURL(applicationPath, receipt: receipt).path }
        else { throw MaintenanceProtocolError.invalidRequest }
        guard try Self.snapshot(root, uid: parent.uid) == entries else { throw MaintenanceProtocolError.invalidRequest }
        // Derive the only allowed external preference file again from the actual enrolled bundle.
        if let configurationPath {
            let data = try Data(contentsOf: URL(fileURLWithPath: root).appendingPathComponent("Contents/Info.plist"))
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            guard let identifier = plist?["CFBundleIdentifier"] as? String,
                  !identifier.isEmpty, identifier.utf8.count <= 128,
                  identifier.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0)
                      || (48...57).contains($0) || $0 == 46 || $0 == 45 }),
                  let user = getpwuid(parent.uid), let home = user.pointee.pw_dir,
                  configurationPath == URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Library/Preferences")
                    .appendingPathComponent(identifier + ".plist").path else { throw MaintenanceProtocolError.invalidRequest }
        }
    }

    private func backupURL(_ path: String, receipt: MaintenanceReceipt) -> URL {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).watt-removal-\(receipt.id.uuidString)")
    }
    private func restoreObject(_ path: String, expected: [Entry], receipt: MaintenanceReceipt) throws {
        if let current = try Self.snapshot(path, uid: parent.uid) {
            guard current == expected else { throw MaintenanceProtocolError.invalidRequest }
            return
        }
        let backup = backupURL(path, receipt: receipt)
        guard try Self.snapshot(backup.path, uid: parent.uid) == expected else { throw MaintenanceProtocolError.invalidRequest }
        let url = URL(fileURLWithPath: path)
        let directory = try BoundedUSTAR.openDirectory(url.deletingLastPathComponent()); defer { close(directory) }
        guard renameatx_np(directory, backup.lastPathComponent, directory, url.lastPathComponent, UInt32(RENAME_EXCL)) == 0,
              fsync(directory) == 0, try Self.snapshot(path, uid: parent.uid) == expected else {
            throw MaintenanceProtocolError.invalidRequest
        }
    }

    private static func snapshot(_ path: String, uid: UInt32) throws -> [Entry]? {
        let url = URL(fileURLWithPath: path)
        guard path.hasPrefix("/"), !path.contains("\0"),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var parentFD = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parentFD >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { close(parentFD) }
        for component in url.deletingLastPathComponent().pathComponents.dropFirst() {
            let next = openat(parentFD, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if next < 0 {
                if errno == ENOENT { return nil }
                throw MaintenanceProtocolError.invalidRequest
            }
            close(parentFD); parentFD = next
        }
        var result: [Entry] = []
        guard try capture(parentFD, name: url.lastPathComponent, relative: "", uid: uid, into: &result) else { return nil }
        return result
    }
    private static func capture(_ parent: Int32, name: String, relative: String, uid: UInt32,
                                into result: inout [Entry]) throws -> Bool {
        var st = stat()
        guard fstatat(parent, name, &st, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ENOENT { return false }; throw MaintenanceProtocolError.invalidRequest
        }
        let kind = st.st_mode & S_IFMT
        guard st.st_uid == uid, st.st_mode & 0o022 == 0,
              kind == S_IFDIR || (kind == S_IFREG && st.st_nlink == 1),
              result.count < 4096, relative.utf8.count <= 1024 else { throw MaintenanceProtocolError.invalidRequest }
        let fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | (kind == S_IFDIR ? O_DIRECTORY : 0))
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, opened.st_ino == st.st_ino, opened.st_dev == st.st_dev else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var digest: Data?
        if kind == S_IFREG {
            guard st.st_size >= 0, st.st_size <= 1_073_741_824 else { throw MaintenanceProtocolError.oversized }
            var hasher = SHA256(); var buffer = [UInt8](repeating: 0, count: 65536); var total: Int64 = 0
            while true {
                let count = read(fd, &buffer, buffer.count)
                guard count >= 0 else { throw MaintenanceProtocolError.invalidRequest }
                if count == 0 { break }; total += Int64(count)
                guard total <= st.st_size else { throw MaintenanceProtocolError.invalidRequest }
                hasher.update(data: Data(buffer.prefix(count)))
            }
            guard total == st.st_size else { throw MaintenanceProtocolError.invalidRequest }
            digest = Data(hasher.finalize())
        }
        result.append(Entry(relative: relative, device: UInt64(st.st_dev), inode: st.st_ino, mode: st.st_mode, digest: digest))
        if kind == S_IFDIR {
            guard let dir = fdopendir(dup(fd)) else { throw MaintenanceProtocolError.invalidRequest }
            defer { closedir(dir) }
            var names: [String] = []
            while let entry = readdir(dir) {
                let name = withUnsafePointer(to: &entry.pointee.d_name) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
                }
                if name != "." && name != ".." { names.append(name) }
            }
            for name in names.sorted() {
                guard try capture(fd, name: name, relative: relative + "/" + name, uid: uid, into: &result) else {
                    throw MaintenanceProtocolError.invalidRequest
                }
            }
        }
        return true
    }
}
