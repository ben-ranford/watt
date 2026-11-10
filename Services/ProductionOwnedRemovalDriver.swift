import CryptoKit
import Darwin
import Foundation

/// OS/process and installation ownership proof is supplied independently of the journal.
/// A decoded manifest, receipt, or PID is never sufficient ownership evidence.
@MainActor
protocol RemovalOwnershipWitness {
    func validateInstallation(_ manifest: RemovalManifest) throws
    func processesAndRegistrations(_ manifest: RemovalManifest) async throws -> RemovalInventory
}

/// Removes exact enrolled objects by preserving them in receipt-scoped, same-volume backups.
/// Backups deliberately remain available for explicit recovery. No recursive delete is used.
@MainActor
final class ProductionOwnedRemovalDriver: OwnedRemovalDriver {
    private struct Entry: Codable, Equatable {
        let name: String
        let device: UInt64
        let inode: UInt64
        let mode: UInt16
        let digest: Data?
    }
    private struct Journal: Codable {
        var transaction: RemovalTransaction?
        var objects: [String: [Entry]]
        var intents: Set<String>
    }
    private let manifest: RemovalManifest
    private let storage: any PreferenceStorage
    private let witness: any RemovalOwnershipWitness
    private let key: String
    private var journal: Journal

    init(manifest: RemovalManifest, storage: any PreferenceStorage,
         witness: any RemovalOwnershipWitness) throws {
        try manifest.validate()
        guard manifest.resources.allSatisfy({ resource in
            resource.kind != .application || URL(fileURLWithPath: resource.path).pathExtension == "app"
        }) else { throw ServiceFailure.invalidData }
        try witness.validateInstallation(manifest)
        self.manifest = manifest; self.storage = storage; self.witness = witness
        key = "removal.\(manifest.installationID.uuidString).v1"
        if let data = try storage.read(key: key) {
            journal = try JSONDecoder().decode(Journal.self, from: data)
            guard journal.transaction?.manifest == manifest,
                  Set(journal.objects.keys).isSubset(of: Set(manifest.resources.map(\.path))),
                  journal.intents.isSubset(of: Set(manifest.resources.map(\.path))) else {
                throw ServiceFailure.untrustedIdentity
            }
        } else {
            var objects: [String: [Entry]] = [:]
            for resource in manifest.resources {
                if let entries = try Self.snapshot(resource.path) {
                    guard resource.kind != .configuration || (entries.count == 1 && entries[0].digest != nil) else {
                        throw ServiceFailure.untrustedIdentity
                    }
                    objects[resource.path] = entries
                }
            }
            journal = Journal(transaction: nil, objects: objects, intents: [])
        }
    }

    func inventory(manifest: RemovalManifest) async throws -> RemovalInventory {
        guard manifest == self.manifest else { throw ServiceFailure.untrustedIdentity }
        try witness.validateInstallation(manifest)
        let state = try await witness.processesAndRegistrations(manifest)
        var paths = Set<String>()
        for resource in manifest.resources {
            if let actual = try Self.snapshot(resource.path) {
                guard actual == journal.objects[resource.path] else { throw ServiceFailure.untrustedIdentity }
                paths.insert(resource.path)
            }
        }
        // Registrations may outlive files; retain those exact owned paths as present.
        guard state.presentPaths.isSubset(of: Set(manifest.resources.map(\.path))) else {
            throw ServiceFailure.untrustedIdentity
        }
        return RemovalInventory(presentPaths: paths.union(state.presentPaths),
                                helperRunning: state.helperRunning, appRunning: state.appRunning)
    }

    func transaction() throws -> RemovalTransaction? { journal.transaction }

    func save(_ transaction: RemovalTransaction) throws {
        guard transaction.manifest == manifest, transaction.receipt.createdAt.timeIntervalSince1970.isFinite else { throw ServiceFailure.untrustedIdentity }
        if let existing = journal.transaction {
            guard existing.receipt == transaction.receipt, existing.scope == transaction.scope,
                  existing.baseline == transaction.baseline else { throw ServiceFailure.untrustedIdentity }
            let transition = existing.phase == transaction.phase
                || (existing.phase == .removing && transaction.phase == .rollingBack)
                || (existing.phase == .rollingBack && transaction.phase == .rolledBack)
            guard transition else { throw ServiceFailure.interruptedRemoval }
        } else {
            guard transaction.phase == .removing else { throw ServiceFailure.interruptedRemoval }
        }
        var next = journal; next.transaction = transaction
        try commit(next)
    }

    func remove(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        try bound(resource, transaction)
        guard transaction.phase == .removing else { throw ServiceFailure.interruptedRemoval }
        // Protected helper mutation belongs exclusively to the administrator installer.
        guard resource.kind != .helper else { throw ServiceFailure.adminRequired }
        guard resource.kind != .login else { throw ServiceFailure.unknownStatus }
        let state = try await witness.processesAndRegistrations(manifest)
        guard resource.kind != .application || !state.appRunning else { throw ServiceFailure.interruptedRemoval }
        try witness.validateInstallation(manifest)
        let backup = backupPath(resource.path, receipt: transaction.receipt)
        guard let actual = try Self.snapshot(resource.path) else {
            guard journal.intents.contains(resource.path),
                  try Self.snapshot(backup) == journal.objects[resource.path] else {
                throw ServiceFailure.untrustedIdentity
            }
            return
        }
        guard actual == journal.objects[resource.path], try Self.snapshot(backup) == nil else {
            throw ServiceFailure.untrustedIdentity
        }
        var next = journal; next.intents.insert(resource.path)
        try commit(next) // durable intent before rename
        try Self.moveExact(resource.path, to: backup, expected: actual)
    }

