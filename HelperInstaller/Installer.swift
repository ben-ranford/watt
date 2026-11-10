import Foundation
import Darwin
import CryptoKit
#if SWIFT_PACKAGE
import WattHelperShared
import WattMaintenanceShared
#endif

/// Explicit administrator entry point. It has no IPC or arbitrary destination/command interface.
/// Preflight copies into a private staging object before inspecting any code identity.
enum InstallerError: Error { case usage, unsafeFile, refused, interrupted, approvalMismatch }
struct Inventory: Codable, Equatable {
    let treeSHA256: String
    let appHashes: [Data]
    let helperHashes: [Data]
    let maintenanceHashes: [Data]
    let build: UInt64
    var approval: String { get throws { SHA256.hash(data: try JSONEncoder.sorted.encode(self)).map { String(format: "%02x", $0) }.joined() } }
}
private extension JSONEncoder {
    static var sorted: JSONEncoder { let value = JSONEncoder(); value.outputFormatting = [.sortedKeys]; return value }
}
private struct Journal: Codable {
    let installationID: UUID
    let generation: UInt64
    let previous: ProtectedHelperRecord?
    let next: ProtectedHelperRecord
    var phase: String
    var action = "install"
    var generations: [ProtectedHelperRecord] = []
    var maintenanceBinding: ProtectedMaintenanceBinding?
}
/// The CLI uses only production. Tests inject filesystem/launchd authority at this
/// boundary; there are no command-line switches for alternative paths or ownership.
struct InstallerEnvironment {
    var root: URL
    var helperURL: URL
    var plistURL: URL
    var owner: uid_t
    var launchd: (([String]) throws -> Void)?
    var stopped: (([String], Bool) throws -> Void)?
    var journalCheckpoint: ((String) throws -> Void)?
    static var production: Self {
        Self(root: ProtectedHelperRecord.directory, helperURL: ProtectedHelperRecord.helperURL,
             plistURL: ProtectedHelperRecord.plistURL, owner: 0)
    }
}
@MainActor var installerEnvironment = InstallerEnvironment.production
@MainActor private let fm = FileManager.default
private func itemExists(_ path: String) -> Bool {
    var information = stat()
    if lstat(path, &information) == 0 { return true }
    return errno != ENOENT // uncertainty must take the validating/refusal branch
}
@MainActor private var root: URL { installerEnvironment.root }
@MainActor private var journalURL: URL { root.appendingPathComponent("installer-journal.json") }
@MainActor private var publicURL: URL { root.appendingPathComponent("helper-trust.json") }
@MainActor private var helperURL: URL { installerEnvironment.helperURL }
@MainActor private var plistURL: URL { installerEnvironment.plistURL }
@MainActor private var maintenanceResultURL: URL { root.deletingLastPathComponent().appendingPathComponent("Watt-maintenance-result.json") }
@MainActor private func applicationURL(_ record: ProtectedHelperRecord) -> URL {
    root.appendingPathComponent("generations/\(record.installationID.uuidString)-\(record.generation)/Watt.app")
}
@MainActor private func readRecord(at url: URL? = nil, expectedInstallationID: UUID? = nil) throws -> ProtectedHelperRecord {
    try ProtectedHelperRecord.read(at: url ?? publicURL, expectedInstallationID: expectedInstallationID, requiredOwner: installerEnvironment.owner)
}
@MainActor private func protectedFile(_ url: URL) throws -> Int32 {
    try ProtectedHelperRecord.openProtectedFile(at: url, requiredOwner: installerEnvironment.owner)
}
@MainActor private func protectedData(_ url: URL) throws -> Data {
    try ProtectedHelperRecord.readProtectedFile(at: url, requiredOwner: installerEnvironment.owner)
}
@MainActor private func persistJournal(_ journal: Journal) throws {
    let bytes = try JSONEncoder.sorted.encode(journal)
    guard bytes.count <= 65536 else { throw InstallerError.refused }
    try durableWrite(bytes, to: journalURL, mode: 0o600)
    try installerEnvironment.journalCheckpoint?(journal.phase)
}

@MainActor private func ensureDirectory(_ url: URL, mode: mode_t = 0o755) throws {
    if mkdir(url.path, mode) != 0 && errno != EEXIST { throw InstallerError.unsafeFile }
    let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_DIRECTORY | O_CLOEXEC)
    guard fd >= 0 else { throw InstallerError.unsafeFile }
    defer { close(fd) }
    var value = stat()
    guard fstat(fd, &value) == 0, value.st_uid == geteuid(), value.st_mode & 0o022 == 0 else { throw InstallerError.unsafeFile }
}

@MainActor private func durableWrite(_ data: Data, to url: URL, mode: mode_t) throws {
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".write-" + UUID().uuidString)
    let fd = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode)
    guard fd >= 0 else { throw InstallerError.unsafeFile }
    defer { close(fd); _ = unlink(temporary.path) }
    let result = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
    guard result == data.count, fsync(fd) == 0, rename(temporary.path, url.path) == 0 else { throw InstallerError.interrupted }
    let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard parent >= 0 else { throw InstallerError.interrupted }
    defer { close(parent) }
    guard fsync(parent) == 0 else { throw InstallerError.interrupted }
}

