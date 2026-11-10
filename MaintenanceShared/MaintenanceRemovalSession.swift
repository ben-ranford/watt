import Darwin
import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Single-owner durable continuation; production callers derive the directory below.
@MainActor
public final class MaintenanceRemovalSession {
    public struct Record: Codable, Equatable, Sendable {
        public enum Phase: String, Codable, Sendable { case accepted, removing, completed, interrupted, restored }
        public let request: MaintenanceRequest
        public let plan: MaintenanceRemovalPlan
        public var phase: Phase
    }
    private let directoryURL: URL
    private let directory: Int32
    private let lock: Int32
    public private(set) var record: Record
    private let observation: MaintenanceProcessWitness.LiveObservation
    private let helperAbsence: @MainActor () throws -> Bool

    public static func directory(installationID: UUID) throws -> URL {
        guard let user = getpwuid(getuid()), let home = user.pointee.pw_dir else { throw MaintenanceProtocolError.invalidRequest }
        return URL(fileURLWithPath: String(cString: home)).appendingPathComponent("Library/Application Support")
            .appendingPathComponent("WattMaintenance-" + installationID.uuidString)
    }

    /// Directory injection is for explicitly owned fixture roots; the executable never accepts a path.
    public init(directory url: URL, request: MaintenanceRequest, plan: MaintenanceRemovalPlan,
                helperAbsence fixtureWitness: (@MainActor () throws -> Bool)? = nil) throws {
        try plan.validateLiveParent(request)
        helperAbsence = fixtureWitness ?? { try plan.helperIsAbsent() }
        observation = try MaintenanceProcessWitness.observeLive(pid: request.parent.pid)
        let parent = try BoundedUSTAR.openDirectory(url.deletingLastPathComponent()); defer { close(parent) }
        if mkdirat(parent, url.lastPathComponent, 0o700) != 0 && errno != EEXIST { throw MaintenanceProtocolError.invalidRequest }
        let fd = openat(parent, url.lastPathComponent, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_mode & 0o077 == 0 else {
            close(fd); throw MaintenanceProtocolError.invalidRequest
        }
        let lockFD = openat(fd, ".writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0 else { close(fd); throw MaintenanceProtocolError.invalidRequest }
        guard fstat(lockFD, &st) == 0, st.st_uid == getuid(), st.st_mode & 0o077 == 0,
              st.st_nlink == 1, st.st_mode & S_IFMT == S_IFREG, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            close(lockFD); close(fd); throw MaintenanceProtocolError.invalidRequest
        }
        // Fresh consent may follow a verified rollback; an unresolved receipt is never replayed.
        if fstatat(fd, "continuation.json", &st, AT_SYMLINK_NOFOLLOW) == 0 {
            do {
                let previous = try Self.read(directoryDescriptor: fd)
                guard previous.phase == .restored, previous.request.receipt.id != request.receipt.id,
                      renameatx_np(fd, "continuation.json", fd,
                          "restored-" + previous.request.receipt.id.uuidString + ".json", UInt32(RENAME_EXCL)) == 0,
                      fsync(fd) == 0 else { throw MaintenanceProtocolError.invalidRequest }
            } catch { close(lockFD); close(fd); throw error }
        } else if errno != ENOENT {
            close(lockFD); close(fd); throw MaintenanceProtocolError.invalidRequest
        }
        directoryURL = url; directory = fd; lock = lockFD
        record = Record(request: request, plan: plan, phase: .accepted)
        try persist()
    }
    deinit { close(lock); close(directory) }

    private init(directoryURL: URL, directory: Int32, lock: Int32, record: Record,
                 observer: MaintenanceProcessWitness.LiveObservation) {
        self.directoryURL = directoryURL; self.directory = directory; self.lock = lock
        self.record = record; self.observation = observer
        self.helperAbsence = { try record.plan.helperIsAbsent() }
    }

    /// Explicit rollback from a newly authenticated actual bundle/companion. This does
    /// not resume deletion consent, reconstruct the original live witness, or overwrite
    /// intervening objects. Protected rollback restores user configuration only.
    public static func recover(directory url: URL, receipt: MaintenanceReceipt,
                               observer: MaintenanceProcessWitness.LiveObservation) throws -> Record {
        let dir = try BoundedUSTAR.openDirectory(url)
        var status = stat()
        guard fstat(dir, &status) == 0, status.st_uid == getuid(), status.st_mode & 0o077 == 0 else {
            close(dir); throw MaintenanceProtocolError.invalidRequest
        }
        let lockFD = openat(dir, ".writer.lock", O_RDWR | O_NOFOLLOW | O_CLOEXEC)
        guard lockFD >= 0 else { close(dir); throw MaintenanceProtocolError.invalidRequest }
        guard fstat(lockFD, &status) == 0, status.st_uid == getuid(), status.st_nlink == 1,
              status.st_mode & S_IFMT == S_IFREG, status.st_mode & 0o077 == 0,
              flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            close(lockFD); close(dir); throw MaintenanceProtocolError.invalidRequest
        }
        var transferred = false
        do {
            let value = try read(directoryDescriptor: dir)
            guard value.request.receipt == receipt, value.phase != .restored else { throw MaintenanceProtocolError.invalidRequest }
            let session = Self(directoryURL: url, directory: dir, lock: lockFD, record: value, observer: observer)
            transferred = true
            try session.validateOwnership()
            try value.plan.restore(receipt: receipt, observer: observer)
            session.record.phase = value.plan.protectedRecord == nil ? .restored : .interrupted
            try session.persist()
            return session.record
        } catch {
            if !transferred { close(lockFD); close(dir) }
            throw error
        }
    }

