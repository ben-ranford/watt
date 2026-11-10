import CryptoKit
import Foundation
import Security
import Darwin
#if canImport(WattMaintenanceShared)
import WattMaintenanceShared
#endif
#if SWIFT_PACKAGE
import WattHelperShared
#endif

struct VerifiedUpdateBundle: Codable, Equatable, Sendable {
    let identifier: String
    let build: UInt64
    let minimumSystemVersion: String
    let codeHash: Data
}

@MainActor
protocol ProductionUpdateCodeValidator {
    func verify(bundle: URL) throws -> VerifiedUpdateBundle
}

/// Validates the sealed bundle and its actual ad-hoc or certificate-backed code identity.
/// No certificate/identifier fallback is used when code validation fails.
struct SecurityUpdateCodeValidator: ProductionUpdateCodeValidator {
    func verify(bundle: URL) throws -> VerifiedUpdateBundle {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundle as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), nil) == errSecSuccess else {
            throw ServiceFailure.untrustedIdentity
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any],
              let identifier = dictionary[kSecCodeInfoIdentifier as String] as? String,
              let hash = dictionary[kSecCodeInfoUnique as String] as? Data, hash.count == 20,
              let plist = dictionary[kSecCodeInfoPList as String] as? [String: Any],
              plist["CFBundleIdentifier"] as? String == identifier,
              let version = plist["CFBundleVersion"] as? String, !version.isEmpty,
              version.utf8.allSatisfy({ (48...57).contains($0) }), let build = UInt64(version), build > 0,
              let minimum = plist["LSMinimumSystemVersion"] as? String else { throw ServiceFailure.untrustedIdentity }
        return VerifiedUpdateBundle(identifier: identifier, build: build, minimumSystemVersion: minimum, codeHash: hash)
    }
}