/// Source descriptors are never followed through links. Mixed/raced input must still match
/// the administrator's approved complete-tree digest and every executable signature.
@MainActor func stage(_ source: URL, at destination: URL) throws -> String {
    var input = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard input >= 0 else { throw InstallerError.unsafeFile }
    do {
        for component in source.pathComponents.dropFirst() {
            guard component != "..", component != "." else { throw InstallerError.unsafeFile }
            let next = openat(input, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { throw InstallerError.unsafeFile }
            close(input); input = next
        }
    } catch { close(input); throw error }
    defer { close(input) }
    try ensureDirectory(destination, mode: 0o700)
    var entries = 0, total = 0
    var digest = SHA256()
    func copy(_ directory: Int32, _ target: URL, _ relative: String, _ depth: Int) throws {
        guard depth <= 64, let stream = fdopendir(dup(directory)) else { throw InstallerError.unsafeFile }
        defer { closedir(stream) }
        var names: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
            }
            if name != "." && name != ".." {
                guard names.count + entries < 10000 else { throw InstallerError.unsafeFile }
                names.append(name)
            }
        }
        for name in names.sorted() {
            entries += 1
            let path = relative + "/" + name
            guard entries <= 10000, path.utf8.count <= 4096, !name.contains("/"), !name.isEmpty else { throw InstallerError.unsafeFile }
            let fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw InstallerError.unsafeFile }
            defer { close(fd) }
            var info = stat()
            guard fstat(fd, &info) == 0 else { throw InstallerError.unsafeFile }
            let url = target.appendingPathComponent(name)
            digest.update(data: Data(path.utf8)); digest.update(data: Data([0]))
            if info.st_mode & S_IFMT == S_IFDIR {
                digest.update(data: Data("directory\0".utf8))
                try ensureDirectory(url)
                try copy(fd, url, path, depth + 1)
            } else {
                guard info.st_mode & S_IFMT == S_IFREG, info.st_nlink == 1,
                      info.st_size >= 0, info.st_size <= 256 * 1024 * 1024 else { throw InstallerError.unsafeFile }
                total += Int(info.st_size)
                guard total <= 256 * 1024 * 1024 else { throw InstallerError.unsafeFile }
                let mode: mode_t = info.st_mode & 0o111 == 0 ? 0o644 : 0o755
                digest.update(data: Data("file:\(mode):\(info.st_size)\0".utf8))
                let output = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode)
                guard output >= 0 else { throw InstallerError.unsafeFile }
                defer { close(output) }
                var remaining = Int(info.st_size), buffer = [UInt8](repeating: 0, count: 65536)
                while remaining > 0 {
                    let count = Darwin.read(fd, &buffer, min(remaining, buffer.count))
                    guard count > 0 else { throw InstallerError.unsafeFile }
                    let data = Data(buffer.prefix(count)); digest.update(data: data)
                    let written = data.withUnsafeBytes { Darwin.write(output, $0.baseAddress, $0.count) }
                    guard written == count else { throw InstallerError.interrupted }
                    remaining -= count
                }
                var extra: UInt8 = 0
                guard Darwin.read(fd, &extra, 1) == 0, fsync(output) == 0 else { throw InstallerError.unsafeFile }
            }
        }
        let targetFD = open(target.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard targetFD >= 0 else { throw InstallerError.interrupted }
        defer { close(targetFD) }
        guard fsync(targetFD) == 0 else { throw InstallerError.interrupted }
    }
    try copy(input, destination, "", 0)
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
}

@MainActor func inventory(_ app: URL, tree: String) throws -> Inventory {
    let macOS = app.appendingPathComponent("Contents/MacOS")
    let plistData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
    guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
          plist["CFBundleIdentifier"] as? String == HelperIdentity.appIdentifier,
          plist["CFBundleExecutable"] as? String == "Watt",
          let buildText = plist["CFBundleVersion"] as? String, let build = UInt64(buildText), build > 0 else { throw InstallerError.refused }
    let appHashes = try ExactCodeIdentity.allHashes(at: macOS.appendingPathComponent("Watt"), identifier: HelperIdentity.appIdentifier)
    _ = try ExactCodeIdentity.verify(at: app, requirement: ExactCodeIdentity.requirement(hashes: appHashes, identifier: HelperIdentity.appIdentifier))
    let helperHashes = try ExactCodeIdentity.allHashes(at: macOS.appendingPathComponent("WattHelper"), identifier: HelperIdentity.helperIdentifier)
    let maintenanceHashes = try ExactCodeIdentity.allHashes(at: macOS.appendingPathComponent("WattMaintenance"), identifier: HelperIdentity.appIdentifier + ".maintenance")
    return Inventory(treeSHA256: tree, appHashes: appHashes, helperHashes: helperHashes, maintenanceHashes: maintenanceHashes, build: build)
}

@MainActor private func launchctl(_ arguments: [String], allowAbsent: Bool = false) throws {
    if let launchd = installerEnvironment.launchd { try launchd(arguments); return }
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 || (allowAbsent && process.terminationStatus == 3) else { throw InstallerError.interrupted }
}

@MainActor private func requireStopped(applicationPaths: [String] = [], includeHelper: Bool = true) throws {
    if let stopped = installerEnvironment.stopped { try stopped(applicationPaths, includeHelper); return }
    let deadline = Date().addingTimeInterval(5)
    repeat {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0, estimate < 32640 else { throw InstallerError.interrupted }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 128)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard count > 0, count < pids.count else { throw InstallerError.interrupted }
        var found = false
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var bytes = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
            errno = 0
            let length = bytes.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
            if length <= 0 {
                if errno == ESRCH { continue }
                // Unknown process identity is not proof of absence.
                throw InstallerError.interrupted
            }
            guard let end = bytes.firstIndex(of: 0), end > 0,
                  let path = String(bytes: bytes[..<end].map { UInt8(bitPattern: $0) }, encoding: .utf8) else { throw InstallerError.interrupted }
            if (includeHelper && (path == helperURL.path || path == "/usr/bin/powermetrics")) || applicationPaths.contains(path) { found = true }
        }
        if !found { return }
        Thread.sleep(forTimeInterval: 0.05)
    } while Date() < deadline
    throw InstallerError.interrupted
}

