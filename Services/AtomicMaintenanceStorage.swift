import Foundation
import Darwin
#if canImport(WattMaintenanceShared)
import WattMaintenanceShared
#endif

/// A private journal directory with one lifetime writer lock and durable atomic file commits.
@MainActor
final class AtomicMaintenanceStorage: PreferenceStorage {
    private let directory: URL
    private var directoryFD: Int32
    private var lockFD: Int32
    private let maximumBytes = 1024 * 1024

    init(directory: URL) throws {
        self.directory = directory
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
        directoryFD = root; lockFD = lock
    }
    deinit { Darwin.close(lockFD); Darwin.close(directoryFD) }

    /// Release ownership before an authenticated external maintenance owner opens this journal.
    /// Closed instances cannot read or mutate a journal even if another writer has acquired it.
    func close() {
        if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
        if directoryFD >= 0 { Darwin.close(directoryFD); directoryFD = -1 }
    }

    private func validate(_ key: String) throws {
        guard directoryFD >= 0, lockFD >= 0, !key.isEmpty, key.utf8.count <= 128,
              key.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }),
              key.first != "." else { throw ServiceFailure.persistence }
        let current = try BoundedUSTAR.openDirectory(directory)
        defer { Darwin.close(current) }
        var before = stat(), now = stat(), heldLock = stat(), visibleLock = stat()
        guard fstat(directoryFD, &before) == 0, fstat(current, &now) == 0,
              before.st_dev == now.st_dev, before.st_ino == now.st_ino,
              now.st_uid == geteuid(), now.st_mode & 0o077 == 0,
              fstat(lockFD, &heldLock) == 0,
              fstatat(directoryFD, ".writer.lock", &visibleLock, AT_SYMLINK_NOFOLLOW) == 0,
              heldLock.st_dev == visibleLock.st_dev, heldLock.st_ino == visibleLock.st_ino else {
            throw ServiceFailure.persistence
        }
    }
    func read(key: String) throws -> Data? {
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
    func write(_ data: Data, key: String) throws {
        try validate(key)
        guard data.count <= maximumBytes else { throw ServiceFailure.persistence }
        // Refuse symlinks, hard links, nonprivate or foreign existing objects rather than replacing them.
        _ = try read(key: key)
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
}