@MainActor
protocol ProductionUpdateProcessWitness {
    func launch(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws
    func authenticatedRunning(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool
}

/// Staging and replacement are restricted to the constructor's fixed application and private root.
/// The external maintenance owner supplies a real process witness and protected-generation gate.
@MainActor
final class ProductionUpdateInstallationDriver: UpdateInstallationDriver {
    private struct Record: Codable {
        let receipt: OperationReceipt
        let manifest: UpdateManifest
        let original: VerifiedUpdateBundle
        var replacement: VerifiedUpdateBundle?
    }
    private let application: URL
    private let root: URL
    private let applicationOwnerUID: uid_t
    private let validator: any ProductionUpdateCodeValidator
    private let witness: any ProductionUpdateProcessWitness
    private let requiresAdministrator: @MainActor (UpdateManifest, OperationReceipt) throws -> Bool
    private let storage: AtomicMaintenanceStorage

    init(application: URL, stagingDirectory: URL, applicationOwnerUID: uid_t = geteuid(), validator: any ProductionUpdateCodeValidator = SecurityUpdateCodeValidator(),
         witness: any ProductionUpdateProcessWitness,
         requiresAdministrator: @escaping @MainActor (UpdateManifest, OperationReceipt) throws -> Bool) throws {
        guard application.isFileURL, application.pathExtension == "app",
              !application.path.hasPrefix(stagingDirectory.path + "/"),
              !stagingDirectory.path.hasPrefix(application.path + "/") else { throw ServiceFailure.invalidData }
        self.application = application; root = stagingDirectory; self.applicationOwnerUID = applicationOwnerUID; self.validator = validator
        self.witness = witness; self.requiresAdministrator = requiresAdministrator
        storage = try AtomicMaintenanceStorage(directory: stagingDirectory)
        _ = try verified(application)
    }
    private func key(_ receipt: OperationReceipt) -> String { "transaction-" + receipt.id.uuidString }
    private func directory(_ receipt: OperationReceipt) -> URL { root.appendingPathComponent(receipt.id.uuidString, isDirectory: true) }
    private func candidate(_ receipt: OperationReceipt) -> URL {
        directory(receipt).appendingPathComponent("payload", isDirectory: true).appendingPathComponent(application.lastPathComponent, isDirectory: true)
    }
    private func backup(_ receipt: OperationReceipt) -> URL { directory(receipt).appendingPathComponent("original.app", isDirectory: true) }
    private func record(_ receipt: OperationReceipt) throws -> Record {
        guard receipt.createdAt.timeIntervalSince1970.isFinite,
              let data = try storage.read(key: key(receipt)), let record = try? JSONDecoder().decode(Record.self, from: data),
              record.receipt == receipt else { throw ServiceFailure.invalidData }
        return record
    }
    private func save(_ record: Record) throws { try storage.write(JSONEncoder().encode(record), key: key(record.receipt)) }
    private func verified(_ url: URL) throws -> VerifiedUpdateBundle {
        let fd = try BoundedUSTAR.openDirectory(url)
        defer { close(fd) }
        var before = stat(), after = stat()
        guard fstat(fd, &before) == 0, before.st_uid == (url == application ? applicationOwnerUID : geteuid()), before.st_mode & 0o022 == 0 else {
            throw ServiceFailure.untrustedIdentity
        }
        try rejectLinks(url)
        let identity = try validator.verify(bundle: url)
        let current = try BoundedUSTAR.openDirectory(url)
        defer { close(current) }
        guard fstat(current, &after) == 0, before.st_dev == after.st_dev, before.st_ino == after.st_ino else {
            throw ServiceFailure.untrustedIdentity
        }
        return identity
    }
    private func rejectLinks(_ url: URL) throws {
        guard let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { throw ServiceFailure.invalidData }
        var count = 0, total: Int64 = 0
        for case let file as URL in files {
            var info = stat()
            guard lstat(file.path, &info) == 0, info.st_uid == (url == application ? applicationOwnerUID : geteuid()), info.st_mode & 0o022 == 0,
                  info.st_mode & S_IFMT == S_IFDIR || (info.st_mode & S_IFMT == S_IFREG && info.st_nlink == 1) else { throw ServiceFailure.untrustedIdentity }
            count += 1
            guard count <= BoundedUSTAR.maximumEntries, info.st_size >= 0,
                  info.st_size <= BoundedUSTAR.maximumBytes, total <= Int64(BoundedUSTAR.maximumBytes) - info.st_size else {
                throw ServiceFailure.invalidData
            }
            total += info.st_size
        }
    }
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws {
        guard receipt.createdAt.timeIntervalSince1970.isFinite,
              Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw ServiceFailure.invalidData }
        let archive = try BoundedUSTAR(validating: bytes)
        guard archive.entries.allSatisfy({ $0.path == application.lastPathComponent || $0.path.hasPrefix(application.lastPathComponent + "/") }) else {
            throw ServiceFailure.invalidData
        }
        if try storage.read(key: key(receipt)) != nil {
            try verifyStaged(manifest: manifest, receipt: receipt); return
        }
        let original = try verified(application)
        guard original.identifier == manifest.identity, original.build < manifest.build else { throw ServiceFailure.incompatibleVersion }
        var value = Record(receipt: receipt, manifest: manifest, original: original, replacement: nil)
        try save(value)
        let rootFD = try BoundedUSTAR.openDirectory(root)
        defer { close(rootFD) }
        guard mkdirat(rootFD, receipt.id.uuidString, 0o700) == 0, fsync(rootFD) == 0 else { throw ServiceFailure.persistence }
        try ProtectedUpdatePackage.writeFile(bytes, named: "release.tar", directory: directory(receipt))
        try archive.extract(intoFreshDirectory: directory(receipt).appendingPathComponent("payload", isDirectory: true))
        let identity = try verified(candidate(receipt))
        guard identity.identifier == manifest.identity, identity.build == manifest.build,
              identity.minimumSystemVersion == manifest.minimumSystemVersion else { throw ServiceFailure.untrustedIdentity }
        value.replacement = identity; try save(value)
    }
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        let value = try record(receipt)
        guard value.manifest == manifest, let replacement = value.replacement,
              try verified(candidate(receipt)) == replacement else { throw ServiceFailure.untrustedIdentity }
    }
    func preflightReplacement(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        try verifyStaged(manifest: manifest, receipt: receipt)
        if try requiresAdministrator(manifest, receipt) { throw ServiceFailure.adminRequired }
    }
    func closeForMaintenanceTransfer() { storage.close() }