@MainActor func install(source: URL, approval: String, rotate: Bool) throws {
    guard geteuid() == installerEnvironment.owner else { throw ProtectedTrustError.administratorRequired }
    // Validate all ancestors before creating any owned destination.
    for parent in [root.deletingLastPathComponent(), helperURL.deletingLastPathComponent(), plistURL.deletingLastPathComponent()] {
        let probe = parent.appendingPathComponent(".")
        var current = URL(fileURLWithPath: "/")
        for component in probe.pathComponents.dropFirst() where component != "." {
            current.appendPathComponent(component)
            var info = stat()
            guard lstat(current.path, &info) == 0, (info.st_uid == 0 || info.st_uid == installerEnvironment.owner), info.st_mode & S_IFMT == S_IFDIR,
                  info.st_mode & 0o022 == 0 else { throw InstallerError.unsafeFile }
        }
    }
    try ensureDirectory(root)
    let lockURL = root.appendingPathComponent("installer.lock")
    let lock = open(lockURL.path, O_WRONLY | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard lock >= 0 else { throw InstallerError.unsafeFile }
    defer { close(lock) }
    var lockInfo = stat()
    guard fstat(lock, &lockInfo) == 0, lockInfo.st_uid == installerEnvironment.owner, lockInfo.st_mode & 0o077 == 0,
          lockInfo.st_mode & S_IFMT == S_IFREG, lockInfo.st_nlink == 1,
          flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw InstallerError.interrupted }
    try installLocked(source: source, approval: approval, rotate: rotate)
}

@MainActor private func installLocked(source: URL, approval: String, rotate: Bool, binding: ProtectedMaintenanceBinding? = nil) throws {
    // An interrupted mutation requires explicit recovery, never blind replay.
    guard !itemExists(journalURL.path) else { throw InstallerError.interrupted }
    let previous = itemExists(publicURL.path) ? try readRecord() : nil
    guard rotate == (previous != nil) else { throw InstallerError.refused }
    if previous == nil {
        guard !itemExists(helperURL.path), !itemExists(plistURL.path) else { throw InstallerError.refused }
    }
    let generations = root.appendingPathComponent("generations", isDirectory: true)
    try ensureDirectory(generations)
    let installation = previous?.installationID ?? UUID()
    guard previous?.generation != UInt64.max else { throw InstallerError.refused }
    let generation = (previous?.generation ?? 0) + 1
    let generationRoot = generations.appendingPathComponent("\(installation.uuidString)-\(generation)")
    guard !itemExists(generationRoot.path) else { throw InstallerError.refused }
    try ensureDirectory(generationRoot)
    var journalOwnsGeneration = false
    defer { if !journalOwnsGeneration && !itemExists(journalURL.path) { try? fm.removeItem(at: generationRoot) } }
    let app = generationRoot.appendingPathComponent("Watt.app")
    let tree = try stage(source, at: app)
    let candidate = try inventory(app, tree: tree)
    guard try candidate.approval == approval else { throw InstallerError.approvalMismatch }
    guard previous == nil || candidate.build > previous!.build else { throw InstallerError.refused }
    let record = try ProtectedHelperRecord(installationID: installation, generation: generation, build: candidate.build,
                                          appHashes: candidate.appHashes, helperHashes: candidate.helperHashes, maintenanceHashes: candidate.maintenanceHashes, maintenanceBinding: binding)
    if let binding {
        guard let previous, binding.previousGeneration == previous.generation,
              binding.installationID == previous.installationID else { throw InstallerError.refused }
        try checkUnused(binding)
    }
    var journal = Journal(installationID: installation, generation: generation, previous: previous, next: record, phase: "staged")
    guard chmod(app.path, 0o755) == 0 else { throw InstallerError.unsafeFile }
    try persistJournal(journal)
    journalOwnsGeneration = true
    try finishInstall(&journal)
}

