import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif
#if canImport(WattMaintenanceShared)
import WattMaintenanceShared
#endif

/// The exclusive writer lock for one private maintenance directory.
/// Acquisition is not actor-isolated, so launch can open the journal off the main thread.
/// `flock` stays `LOCK_EX | LOCK_NB`: a busy lock fails, it does not wait.
final class HeldLock: @unchecked Sendable {
    let directory: URL
    private var directoryFD: Int32
    private var lockFD: Int32
    private var released = false

    static func acquire(directory: URL) throws -> HeldLock {
        if LaunchPathPolicy.isPrivacyProtected(directory) { throw ServiceFailure.persistence }
        let parent = try BoundedUSTAR.openDirectory(directory.deletingLastPathComponent())
        defer { Darwin.close(parent) }
        let name = directory.lastPathComponent
        guard !name.isEmpty, name != ".", name != ".." else { throw ServiceFailure.persistence }
        if mkdirat(parent, name, 0o700) != 0 && errno != EEXIST { throw ServiceFailure.persistence }
        let root = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw ServiceFailure.persistence }
        var metadata = stat()
        guard fstat(root, &metadata) == 0, metadata.st_uid == geteuid(), metadata.st_mode & 0o077 == 0 else {
            Darwin.close(root); throw ServiceFailure.persistence
        }
        let lock = openat(root, ".writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lock >= 0 else { Darwin.close(root); throw ServiceFailure.persistence }
        guard fstat(lock, &metadata) == 0, metadata.st_uid == geteuid(), metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_mode & 0o077 == 0, metadata.st_nlink == 1, flock(lock, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(lock); Darwin.close(root); throw ServiceFailure.persistence
        }
        return HeldLock(directory: directory, directoryFD: root, lockFD: lock)
    }

    private init(directory: URL, directoryFD: Int32, lockFD: Int32) {
        self.directory = directory
        self.directoryFD = directoryFD
        self.lockFD = lockFD
    }

    deinit { release() }

    func release() {
        if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
        if directoryFD >= 0 { Darwin.close(directoryFD); directoryFD = -1 }
        released = true
    }

    func read(key: String, maximumBytes: Int) throws -> Data? {
        try validate(key)
        let fd = openat(directoryFD, key, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if fd < 0 && errno == ENOENT { return nil }
        guard fd >= 0 else { throw ServiceFailure.persistence }
        defer { Darwin.close(fd) }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == geteuid(), metadata.st_mode & 0o077 == 0, metadata.st_nlink == 1,
              metadata.st_size >= 0, metadata.st_size <= maximumBytes else { throw ServiceFailure.persistence }
        var data = Data(), buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0, count <= maximumBytes - data.count else { throw ServiceFailure.persistence }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard data.count == metadata.st_size else { throw ServiceFailure.persistence }
        return data
    }

    func write(_ data: Data, key: String, maximumBytes: Int) throws {
        try validate(key)
        guard data.count <= maximumBytes else { throw ServiceFailure.persistence }
        _ = try read(key: key, maximumBytes: maximumBytes)
        let temporary = ".pending-" + UUID().uuidString
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ServiceFailure.persistence }
        defer { Darwin.close(fd); unlinkat(directoryFD, temporary, 0) }
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < data.count {
                let count = Darwin.write(fd, raw.baseAddress!.advanced(by: offset), data.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw ServiceFailure.persistence }
                offset += count
            }
        }
        guard fsync(fd) == 0 else { throw ServiceFailure.persistence }
        try validate(key)
        guard renameat(directoryFD, temporary, directoryFD, key) == 0, fsync(directoryFD) == 0 else {
            throw ServiceFailure.persistence
        }
    }

    private func validate(_ key: String) throws {
        guard directoryFD >= 0, lockFD >= 0, !key.isEmpty, key.utf8.count <= 128,
              key.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }),
              key.first != "." else { throw ServiceFailure.persistence }
        let current = try BoundedUSTAR.openDirectory(directory)
        defer { Darwin.close(current) }
        var before = stat(), now = stat(), held = stat(), visible = stat()
        guard fstat(directoryFD, &before) == 0, fstat(current, &now) == 0,
              before.st_dev == now.st_dev, before.st_ino == now.st_ino,
              now.st_uid == geteuid(), now.st_mode & 0o077 == 0,
              fstat(lockFD, &held) == 0,
              fstatat(directoryFD, ".writer.lock", &visible, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == visible.st_dev, held.st_ino == visible.st_ino else {
            throw ServiceFailure.persistence
        }
    }
}

/// A private journal directory with one lifetime writer lock and durable atomic file commits.
@MainActor
final class AtomicMaintenanceStorage: PreferenceStorage {
    private let lock: HeldLock
    private let maximumBytes = 1024 * 1024

    init(directory: URL) throws {
        lock = try HeldLock.acquire(directory: directory)
    }

    init(adopting lock: HeldLock) {
        self.lock = lock
    }

    /// Release ownership before an authenticated external maintenance owner opens this journal.
    /// Closed instances cannot read or mutate a journal even if another writer has acquired it.
    func close() { lock.release() }

    func read(key: String) throws -> Data? { try lock.read(key: key, maximumBytes: maximumBytes) }

    func write(_ data: Data, key: String) throws { try lock.write(data, key: key, maximumBytes: maximumBytes) }
}
