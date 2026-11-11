import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

public enum ArchiveValidationError: Error { case invalidArchive, unsafeDestination, ioFailure }

/// The single release archive profile. The entire immutable input is checked before extraction.
public struct BoundedUSTAR: Sendable {
    public static let maximumBytes = 256 * 1024 * 1024
    public static let maximumEntries = 10_000
    public static let maximumPathBytes = 4096
    public static let maximumDepth = 64
    public struct Entry: Sendable {
        public let path: String
        public let isDirectory: Bool
        public let size: Int
        public let executable: Bool
        fileprivate let offset: Int
    }
    private let bytes: Data
    public let entries: [Entry]

    public init(validating input: Data) throws {
        guard input.count <= Self.maximumBytes, input.count >= 1024, input.count % 512 == 0 else {
            throw ArchiveValidationError.invalidArchive
        }
        let bytes = Data(input)
        var offset = 0, total = 0
        var entries: [Entry] = [], names = Set<String>()
        var foundEnd = false
        while offset + 512 <= bytes.count {
            let header = Array(bytes[offset..<(offset + 512)])
            if header.allSatisfy({ $0 == 0 }) {
                guard offset + 1024 <= bytes.count,
                      bytes[offset...].allSatisfy({ $0 == 0 }) else { throw ArchiveValidationError.invalidArchive }
                foundEnd = true
                break
            }
            guard entries.count < Self.maximumEntries,
                  Array(header[257..<263]) == [117,115,116,97,114,0],
                  Array(header[263..<265]) == [48,48],
                  header[500..<512].allSatisfy({ $0 == 0 }) else { throw ArchiveValidationError.invalidArchive }
            let expected = try Self.octal(header[148..<156])
            let sum = header.enumerated().reduce(0) { $0 + ((148..<156).contains($1.offset) ? 32 : Int($1.element)) }
            guard expected == sum else { throw ArchiveValidationError.invalidArchive }
            let mode = try Self.octal(header[100..<108])
            _ = try Self.octal(header[108..<116]); _ = try Self.octal(header[116..<124])
            let size = try Self.octal(header[124..<136])
            _ = try Self.octal(header[136..<148])
            // USTAR device fields may be all NUL for non-device entries.
            _ = try Self.octal(header[329..<337], allowEmpty: true)
            _ = try Self.octal(header[337..<345], allowEmpty: true)
            let type = header[156]
            guard [UInt8(0), 48, 53].contains(type),
                  header[157..<257].allSatisfy({ $0 == 0 }),
                  size <= Self.maximumBytes, total <= Self.maximumBytes - size else { throw ArchiveValidationError.invalidArchive }
            let prefix = try Self.string(header[345..<500]), name = try Self.string(header[0..<100])
            var path = prefix.isEmpty ? name : prefix + "/" + name
            let directory = type == 53
            if directory && path.hasSuffix("/") { path.removeLast() }
            let components = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.isEmpty, path.utf8.count <= Self.maximumPathBytes,
                  components.count <= Self.maximumDepth,
                  components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  !path.contains("\\"), !path.utf8.contains(where: { $0 < 32 || $0 == 127 }),
                  names.insert(Self.canonicalPath(path)).inserted, !directory || size == 0 else { throw ArchiveValidationError.invalidArchive }
            let dataStart = offset + 512
            guard size <= bytes.count - dataStart else { throw ArchiveValidationError.invalidArchive }
            let padding = (512 - size % 512) % 512
            guard padding <= bytes.count - dataStart - size,
                  bytes[(dataStart + size)..<(dataStart + size + padding)].allSatisfy({ $0 == 0 }) else {
                throw ArchiveValidationError.invalidArchive
            }
            entries.append(Entry(path: path, isDirectory: directory, size: size, executable: mode & 0o111 != 0, offset: dataStart))
            total += size; offset = dataStart + size + padding
        }
        guard foundEnd, !entries.isEmpty else { throw ArchiveValidationError.invalidArchive }
        let types = Dictionary(uniqueKeysWithValues: entries.map { (Self.canonicalPath($0.path), $0.isDirectory) })
        for entry in entries {
            var parts = entry.path.split(separator: "/")
            while parts.count > 1 {
                parts.removeLast()
                if types[Self.canonicalPath(parts.joined(separator: "/"))] == false { throw ArchiveValidationError.invalidArchive }
            }
        }
        self.bytes = bytes; self.entries = entries
    }