@MainActor private func finishInstall(_ journal: inout Journal) throws {
    let record = journal.next
    try record.validate()
    let stagedRecordURL = applicationURL(record).deletingLastPathComponent().appendingPathComponent("record.json")
    if itemExists(stagedRecordURL.path) {
        guard try readRecord(at: stagedRecordURL, expectedInstallationID: record.installationID) == record else { throw InstallerError.refused }
    }
    if let previous = journal.previous {
        let previousURL = applicationURL(previous).deletingLastPathComponent().appendingPathComponent("record.json")
        guard try readRecord(at: previousURL, expectedInstallationID: previous.installationID) == previous else { throw InstallerError.refused }
    }
    if let binding = record.maintenanceBinding { try claimReceipt(binding, recovering: true) }
    if itemExists(publicURL.path) {
        let active = try readRecord()
        guard active == journal.previous || active == record else { throw InstallerError.refused }
    } else if journal.previous != nil { throw InstallerError.refused }
    if itemExists(helperURL.path) {
        let fd = try protectedFile(helperURL); close(fd)
        let allowed = record.helperHashes + (journal.previous?.helperHashes ?? [])
        _ = try ExactCodeIdentity.verify(at: helperURL, requirement: ExactCodeIdentity.requirement(hashes: Array(Set(allowed)), identifier: HelperIdentity.helperIdentifier))
    } else if journal.previous != nil { throw InstallerError.refused }
    if itemExists(plistURL.path) {
        let data = try protectedData(plistURL)
        guard let fields = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              Set(fields.keys) == Set(["Label", "ProgramArguments", "MachServices", "UserName"]),
              fields["Label"] as? String == HelperIdentity.helperIdentifier,
              fields["ProgramArguments"] as? [String] == [helperURL.path],
              fields["MachServices"] as? [String: Bool] == [HelperIdentity.machService: true],
              fields["UserName"] as? String == "root" else { throw InstallerError.refused }
    } else if journal.previous != nil { throw InstallerError.refused }
    let lockPath = root.appendingPathComponent("installer.lock")
    let checkedLock = try protectedFile(lockPath); close(checkedLock)
    let lock = open(lockPath.path, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
    guard lock >= 0 else { throw InstallerError.unsafeFile }
    defer { close(lock) }
    let binding = try JSONEncoder.sorted.encode(record)
    guard ftruncate(lock, 0) == 0,
          binding.withUnsafeBytes({ pwrite(lock, $0.baseAddress, $0.count, 0) }) == binding.count,
          fsync(lock) == 0 else { throw InstallerError.interrupted }
    let app = applicationURL(record)
    // Recovery revalidates the staged immutable generation against protected pins.
    let hashes = try ExactCodeIdentity.allHashes(at: app.appendingPathComponent("Contents/MacOS/Watt"), identifier: HelperIdentity.appIdentifier)
    guard Set(hashes) == Set(record.appHashes) else { throw InstallerError.refused }
    _ = try ExactCodeIdentity.verify(at: app, requirement: ExactCodeIdentity.requirement(hashes: record.appHashes, identifier: HelperIdentity.appIdentifier))
    let helperHashes = try ExactCodeIdentity.allHashes(at: app.appendingPathComponent("Contents/MacOS/WattHelper"), identifier: HelperIdentity.helperIdentifier)
    let maintenanceHashes = try ExactCodeIdentity.allHashes(at: app.appendingPathComponent("Contents/MacOS/WattMaintenance"), identifier: HelperIdentity.appIdentifier + ".maintenance")
    guard Set(helperHashes) == Set(record.helperHashes), Set(maintenanceHashes) == Set(record.maintenanceHashes) else { throw InstallerError.refused }
    try launchctl(["bootout", "system/" + HelperIdentity.helperIdentifier], allowAbsent: true)
    try requireStopped()
    journal.phase = "stopped"; try persistJournal(journal)
    let helper = applicationURL(record).appendingPathComponent("Contents/MacOS/WattHelper")
    let helperData = try Data(contentsOf: helper)
    try durableWrite(helperData, to: helperURL, mode: 0o755)
    _ = try ExactCodeIdentity.verify(at: helperURL, requirement: ExactCodeIdentity.requirement(hashes: record.helperHashes, identifier: HelperIdentity.helperIdentifier))
    let plist: [String: Any] = ["Label": HelperIdentity.helperIdentifier, "ProgramArguments": [helperURL.path],
                               "MachServices": [HelperIdentity.machService: true], "UserName": "root"]
    try durableWrite(PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0), to: plistURL, mode: 0o644)
    let generationRecordURL = applicationURL(record).deletingLastPathComponent().appendingPathComponent("record.json")
    if itemExists(generationRecordURL.path) {
        // Recovery can reuse the exact immutable record; never repin a prior generation.
        guard try readRecord(at: generationRecordURL, expectedInstallationID: record.installationID) == record else { throw InstallerError.refused }
    } else {
        try durableWrite(JSONEncoder.sorted.encode(record), to: generationRecordURL, mode: 0o644)
    }
    journal.phase = "placed"; try persistJournal(journal)
    try durableWrite(JSONEncoder.sorted.encode(record), to: publicURL, mode: 0o644)
    journal.phase = "activated"; try persistJournal(journal)
    try launchctl(["bootstrap", "system", plistURL.path])
    journal.phase = "complete"; try persistJournal(journal)
    guard unlink(journalURL.path) == 0 else { throw InstallerError.interrupted }
    print("Installed protected generation \(record.generation). Application: \(applicationURL(record).path)")
}

@MainActor private func withInstallationLock(_ body: () throws -> Void) throws {
    guard geteuid() == installerEnvironment.owner else { throw ProtectedTrustError.administratorRequired }
    let fd = try protectedFile(root.appendingPathComponent("installer.lock"))
    defer { close(fd) }
    var information = stat()
    guard fstat(fd, &information) == 0, information.st_mode & 0o077 == 0,
          flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw InstallerError.interrupted }
    try body()
}

@MainActor func recover(installation: UUID, generation: UInt64) throws {
    guard geteuid() == installerEnvironment.owner else { throw ProtectedTrustError.administratorRequired }
    if !itemExists(journalURL.path), !itemExists(publicURL.path),
       !itemExists(helperURL.path), !itemExists(plistURL.path) {
        let entries = try fm.contentsOfDirectory(atPath: root.path)
        guard generation <= 1000, Set(entries).isSubset(of: ["installer.lock"]) else { throw InstallerError.interrupted }
        if !entries.isEmpty {
            let binding = try JSONDecoder().decode(ProtectedHelperRecord.self, from: protectedData(root.appendingPathComponent("installer.lock")))
            guard binding.installationID == installation, binding.generation == generation else { throw InstallerError.refused }
        }
        let paths = (1...generation).map { root.appendingPathComponent("generations/\(installation.uuidString)-\($0)/Watt.app/Contents/MacOS/Watt").path }
        try requireStopped(applicationPaths: paths)
        if !entries.isEmpty { guard unlink(root.appendingPathComponent("installer.lock").path) == 0 else { throw InstallerError.interrupted } }
        guard rmdir(root.path) == 0 else { throw InstallerError.interrupted }
        return
    }
    try withInstallationLock {
        let descriptor = try protectedFile(journalURL)
        var information = stat()
        let status = fstat(descriptor, &information); close(descriptor)
        guard status == 0, information.st_mode & 0o077 == 0 else { throw InstallerError.unsafeFile }
        var journal = try JSONDecoder().decode(Journal.self, from: protectedData(journalURL))
        guard journal.installationID == installation, journal.generation == generation,
              journal.next.installationID == installation, journal.next.generation == generation else { throw InstallerError.refused }
        try journal.next.validate()
        if journal.action == "install" { try finishInstall(&journal) }
        else if journal.action == "removeHelper" || journal.action == "uninstall" { try finishRemoval(&journal) }
        else { throw InstallerError.refused }
    }
}