    func exportProtectedPackage(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt,
                                installation: ProtectedHelperRecord) throws -> (ProtectedUpdateEnvelope, URL) {
        try verifyStaged(manifest: manifest, receipt: receipt)
        guard installation.generation < UInt64.max, application == installation.applicationURL else { throw ServiceFailure.untrustedIdentity }
        let staged = candidate(receipt).appendingPathComponent("Contents/MacOS", isDirectory: true)
        let binding: ProtectedMaintenanceBinding
        if let current = installation.maintenanceBinding, current.receipt.id == receipt.id,
           current.receipt.createdAt == receipt.createdAt,
           current.signedPayloadSHA256 == Data(SHA256.hash(data: release.payload)), current.archiveSHA256 == manifest.sha256,
           current.build == manifest.build {
            binding = current
        } else {
        guard manifest.build > installation.build else { throw ServiceFailure.incompatibleVersion }
        binding = try ProtectedMaintenanceBinding(receipt: ProtectedMaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt),
            installationID: installation.installationID, previousGeneration: installation.generation, nextGeneration: installation.generation + 1,
            operation: .update, signedPayloadSHA256: Data(SHA256.hash(data: release.payload)), archiveSHA256: manifest.sha256,
            build: manifest.build,
            replacementAppHashes: ExactCodeIdentity.allHashes(at: staged.appendingPathComponent("Watt"), identifier: HelperIdentity.appIdentifier),
            replacementHelperHashes: ExactCodeIdentity.allHashes(at: staged.appendingPathComponent("WattHelper"), identifier: HelperIdentity.helperIdentifier),
            replacementMaintenanceHashes: ExactCodeIdentity.allHashes(at: staged.appendingPathComponent("WattMaintenance"), identifier: HelperIdentity.appIdentifier + ".maintenance"))
        }
        let parent = try MaintenanceProcessWitness.observe(pid: getpid())
        guard installation.appHashes.contains(parent.codeDirectoryHash) else { throw ServiceFailure.untrustedIdentity }
        let request = try MaintenanceRequest(receipt: receipt, installationID: installation.installationID, generation: binding.previousGeneration,
            operation: .update, parent: parent, candidateSHA256: manifest.sha256)
        let envelope = try ProtectedUpdateEnvelope(request: request, binding: binding, minimumSystemVersion: manifest.minimumSystemVersion)
        let destination = directory(receipt).appendingPathComponent("protected-package", isDirectory: true)
        let parentFD = try ProtectedUpdatePackage.privateDirectory(directory(receipt)); defer { close(parentFD) }
        if mkdirat(parentFD, "protected-package", 0o700) != 0 {
            guard errno == EEXIST else { throw ServiceFailure.persistence }
            try ProtectedUpdatePackage.validate(envelope, at: destination)
            return (envelope, destination)
        }
        let bytes = try ProtectedUpdatePackage.readFile("release.tar", directory: directory(receipt), limit: BoundedUSTAR.maximumBytes)
        guard Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw ServiceFailure.invalidData }
        try ProtectedUpdatePackage.writeFile(try JSONEncoder().encode(release), named: "manifest.json", directory: destination)
        try ProtectedUpdatePackage.writeFile(bytes, named: "release.tar", directory: destination)
        try ProtectedUpdatePackage.writeFile(try JSONEncoder().encode(binding), named: "request.json", directory: destination)
        try ProtectedUpdatePackage.validate(envelope, at: destination)
        guard fsync(parentFD) == 0 else { throw ServiceFailure.persistence }
        return (envelope, destination)
    }
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        let value = try record(receipt)
        guard value.manifest == manifest else { throw ServiceFailure.invalidData }
        if try placement(manifest: manifest, receipt: receipt) == .replacement { return }
        try preflightReplacement(manifest: manifest, receipt: receipt)
        guard try verified(application) == value.original else { throw ServiceFailure.untrustedIdentity }
        // Copy into the private transaction first; preserve and verify the original before any move.
        if !FileManager.default.fileExists(atPath: backup(receipt).path) {
            try FileManager.default.copyItem(at: application, to: backup(receipt))
        }
        guard try verified(backup(receipt)) == value.original else { throw ServiceFailure.untrustedIdentity }
        try syncTree(backup(receipt))
        let displaced = directory(receipt).appendingPathComponent("displaced.app", isDirectory: true)
        try move(application, to: displaced, expecting: value.original)
        do { try move(candidate(receipt), to: application, expecting: value.replacement!) }
        catch { throw ServiceFailure.interruptedUpdate }
        guard try verified(application) == value.replacement else { throw ServiceFailure.interruptedUpdate }
    }
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement {
        let value = try record(receipt)
        guard value.manifest == manifest else { throw ServiceFailure.invalidData }
        guard let actual = try? verified(application) else { return .uncertain }
        if actual == value.original { return .original }
        if actual == value.replacement { return .replacement }
        return .uncertain
    }
    func rollback(receipt: OperationReceipt) throws {
        let value = try record(receipt)
        if let actual = try? verified(application) {
            if actual == value.original { return }
            guard actual == value.replacement else { throw ServiceFailure.untrustedIdentity }
            guard try verified(backup(receipt)) == value.original else { throw ServiceFailure.untrustedIdentity }
            let failed = directory(receipt).appendingPathComponent("failed.app", isDirectory: true)
            try move(application, to: failed, expecting: actual)
        } else {
            var info = stat()
            guard lstat(application.path, &info) != 0, errno == ENOENT else { throw ServiceFailure.untrustedIdentity }
        }
        guard try verified(backup(receipt)) == value.original else { throw ServiceFailure.untrustedIdentity }
        try move(backup(receipt), to: application, expecting: value.original)
    }
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws {
        guard try placement(manifest: manifest, receipt: receipt) == .replacement else { throw ServiceFailure.untrustedIdentity }
        try witness.launch(bundle: application, manifest: manifest, receipt: receipt)
    }
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool {
        guard try placement(manifest: manifest, receipt: receipt) == .replacement else { return false }
        return try witness.authenticatedRunning(bundle: application, manifest: manifest, receipt: receipt)
    }
    func discard(receipt: OperationReceipt) throws {
        if try storage.read(key: key(receipt)) == nil {
            guard try stagingAbsent(receipt: receipt) else { throw ServiceFailure.untrustedIdentity }
            return
        }
        let value = try record(receipt)
        guard try verified(application) == value.original else { throw ServiceFailure.interruptedUpdate }
        let url = directory(receipt)
        var info = stat()
        if lstat(url.path, &info) != 0 && errno == ENOENT { return }
        let parent = try BoundedUSTAR.openDirectory(root)
        defer { close(parent) }
        var remaining = BoundedUSTAR.maximumEntries + 16
        try removeDirectory(parent: parent, name: receipt.id.uuidString, remaining: &remaining)
        guard fsync(parent) == 0 else { throw ServiceFailure.persistence }
    }
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool {
        if try storage.read(key: key(receipt)) != nil { _ = try record(receipt) }
        var info = stat()
        if lstat(directory(receipt).path, &info) == 0 { return false }
        guard errno == ENOENT else { throw ServiceFailure.persistence }
        return true
    }
    private func move(_ from: URL, to: URL, expecting identity: VerifiedUpdateBundle) throws {
        guard try verified(from) == identity else { throw ServiceFailure.untrustedIdentity }
        let source = try BoundedUSTAR.openDirectory(from.deletingLastPathComponent())
        defer { close(source) }
        let target = try BoundedUSTAR.openDirectory(to.deletingLastPathComponent())
        defer { close(target) }
        // RENAME_EXCL keeps recovery from replacing unrelated destinations.
        guard renameatx_np(source, from.lastPathComponent, target, to.lastPathComponent, UInt32(RENAME_EXCL)) == 0,
              fsync(source) == 0, fsync(target) == 0 else { throw ServiceFailure.interruptedUpdate }
    }
    private func syncTree(_ url: URL) throws {
        guard let entries = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { throw ServiceFailure.persistence }
        var urls = [url]
        for case let child as URL in entries { urls.append(child) }
        for child in urls.reversed() {
            let fd = open(child.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
            guard fd >= 0 else { throw ServiceFailure.persistence }
            let result = fsync(fd); close(fd)
            guard result == 0 else { throw ServiceFailure.persistence }
        }
    }

    private func removeDirectory(parent: Int32, name: String, remaining: inout Int) throws {
        let fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw ServiceFailure.persistence }
        defer { close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, opened.st_uid == geteuid(), opened.st_mode & 0o022 == 0 else {
            throw ServiceFailure.untrustedIdentity
        }
        let duplicate = dup(fd)
        guard duplicate >= 0 else { throw ServiceFailure.persistence }
        guard let iterator = fdopendir(duplicate) else { close(duplicate); throw ServiceFailure.persistence }
        defer { closedir(iterator) }
        while let entry = readdir(iterator) {
            let child = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            if child == "." || child == ".." { continue }
            remaining -= 1
            var info = stat()
            guard remaining >= 0, fstatat(fd, child, &info, AT_SYMLINK_NOFOLLOW) == 0,
                  info.st_uid == geteuid(), info.st_mode & 0o022 == 0 else { throw ServiceFailure.untrustedIdentity }
            if info.st_mode & S_IFMT == S_IFDIR {
                try removeDirectory(parent: fd, name: child, remaining: &remaining)
            } else {
                guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
                      unlinkat(fd, child, 0) == 0 else { throw ServiceFailure.untrustedIdentity }
            }
        }
        var current = stat()
        guard fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) == 0,
              opened.st_dev == current.st_dev, opened.st_ino == current.st_ino,
              unlinkat(parent, name, AT_REMOVEDIR) == 0 else { throw ServiceFailure.persistence }
    }
}
