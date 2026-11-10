import Foundation
import AppKit
import Darwin
import CryptoKit
#if SWIFT_PACKAGE
import WattHelperShared
import WattMaintenanceShared
#endif

@MainActor
protocol ProtectedUpdateCoordinating {
    var administratorCommand: String? { get }
    var packageDirectory: URL? { get }
    func install(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt,
                 prepareOwnershipTransfer: () throws -> Void) async throws -> UpdateState
    func recover(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdateState
}

/// The existing adapter owns download/consent; this lane follows protected generation changes.
@MainActor
final class ProtectedUpdateCoordinator: ProtectedUpdateCoordinating {
    private let installation: ProtectedHelperRecord
    private let driver: ProductionUpdateInstallationDriver
    private let journal: AtomicMaintenanceStorage
    private var worker: Process?
    private var workerReceipt: OperationReceipt?
    private(set) var packageDirectory: URL?
    private(set) var administratorCommand: String?
    init(installation: ProtectedHelperRecord, driver: ProductionUpdateInstallationDriver, journal: AtomicMaintenanceStorage) {
        self.installation = installation; self.driver = driver; self.journal = journal
    }
    static func administratorArguments(package: URL) -> [String] {
        ["--rotate-release", "--manifest", package.appendingPathComponent("manifest.json").path,
         "--archive", package.appendingPathComponent("release.tar").path,
         "--request", package.appendingPathComponent("request.json").path]
    }
    /// The request's retained previous generation owns this command across interrupted rotation.
    /// Record injection is a fixture boundary; production always reads the root-owned record.
    static func prepareAdministratorCommand(package: URL, envelope: ProtectedUpdateEnvelope,
        installation: ProtectedHelperRecord,
        readPreviousRecord: (URL) throws -> ProtectedHelperRecord = { try ProtectedHelperRecord.read(at: $0) }) throws -> String {
        try envelope.validate(); try installation.validate()
        let binding = envelope.binding
        guard installation.installationID == binding.installationID else { throw ServiceFailure.untrustedIdentity }
        let previousURL = ProtectedHelperRecord.directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent("\(binding.installationID.uuidString)-\(binding.previousGeneration)", isDirectory: true)
            .appendingPathComponent("record.json")
        let previous = try readPreviousRecord(previousURL)
        try previous.validate()
        guard previous.installationID == binding.installationID, previous.generation == binding.previousGeneration,
              previous.build < binding.build,
              (installation == previous || (installation.generation == binding.nextGeneration && installation.maintenanceBinding == binding)) else {
            throw ServiceFailure.untrustedIdentity
        }
        let installer = previous.applicationURL.appendingPathComponent("Contents/MacOS/WattHelperInstaller")
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = (["sudo", installer.path] + administratorArguments(package: package)).map(quote).joined(separator: " ")
        let bytes = Data((command + "\n").utf8)
        let directory = try ProtectedUpdatePackage.privateDirectory(package); defer { close(directory) }
        var info = stat()
        if fstatat(directory, "administrator-command.txt", &info, AT_SYMLINK_NOFOLLOW) == 0 {
            guard try ProtectedUpdatePackage.readFile("administrator-command.txt", directory: package, limit: 16384) == bytes else {
                throw ServiceFailure.untrustedIdentity
            }
        } else {
            guard errno == ENOENT else { throw ServiceFailure.persistence }
            try ProtectedUpdatePackage.writeFile(bytes, named: "administrator-command.txt", directory: package)
        }
        return command
    }
    func install(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt,
                 prepareOwnershipTransfer: () throws -> Void) async throws -> UpdateState {
        guard worker == nil else { throw ServiceFailure.interruptedUpdate }
        let (envelope, package) = try driver.exportProtectedPackage(release: release, manifest: manifest, receipt: receipt, installation: installation)
        packageDirectory = package
        administratorCommand = try Self.prepareAdministratorCommand(package: package, envelope: envelope, installation: installation)
        NSWorkspace.shared.open(package)
        let executable = installation.applicationURL.appendingPathComponent("Contents/MacOS/WattMaintenance")
        let hash = try ExactCodeIdentity.verify(at: executable,
            requirement: ExactCodeIdentity.requirement(hashes: installation.maintenanceHashes, identifier: HelperIdentity.appIdentifier + ".maintenance"))
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = executable; process.arguments = []
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
        try process.run()
        try input.fileHandleForReading.close(); try output.fileHandleForWriting.close()
        defer { try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close() }
        do {
            let observed = try MaintenanceProcessWitness.observe(pid: process.processIdentifier)
            guard observed.uid == getuid(), observed.codeDirectoryHash == hash else { throw ServiceFailure.untrustedIdentity }
            try MaintenanceChannel.write(JSONEncoder().encode(envelope.request), to: input.fileHandleForWriting.fileDescriptor)
            try MaintenanceChannel.write(JSONEncoder().encode(envelope), to: input.fileHandleForWriting.fileDescriptor)
            let ready = try MaintenanceRequest.decode(MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor))
            guard ready == envelope.request, try MaintenanceProcessWitness.matches(observed) else { throw ServiceFailure.untrustedIdentity }
            try prepareOwnershipTransfer()
            driver.closeForMaintenanceTransfer(); journal.close()
            try MaintenanceChannel.write(Data("release".utf8), to: input.fileHandleForWriting.fileDescriptor)
            guard try MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor) == Data("accepted".utf8),
                  try MaintenanceProcessWitness.matches(observed) else { throw ServiceFailure.interruptedUpdate }
            worker = process
            workerReceipt = receipt
            return .handoffAccepted(receipt)
        } catch { if process.isRunning { process.terminate() }; throw error }
    }
    func recover(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdateState {
        // Only the current process's authenticated startup channel can recreate live evidence.
        if let request = UpdateLaunchAcknowledgementService.acceptedRequest, request.receipt == receipt,
           request.identity == manifest.identity, request.build == manifest.build,
           request.minimumSystemVersion == manifest.minimumSystemVersion {
            let current = try ProtectedHelperRecord.read(expectedInstallationID: installation.installationID)
            guard let binding = current.maintenanceBinding, binding.operation == .update,
                  binding.receipt.id == receipt.id, binding.receipt.createdAt == receipt.createdAt,
                  binding.signedPayloadSHA256 == Data(SHA256.hash(data: release.payload)), binding.archiveSHA256 == manifest.sha256,
                  binding.build == manifest.build, current.appHashes.contains(try MaintenanceProcessWitness.observe(pid: getpid()).codeDirectoryHash) else {
                throw ServiceFailure.untrustedIdentity
            }
            let selfIdentity = try MaintenanceProcessWitness.observe(pid: getpid())
            let correlated = try MaintenanceRequest(receipt: receipt, installationID: current.installationID,
                generation: binding.previousGeneration, operation: .update, parent: selfIdentity, candidateSHA256: binding.archiveSHA256)
            try ProtectedUpdateSession.requireCoherent(current, envelope: ProtectedUpdateEnvelope(request: correlated,
                binding: binding, minimumSystemVersion: manifest.minimumSystemVersion))
            return .completed(receipt)
        }
        if let worker, worker.isRunning, workerReceipt == receipt { return .handoffAccepted(receipt) }
        return .failed(.interruptedUpdate, receipt)
    }
}