@MainActor func removeHelper(installation: UUID, generation: UInt64, uninstall: Bool = false, request: URL? = nil) throws {
    try withInstallationLock {
        guard !itemExists(journalURL.path) else { throw InstallerError.interrupted }
        let record: ProtectedHelperRecord
        if itemExists(publicURL.path) { record = try readRecord(expectedInstallationID: installation) }
        else {
            guard uninstall, !itemExists(helperURL.path), !itemExists(plistURL.path) else { throw InstallerError.refused }
            record = try readRecord(at: root.appendingPathComponent("generations/\(installation.uuidString)-\(generation)/record.json"), expectedInstallationID: installation)
        }
        guard record.generation == generation else { throw InstallerError.refused }
        var journal = Journal(installationID: installation, generation: generation, previous: record, next: record, phase: "removalIntent", action: uninstall ? "uninstall" : "removeHelper")
        if let request {
            guard uninstall else { throw InstallerError.refused }
            let staged = root.appendingPathComponent(".maintenance-request-" + UUID().uuidString)
            try copyBoundedInput(request, to: staged, maximum: 16384)
            defer { _ = unlink(staged.path) }
            let binding = try ProtectedMaintenanceBinding.decode(Data(contentsOf: staged))
            guard binding.operation == .uninstall, binding.installationID == installation,
                  binding.previousGeneration == generation, binding.build == record.build else { throw InstallerError.refused }
            try checkUnused(binding)
            journal.maintenanceBinding = binding
        }
        if uninstall {
            let directory = root.appendingPathComponent("generations")
            let names = try fm.contentsOfDirectory(atPath: directory.path)
            guard !names.isEmpty, names.count <= 1000 else { throw InstallerError.refused }
            for name in names {
                guard name.hasPrefix(installation.uuidString + "-"), !name.contains("/") else { throw InstallerError.refused }
                let prior = try readRecord(at: directory.appendingPathComponent(name).appendingPathComponent("record.json"), expectedInstallationID: installation)
                guard prior.generation <= generation, applicationURL(prior).deletingLastPathComponent().lastPathComponent == name else { throw InstallerError.refused }
                _ = try ExactCodeIdentity.verify(at: applicationURL(prior), requirement: ExactCodeIdentity.requirement(hashes: prior.appHashes, identifier: HelperIdentity.appIdentifier))
                let members = try fm.contentsOfDirectory(atPath: applicationURL(prior).deletingLastPathComponent().path)
                guard Set(members) == Set(["Watt.app", "record.json"]) else { throw InstallerError.refused }
                journal.generations.append(prior)
            }
            guard journal.generations.contains(record) else { throw InstallerError.refused }
            // Reject foreign resources before authorizing any destructive stage.
            let owned = Set(["generations", "installer.lock", "helper-trust.json", "release-trust.json", "maintenance-receipts.json"])
            guard Set(try fm.contentsOfDirectory(atPath: root.path)).isSubset(of: owned) else { throw InstallerError.refused }
            try requireStopped(applicationPaths: journal.generations.map { applicationURL($0).appendingPathComponent("Contents/MacOS/Watt").path }, includeHelper: false)
        }
        if itemExists(root.appendingPathComponent("release-trust.json").path) {
            _ = try readReleaseTrust(installation: record.installationID)
        }
        try validateInstalledResources(record)
        try persistJournal(journal)
        try finishRemoval(&journal)
    }
}