    public func finish(timeout: TimeInterval = 30, administratorTimeout: TimeInterval = 300) async throws {
        guard record.phase == .accepted else { throw MaintenanceProtocolError.invalidRequest }
        do {
            guard try await observation.waitForExit(timeout: timeout) else { throw MaintenanceProtocolError.invalidRequest }
            record.phase = .removing; try persist()
            if record.plan.protectedRecord == nil {
                guard try helperAbsence() else { throw MaintenanceProtocolError.invalidRequest }
            }
            try record.plan.removeAfterExit(observation, receipt: record.request.receipt)
            if record.plan.protectedRecord != nil {
                guard administratorTimeout > 0, administratorTimeout <= 3600 else { throw MaintenanceProtocolError.invalidRequest }
                let deadline = ContinuousClock.now.advanced(by: .milliseconds(Int64(administratorTimeout * 1000)))
                var verified = false
                while ContinuousClock.now < deadline {
                    try Task.checkCancellation()
                    // Missing result remains pending. A result that exists but cannot authenticate
                    // or correlate is an error, not a polling excuse to accept another generation.
                    var metadata = stat()
                    if lstat(ProtectedHelperRecord.maintenanceResultURL.path, &metadata) == 0 {
                        if try record.plan.protectedRemovalVerified(receipt: record.request.receipt) { verified = true; break }
                    } else if errno != ENOENT { throw MaintenanceProtocolError.invalidRequest }
                    try await Task.sleep(for: .milliseconds(200))
                }
                guard verified else { throw MaintenanceProtocolError.invalidRequest }
            }
            guard try record.plan.isAbsent(), try observation.hasExited(), try helperAbsence() else { throw MaintenanceProtocolError.invalidRequest }
            record.phase = .completed; try persist()
        } catch {
            record.phase = .interrupted; try? persist(); throw error
        }
    }

    private func validateOwnership() throws {
        let visible = try BoundedUSTAR.openDirectory(directoryURL); defer { close(visible) }
        var held = stat(), current = stat(), heldLock = stat(), currentLock = stat()
        guard fstat(directory, &held) == 0, fstat(visible, &current) == 0,
              held.st_dev == current.st_dev, held.st_ino == current.st_ino,
              current.st_uid == getuid(), current.st_mode & 0o077 == 0,
              fstat(lock, &heldLock) == 0, fstatat(directory, ".writer.lock", &currentLock, AT_SYMLINK_NOFOLLOW) == 0,
              heldLock.st_dev == currentLock.st_dev, heldLock.st_ino == currentLock.st_ino else {
            throw MaintenanceProtocolError.invalidRequest
        }
    }

    private func persist() throws {
        try validateOwnership()
        let bytes = try JSONEncoder().encode(record)
        guard bytes.count <= 2_097_152 else { throw MaintenanceProtocolError.oversized }
        let temporary = ".continuation-" + UUID().uuidString
        let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { close(fd); unlinkat(directory, temporary, 0) }
        try bytes.withUnsafeBytes { raw in
            var offset = 0
            while offset < bytes.count {
                let count = write(fd, raw.baseAddress!.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { throw MaintenanceProtocolError.invalidRequest }; offset += count
            }
        }
        guard fsync(fd) == 0, renameat(directory, temporary, directory, "continuation.json") == 0,
              fsync(directory) == 0 else { throw MaintenanceProtocolError.invalidRequest }
    }

    public static func read(directory url: URL) throws -> Record {
        let dir = try BoundedUSTAR.openDirectory(url); defer { close(dir) }
        var status = stat()
        guard fstat(dir, &status) == 0, status.st_uid == getuid(), status.st_mode & 0o077 == 0 else {
            throw MaintenanceProtocolError.invalidRequest
        }
        return try read(directoryDescriptor: dir)
    }
    private static func read(directoryDescriptor dir: Int32) throws -> Record {
        let fd = openat(dir, "continuation.json", O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }; defer { close(fd) }
        var st = stat()
        guard fstat(fd, &st) == 0, st.st_uid == getuid(), st.st_nlink == 1,
              st.st_mode & S_IFMT == S_IFREG, st.st_mode & 0o077 == 0,
              st.st_size > 0, st.st_size <= 2_097_152 else { throw MaintenanceProtocolError.invalidRequest }
        var bytes = [UInt8](repeating: 0, count: Int(st.st_size)); var offset = 0
        while offset < bytes.count {
            let remaining = bytes.count - offset
            let n = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!.advanced(by: offset), remaining) }
            guard n > 0 else { throw MaintenanceProtocolError.invalidRequest }; offset += n
        }
        let value = try JSONDecoder().decode(Record.self, from: Data(bytes))
        try value.request.validate()
        guard value.request.removalPlanSHA256 == (try value.plan.digest),
              value.request.parent == value.plan.parent,
              value.request.installationID == value.plan.installationID,
              value.request.generation == value.plan.generation else { throw MaintenanceProtocolError.invalidRequest }
        return value
    }
}