    private static func canonicalPath(_ path: String) -> String {
        path.precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func string(_ field: ArraySlice<UInt8>) throws -> String {
        let raw = Array(field), end = raw.firstIndex(of: 0) ?? raw.count
        guard raw[end...].allSatisfy({ $0 == 0 }), let result = String(bytes: raw[..<end], encoding: .utf8) else {
            throw ArchiveValidationError.invalidArchive
        }
        return result
    }
    private static func octal(_ field: ArraySlice<UInt8>, allowEmpty: Bool = false) throws -> Int {
        let raw = Array(field)
        var end = raw.count
        while end > 0 && (raw[end - 1] == 0 || raw[end - 1] == 32) { end -= 1 }
        guard end > 0 || allowEmpty else { throw ArchiveValidationError.invalidArchive }
        var value = 0
        for digit in raw[..<end] {
            guard (48...55).contains(digit), value <= (Int.max - Int(digit - 48)) / 8 else {
                throw ArchiveValidationError.invalidArchive
            }
            value = value * 8 + Int(digit - 48)
        }
        return value
    }

    /// Parent must already be private and owned by this process. Destination must not exist.
    public func extract(intoFreshDirectory destination: URL) throws {
        let parent = destination.deletingLastPathComponent()
        let parentFD = try Self.openDirectory(parent)
        defer { close(parentFD) }
        var metadata = stat()
        guard fstat(parentFD, &metadata) == 0, metadata.st_uid == geteuid(), metadata.st_mode & 0o077 == 0 else {
            throw ArchiveValidationError.unsafeDestination
        }
        let name = destination.lastPathComponent
        guard name != ".", name != "..", !name.isEmpty,
              mkdirat(parentFD, name, 0o700) == 0 else { throw ArchiveValidationError.unsafeDestination }
        let root = openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard root >= 0 else { throw ArchiveValidationError.unsafeDestination }
        defer { close(root) }
        for entry in entries {
            let parts = entry.path.split(separator: "/").map(String.init)
            var directory = dup(root)
            guard directory >= 0 else { throw ArchiveValidationError.ioFailure }
            defer { close(directory) }
            for component in parts.dropLast() {
                if mkdirat(directory, component, 0o700) != 0 && errno != EEXIST { throw ArchiveValidationError.ioFailure }
                guard fsync(directory) == 0 else { throw ArchiveValidationError.ioFailure }
                let next = openat(directory, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw ArchiveValidationError.unsafeDestination }
                close(directory); directory = next
            }
            let leaf = parts.last!
            if entry.isDirectory {
                if mkdirat(directory, leaf, 0o700) != 0 && errno != EEXIST { throw ArchiveValidationError.ioFailure }
                let fd = openat(directory, leaf, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard fd >= 0 else { throw ArchiveValidationError.unsafeDestination }
                close(fd)
            } else {
                let fd = openat(directory, leaf, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, entry.executable ? 0o700 : 0o600)
                guard fd >= 0 else { throw ArchiveValidationError.unsafeDestination }
                defer { close(fd) }
                try bytes.withUnsafeBytes { raw in
                    var written = 0
                    while written < entry.size {
                        let count = Darwin.write(fd, raw.baseAddress!.advanced(by: entry.offset + written), entry.size - written)
                        if count < 0 && errno == EINTR { continue }
                        guard count > 0 else { throw ArchiveValidationError.ioFailure }
                        written += count
                    }
                }
                guard fsync(fd) == 0 else { throw ArchiveValidationError.ioFailure }
            }
            guard fsync(directory) == 0 else { throw ArchiveValidationError.ioFailure }
        }
        guard fsync(root) == 0, fsync(parentFD) == 0 else { throw ArchiveValidationError.ioFailure }
    }

    /// Walk each component so a symlink in any ancestor cannot redirect extraction.
    /// A privacy-protected component is refused before `openat`. That syscall is what
    /// stalls the main thread when Watt is launched from `~/Downloads`: the walk holds
    /// a directory fd on `$HOME` and blocks in `openat(..., "Downloads")` inside TCC.
    public static func openDirectory(_ url: URL, home: String = NSHomeDirectory()) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/") else { throw ArchiveValidationError.unsafeDestination }
        if LaunchPathPolicy.isPrivacyProtected(path: url.path, home: home) {
            throw ArchiveValidationError.unsafeDestination
        }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw ArchiveValidationError.ioFailure }
        var built = ""
        do {
            for component in url.path.split(separator: "/") {
                guard component != ".", component != ".." else { throw ArchiveValidationError.unsafeDestination }
                let nextPath = built + "/" + component
                if LaunchPathPolicy.isPrivacyProtected(path: nextPath, home: home) {
                    throw ArchiveValidationError.unsafeDestination
                }
                let next = openat(fd, String(component), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                guard next >= 0 else { throw ArchiveValidationError.unsafeDestination }
                close(fd); fd = next
                built = nextPath
            }
            return fd
        } catch { close(fd); throw error }
    }
}