@MainActor private func validateInstalledResources(_ record: ProtectedHelperRecord) throws {
    if itemExists(publicURL.path) {
        guard try readRecord() == record else { throw InstallerError.refused }
    }
    if itemExists(helperURL.path) {
        let fd = try protectedFile(helperURL); close(fd)
        _ = try ExactCodeIdentity.verify(at: helperURL, requirement: ExactCodeIdentity.requirement(hashes: record.helperHashes, identifier: HelperIdentity.helperIdentifier))
    }
    if itemExists(plistURL.path) {
        let data = try protectedData(plistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              Set(plist.keys) == Set(["Label", "ProgramArguments", "MachServices", "UserName"]),
              plist["Label"] as? String == HelperIdentity.helperIdentifier,
              plist["ProgramArguments"] as? [String] == [helperURL.path],
              plist["MachServices"] as? [String: Bool] == [HelperIdentity.machService: true],
              plist["UserName"] as? String == "root" else { throw InstallerError.refused }
    }
}

@MainActor private func finishRemoval(_ journal: inout Journal) throws {
    if let binding = journal.maintenanceBinding {
        try binding.validate()
        guard journal.action == "uninstall", binding.operation == .uninstall,
              binding.installationID == journal.installationID, binding.previousGeneration == journal.generation,
              binding.build == journal.next.build else { throw InstallerError.refused }
        try claimReceipt(binding, recovering: true)
    }
    try validateInstalledResources(journal.next)
    try launchctl(["bootout", "system/" + HelperIdentity.helperIdentifier], allowAbsent: true)
    guard journal.next.installationID == journal.installationID, journal.next.generation == journal.generation else { throw InstallerError.refused }
    if journal.action == "uninstall" {
        guard !journal.generations.isEmpty, journal.generations.allSatisfy({ $0.installationID == journal.installationID && $0.generation <= journal.generation }) else { throw InstallerError.refused }
    }
    try requireStopped(applicationPaths: journal.generations.map { applicationURL($0).appendingPathComponent("Contents/MacOS/Watt").path })
    for url in [helperURL, plistURL, publicURL] {
        if itemExists(url.path) {
            let fd = try protectedFile(url); close(fd)
            guard unlink(url.path) == 0 else { throw InstallerError.interrupted }
            let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            guard parent >= 0 else { throw InstallerError.interrupted }
            let result = fsync(parent); close(parent)
            guard result == 0 else { throw InstallerError.interrupted }
        }
    }
    if journal.action == "uninstall" {
        let receiptsURL = root.appendingPathComponent("maintenance-receipts.json")
        if itemExists(receiptsURL.path) { let fd = try protectedFile(receiptsURL); close(fd); guard unlink(receiptsURL.path) == 0 else { throw InstallerError.interrupted } }
        let trustURL = root.appendingPathComponent("release-trust.json")
        if itemExists(trustURL.path) {
            _ = try readReleaseTrust(installation: journal.installationID)
            guard unlink(trustURL.path) == 0 else { throw InstallerError.interrupted }
        }
        // These exact generation destinations were independently validated before
        // journal intent. Interrupted partial deletion resumes from the protected journal.
        for generation in journal.generations {
            let directory = applicationURL(generation).deletingLastPathComponent()
            var info = stat()
            if lstat(directory.path, &info) == 0 {
                guard (info.st_uid == 0 || info.st_uid == installerEnvironment.owner), info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o022 == 0 else { throw InstallerError.unsafeFile }
                try fm.removeItem(at: directory)
            } else if errno != ENOENT { throw InstallerError.unsafeFile }
        }
        let generations = root.appendingPathComponent("generations")
        if rmdir(generations.path) != 0 && errno != ENOENT { throw InstallerError.interrupted }
    }
    if journal.action == "uninstall" {
        guard Set(try fm.contentsOfDirectory(atPath: root.path)) == Set(["installer.lock", "installer-journal.json"]) else { throw InstallerError.interrupted }
    }
    journal.phase = "removed"; try persistJournal(journal)
    if let binding = journal.maintenanceBinding {
        // Evidence binds this receipt but is not itself an absence proof.
        if itemExists(maintenanceResultURL.path) {
            let old = try ProtectedMaintenanceBinding.decode(protectedData(maintenanceResultURL))
            guard old.operation == .uninstall,
                  old == binding || (old.installationID != binding.installationID && old.receipt.id != binding.receipt.id) else { throw InstallerError.refused }
        }
        try durableWrite(JSONEncoder.sorted.encode(binding), to: maintenanceResultURL, mode: 0o644)
    }
    guard unlink(journalURL.path) == 0 else { throw InstallerError.interrupted }
    if journal.action == "uninstall" {
        guard unlink(root.appendingPathComponent("installer.lock").path) == 0,
              rmdir(root.path) == 0 else { throw InstallerError.interrupted }
        print("Protected application generations and helper removed after process cessation.")
    } else { print("Helper stopped and protected helper resources removed. Application generations retained.") }
}

private struct UsedMaintenanceReceipt: Codable {
    let receipt: ProtectedMaintenanceReceipt
    let bindingSHA256: Data
}
@MainActor private func usedReceipts() throws -> [UsedMaintenanceReceipt] {
    let url = root.appendingPathComponent("maintenance-receipts.json")
    guard itemExists(url.path) else { return [] }
    let values = try JSONDecoder().decode([UsedMaintenanceReceipt].self, from: protectedData(url))
    guard values.count <= 256, Set(values.map { $0.receipt.id }).count == values.count,
          values.allSatisfy({ $0.receipt.createdAt.timeIntervalSince1970.isFinite && $0.bindingSHA256.count == 32 }) else { throw InstallerError.refused }
    return values
}
@MainActor private func checkUnused(_ binding: ProtectedMaintenanceBinding) throws {
    try binding.validate()
    guard try !usedReceipts().contains(where: { $0.receipt.id == binding.receipt.id }) else { throw InstallerError.refused }
    if itemExists(maintenanceResultURL.path) {
        let prior = try ProtectedMaintenanceBinding.decode(protectedData(maintenanceResultURL))
        guard prior.receipt.id != binding.receipt.id else { throw InstallerError.refused }
    }
}
@MainActor private func claimReceipt(_ binding: ProtectedMaintenanceBinding, recovering: Bool) throws {
    try binding.validate()
    var values = try usedReceipts()
    let hash = Data(SHA256.hash(data: try JSONEncoder.sorted.encode(binding)))
    if let previous = values.first(where: { $0.receipt.id == binding.receipt.id }) {
        guard recovering, previous.receipt == binding.receipt, previous.bindingSHA256 == hash else { throw InstallerError.refused }
        return
    }
    guard values.count < 256 else { throw InstallerError.refused }
    values.append(UsedMaintenanceReceipt(receipt: binding.receipt, bindingSHA256: hash))
    try durableWrite(JSONEncoder.sorted.encode(values), to: root.appendingPathComponent("maintenance-receipts.json"), mode: 0o600)
}

struct InstallerReleaseTrust: Codable {
    let installationID: UUID
    let identity: String
    let publicKey: Data
}
private struct InstallerSignedRelease: Codable { let payload: Data; let signature: Data }
private struct InstallerReleaseManifest: Codable {
    let identity: String
    let build: UInt64
    let sha256: Data
    let minimumSystemVersion: String
}
@MainActor private func readReleaseTrust(installation: UUID) throws -> InstallerReleaseTrust {
    let value = try JSONDecoder().decode(InstallerReleaseTrust.self, from: protectedData(root.appendingPathComponent("release-trust.json")))
    guard value.installationID == installation, value.identity == HelperIdentity.appIdentifier,
          value.publicKey.count == 32 else { throw InstallerError.refused }
    _ = try Curve25519.Signing.PublicKey(rawRepresentation: value.publicKey)
    return value
}
@MainActor func provisionReleaseKey(installation: UUID, identity: String, publicKey: Data) throws {
    try withInstallationLock {
        _ = try readRecord(expectedInstallationID: installation)
        guard identity == HelperIdentity.appIdentifier, publicKey.count == 32,
              !itemExists(root.appendingPathComponent("release-trust.json").path),
              !itemExists(journalURL.path) else { throw InstallerError.refused }
        _ = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        let trust = InstallerReleaseTrust(installationID: installation, identity: identity, publicKey: publicKey)
        try durableWrite(JSONEncoder.sorted.encode(trust), to: root.appendingPathComponent("release-trust.json"), mode: 0o644)
    }
}

@MainActor private func copyBoundedInput(_ source: URL, to destination: URL, maximum: Int) throws {
    var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else { throw InstallerError.unsafeFile }
    defer { close(descriptor) }
    let parts = source.pathComponents.dropFirst()
    for (index, name) in parts.enumerated() {
        guard name != ".", name != ".." else { throw InstallerError.unsafeFile }
        let final = index == parts.count - 1
        let next = openat(descriptor, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC | (final ? 0 : O_DIRECTORY))
        guard next >= 0 else { throw InstallerError.unsafeFile }
        close(descriptor); descriptor = next
    }
    var information = stat()
    guard fstat(descriptor, &information) == 0, information.st_mode & S_IFMT == S_IFREG,
          information.st_nlink == 1, information.st_size > 0, information.st_size <= maximum else { throw InstallerError.unsafeFile }
    let output = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard output >= 0 else { throw InstallerError.unsafeFile }
    defer { close(output) }
    var remaining = Int(information.st_size), buffer = [UInt8](repeating: 0, count: 65536)
    while remaining > 0 {
        let count = Darwin.read(descriptor, &buffer, min(remaining, buffer.count))
        guard count > 0 else { throw InstallerError.unsafeFile }
        let written = buffer.withUnsafeBytes { Darwin.write(output, $0.baseAddress, count) }
        guard written == count else { throw InstallerError.interrupted }
        remaining -= count
    }
    var extra: UInt8 = 0
    guard Darwin.read(descriptor, &extra, 1) == 0, fsync(output) == 0 else { throw InstallerError.unsafeFile }
}

private func minimumVersion(_ text: String) throws -> [Int] {
    let parts = text.split(separator: ".", omittingEmptySubsequences: false)
    guard (2...3).contains(parts.count) else { throw InstallerError.refused }
    let values = try parts.map { part -> Int in
        guard !part.isEmpty, part.utf8.allSatisfy({ (48...57).contains($0) }),
              part.count == 1 || part.first != "0", let value = Int(part) else { throw InstallerError.refused }
        return value
    }
    guard values[0] > 0 else { throw InstallerError.refused }
    return [values[0], values[1], values.count == 3 ? values[2] : 0]
}

@MainActor func rotateRelease(manifest sourceManifest: URL, archive sourceArchive: URL, installation: UUID, request sourceRequest: URL? = nil) throws {
    try withInstallationLock {
        let original = try readRecord(expectedInstallationID: installation)
        let trust = try readReleaseTrust(installation: installation)
        guard !itemExists(journalURL.path) else { throw InstallerError.interrupted }
        let staging = root.appendingPathComponent("release-staging")
        guard !itemExists(staging.path) else { throw InstallerError.interrupted }
        try ensureDirectory(staging, mode: 0o700)
        defer { try? fm.removeItem(at: staging) }
        let manifestURL = staging.appendingPathComponent("manifest.json")
        let archiveURL = staging.appendingPathComponent("release.tar")
        try copyBoundedInput(sourceManifest, to: manifestURL, maximum: 1024 * 1024)
        try copyBoundedInput(sourceArchive, to: archiveURL, maximum: BoundedUSTAR.maximumBytes)
        var binding: ProtectedMaintenanceBinding?
        if let sourceRequest {
            let requestURL = staging.appendingPathComponent("request.json")
            try copyBoundedInput(sourceRequest, to: requestURL, maximum: 16384)
            binding = try ProtectedMaintenanceBinding.decode(Data(contentsOf: requestURL))
            guard binding?.operation == .update, binding?.installationID == installation,
                  binding?.previousGeneration == original.generation else { throw InstallerError.refused }
            try checkUnused(binding!)
        }
        // Everything below consumes protected staged objects, never reopens supplied paths.
        let signed = try JSONDecoder().decode(InstallerSignedRelease.self, from: Data(contentsOf: manifestURL))
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: trust.publicKey)
        guard signed.payload.count <= 1024 * 1024, signed.signature.count == 64,
              key.isValidSignature(signed.signature, for: signed.payload) else { throw InstallerError.refused }
        let manifest = try JSONDecoder().decode(InstallerReleaseManifest.self, from: signed.payload)
        guard manifest.identity == trust.identity, manifest.build > original.build, manifest.sha256.count == 32 else { throw InstallerError.refused }
        if let binding {
            guard binding.build == manifest.build, binding.signedPayloadSHA256 == Data(SHA256.hash(data: signed.payload)),
                  binding.archiveSHA256 == manifest.sha256 else { throw InstallerError.refused }
        }
        let minimum = try minimumVersion(manifest.minimumSystemVersion)
        let host = ProcessInfo.processInfo.operatingSystemVersion
        guard ![host.majorVersion, host.minorVersion, host.patchVersion].lexicographicallyPrecedes(minimum) else { throw InstallerError.refused }
        let bytes = try Data(contentsOf: archiveURL)
        guard Data(SHA256.hash(data: bytes)) == manifest.sha256 else { throw InstallerError.refused }
        let archive = try BoundedUSTAR(validating: bytes)
        guard archive.entries.allSatisfy({ $0.path == "Watt.app" || $0.path.hasPrefix("Watt.app/") }) else { throw InstallerError.refused }
        let extraction = staging.appendingPathComponent("extracted")
        try archive.extract(intoFreshDirectory: extraction)
        let app = extraction.appendingPathComponent("Watt.app")
        let plistData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              plist["CFBundleVersion"] as? String == String(manifest.build),
              plist["LSMinimumSystemVersion"] as? String == manifest.minimumSystemVersion else { throw InstallerError.refused }
        // Same approved staged tree feeds the existing coherent-generation transaction.
        let reviewed = staging.appendingPathComponent("reviewed.app")
        let tree = try stage(app, at: reviewed)
        let candidate = try inventory(reviewed, tree: tree)
        guard candidate.build == manifest.build else { throw InstallerError.refused }
        try installLocked(source: reviewed, approval: candidate.approval, rotate: true, binding: binding)
    }
}