    func restore(_ resource: RemovalManifest.Resource, transaction: RemovalTransaction) async throws {
        try bound(resource, transaction)
        guard transaction.phase == .rollingBack else { throw ServiceFailure.interruptedRemoval }
        guard journal.intents.contains(resource.path), let original = journal.objects[resource.path] else { return }
        let backup = backupPath(resource.path, receipt: transaction.receipt)
        if try Self.snapshot(backup) == nil {
            guard try Self.snapshot(resource.path) == original else { throw ServiceFailure.untrustedIdentity }
            return
        }
        guard try Self.snapshot(resource.path) == nil else { throw ServiceFailure.untrustedIdentity }
        try Self.moveExact(backup, to: resource.path, expected: original)
    }

    private func bound(_ resource: RemovalManifest.Resource, _ transaction: RemovalTransaction) throws {
        guard transaction == journal.transaction, transaction.manifest == manifest,
              manifest.resources.contains(resource) else { throw ServiceFailure.untrustedIdentity }
    }
    private func commit(_ next: Journal) throws {
        try storage.write(JSONEncoder().encode(next), key: key)
        journal = next
    }
    private func backupPath(_ path: String, receipt: OperationReceipt) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingLastPathComponent().appendingPathComponent(
            ".\(url.lastPathComponent).watt-removal-\(receipt.id.uuidString)").path
    }

    private static func parent(_ path: String) throws -> (Int32, String) {
        let components = path.split(separator: "/").map(String.init)
        guard path.hasPrefix("/"), let name = components.last, !components.contains(".."),
              !components.contains("."), !path.contains("\0") else { throw ServiceFailure.invalidData }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw ServiceFailure.persistence }
        for component in components.dropLast() {
            let next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(fd)
            guard next >= 0 else { throw ServiceFailure.untrustedIdentity }
            fd = next
        }
        return (fd, name)
    }

    private static func snapshot(_ path: String) throws -> [Entry]? {
        let (fd, name) = try parent(path); defer { close(fd) }
        var entries: [Entry] = []
        guard try capture(parent: fd, name: name, relative: "", into: &entries) else { return nil }
        return entries
    }
    private static func capture(parent: Int32, name: String, relative: String,
                                into entries: inout [Entry]) throws -> Bool {
        var status = stat()
        guard fstatat(parent, name, &status, AT_SYMLINK_NOFOLLOW) == 0 else {
            if errno == ENOENT { return false }
            throw ServiceFailure.persistence
        }
        let kind = status.st_mode & S_IFMT
        guard kind == S_IFREG || kind == S_IFDIR, status.st_nlink == 1 || kind == S_IFDIR,
              entries.count < 100_000, relative.count < 4096 else { throw ServiceFailure.untrustedIdentity }
        let fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | (kind == S_IFDIR ? O_DIRECTORY : 0))
        guard fd >= 0 else { throw ServiceFailure.untrustedIdentity }
        defer { close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, opened.st_ino == status.st_ino,
              opened.st_dev == status.st_dev else { throw ServiceFailure.untrustedIdentity }
        var digest: Data?
        if kind == S_IFREG {
            guard status.st_size >= 0, status.st_size <= 1_073_741_824 else { throw ServiceFailure.invalidData }
            var hash = SHA256(); var bytes = [UInt8](repeating: 0, count: 65_536); var count: Int64 = 0
            while true {
                let n = read(fd, &bytes, bytes.count)
                guard n >= 0 else { throw ServiceFailure.persistence }
                if n == 0 { break }
                count += Int64(n)
                guard count <= 1_073_741_824 else { throw ServiceFailure.invalidData }
                hash.update(data: Data(bytes.prefix(n)))
            }
            guard count == status.st_size else { throw ServiceFailure.untrustedIdentity }
            digest = Data(hash.finalize())
        }
        entries.append(Entry(name: relative, device: UInt64(status.st_dev), inode: status.st_ino,
                             mode: status.st_mode, digest: digest))
        if kind == S_IFDIR {
            guard let directory = fdopendir(dup(fd)) else { throw ServiceFailure.persistence }
            defer { closedir(directory) }
            var names: [String] = []
            while let entry = readdir(directory) {
                let value = withUnsafePointer(to: &entry.pointee.d_name) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
                }
                if value != "." && value != ".." { names.append(value) }
            }
            for child in names.sorted() {
                guard try capture(parent: fd, name: child, relative: relative + "/" + child, into: &entries) else {
                    throw ServiceFailure.untrustedIdentity
                }
            }
        }
        return true
    }
    private static func moveExact(_ source: String, to destination: String, expected: [Entry]) throws {
        let (sourceFD, sourceName) = try parent(source); defer { close(sourceFD) }
        let (destinationFD, destinationName) = try parent(destination); defer { close(destinationFD) }
        var actual: [Entry] = []
        guard try capture(parent: sourceFD, name: sourceName, relative: "", into: &actual), actual == expected else {
            throw ServiceFailure.untrustedIdentity
        }
        guard renameatx_np(sourceFD, sourceName, destinationFD, destinationName, UInt32(RENAME_EXCL)) == 0 else {
            throw ServiceFailure.persistence
        }
        guard fsync(sourceFD) == 0, fsync(destinationFD) == 0 else { throw ServiceFailure.persistence }
        // A concurrent change is retained in the backup and surfaced; never erase evidence.
        guard try snapshot(destination) == expected else { throw ServiceFailure.untrustedIdentity }
    }
}