@MainActor func discardReleaseStage(installation: UUID) throws {
    try withInstallationLock {
        _ = try readRecord(expectedInstallationID: installation)
        guard !itemExists(journalURL.path) else { throw InstallerError.interrupted }
        let staging = root.appendingPathComponent("release-staging")
        var information = stat()
        guard lstat(staging.path, &information) == 0, information.st_uid == installerEnvironment.owner,
              information.st_mode & S_IFMT == S_IFDIR, information.st_mode & 0o077 == 0 else { throw InstallerError.unsafeFile }
        try fm.removeItem(at: staging)
    }
}

enum InstallerCommand: Equatable {
    case preflight(URL)
    case reviewed(source: URL, approval: String, rotate: Bool)
    case provision(installation: UUID, identity: String, key: Data)
    case release(installation: UUID?, manifest: URL, archive: URL, request: URL?)
    case remove(installation: UUID?, generation: UInt64?, uninstall: Bool, request: URL?)
    case recover(installation: UUID, generation: UInt64)
    case discard(installation: UUID)

    /// Parse the complete request before reading installation state or producing effects.
    static func parse(_ arguments: [String]) throws -> Self {
        guard let operation = arguments.first, arguments.count <= 9, arguments.count % 2 == 1,
              arguments.reduce(0, { $0 + $1.utf8.count }) <= 32768 else { throw InstallerError.usage }
        var options: [String: String] = [:]
        for index in stride(from: 1, to: arguments.count, by: 2) {
            let name = arguments[index], value = arguments[index + 1]
            guard name.hasPrefix("--"), !value.isEmpty, !value.hasPrefix("--"),
                  options.updateValue(value, forKey: name) == nil else { throw InstallerError.usage }
        }
        func require(_ required: Set<String>, optional: Set<String> = []) throws {
            let keys = Set(options.keys)
            guard required.isSubset(of: keys), keys.isSubset(of: required.union(optional)) else { throw InstallerError.usage }
        }
        func url(_ name: String) throws -> URL {
            guard let path = options[name], path.hasPrefix("/"), !path.contains("\0") else { throw InstallerError.usage }
            return URL(fileURLWithPath: path)
        }
        func installation() throws -> UUID {
            guard let text = options["--installation"], let id = UUID(uuidString: text) else { throw InstallerError.usage }
            return id
        }
        func generation() throws -> UInt64 {
            guard let text = options["--generation"], let value = UInt64(text), value > 0 else { throw InstallerError.usage }
            return value
        }
        switch operation {
        case "--preflight":
            try require(["--source"]); return .preflight(try url("--source"))
        case "--bootstrap-reviewed", "--rotate-reviewed":
            try require(["--source", "--approval"])
            guard let approval = options["--approval"], approval.count == 64,
                  approval.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw InstallerError.usage }
            return .reviewed(source: try url("--source"), approval: approval, rotate: operation == "--rotate-reviewed")
        case "--provision-release-key":
            try require(["--installation", "--identity", "--public-key"])
            guard let identity = options["--identity"], let text = options["--public-key"],
                  let key = Data(base64Encoded: text), key.count == 32 else { throw InstallerError.usage }
            return .provision(installation: try installation(), identity: identity, key: key)
        case "--rotate-release":
            try require(["--manifest", "--archive"], optional: ["--installation", "--request"])
            guard options["--installation"] != nil || options["--request"] != nil else { throw InstallerError.usage }
            return .release(installation: options["--installation"] == nil ? nil : try installation(),
                            manifest: try url("--manifest"), archive: try url("--archive"),
                            request: options["--request"] == nil ? nil : try url("--request"))
        case "--uninstall", "--remove-helper":
            let uninstall = operation == "--uninstall"
            try require([], optional: uninstall ? ["--installation", "--generation", "--request"] : ["--installation", "--generation"])
            let hasInstallation = options["--installation"] != nil, hasGeneration = options["--generation"] != nil
            guard hasInstallation == hasGeneration, hasInstallation || (uninstall && options["--request"] != nil) else { throw InstallerError.usage }
            return .remove(installation: hasInstallation ? try installation() : nil,
                           generation: hasGeneration ? try generation() : nil, uninstall: uninstall,
                           request: options["--request"] == nil ? nil : try url("--request"))
        case "--recover":
            try require(["--installation", "--generation"])
            return .recover(installation: try installation(), generation: try generation())
        case "--discard-release-stage":
            try require(["--installation"]); return .discard(installation: try installation())
        default: throw InstallerError.usage
        }
    }
}

@MainActor func run() throws {
    switch try InstallerCommand.parse(Array(CommandLine.arguments.dropFirst())) {
    case .preflight(let source):
        let temporary = fm.temporaryDirectory.appendingPathComponent("watt-preflight-" + UUID().uuidString)
        try ensureDirectory(temporary, mode: 0o700)
        defer { try? fm.removeItem(at: temporary) }
        let app = temporary.appendingPathComponent("Watt.app")
        let tree = try stage(source, at: app)
        let candidate = try inventory(app, tree: tree)
        print(String(decoding: try JSONEncoder.sorted.encode(candidate), as: UTF8.self))
        print("Approval: \(try candidate.approval)")
    case .reviewed(let source, let approval, let rotate):
        try install(source: source, approval: approval, rotate: rotate)
    case .provision(let installation, let identity, let key):
        try provisionReleaseKey(installation: installation, identity: identity, publicKey: key)
    case .release(let installation, let manifest, let archive, let request):
        let actualInstallation = try installation ?? readRecord().installationID
        try rotateRelease(manifest: manifest, archive: archive, installation: actualInstallation, request: request)
    case .remove(let installation, let generation, let uninstall, let request):
        if let installation, let generation {
            try removeHelper(installation: installation, generation: generation, uninstall: uninstall, request: request)
        } else {
            let record = try readRecord()
            try removeHelper(installation: record.installationID, generation: record.generation, uninstall: uninstall, request: request)
        }
    case .recover(let installation, let generation): try recover(installation: installation, generation: generation)
    case .discard(let installation): try discardReleaseStage(installation: installation)
    }
}
