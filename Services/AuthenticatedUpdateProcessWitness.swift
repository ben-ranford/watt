import Foundation
import Darwin
import Security
#if canImport(WattMaintenanceShared)
import WattMaintenanceShared
#endif

/// A retained OS-observed child and an exact challenge response over private inherited pipes.
/// Restarting the observer loses this live evidence; journal files never reconstruct it.
@MainActor
final class AuthenticatedUpdateProcessWitness: ProductionUpdateProcessWitness {
    private struct Running {
        let process: Process
        let identity: MaintenanceProcessIdentity
        let bundle: URL
        let manifest: UpdateManifest
        let request: UpdateLaunchRequest
    }
    private let validator: any ProductionUpdateCodeValidator
    private var running: Running?
    var observedProcessIdentity: MaintenanceProcessIdentity? { running?.identity }
    init(validator: any ProductionUpdateCodeValidator = SecurityUpdateCodeValidator()) { self.validator = validator }

    func launch(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws {
        if try authenticatedRunning(bundle: bundle, manifest: manifest, receipt: receipt) { return }
        if let running, !running.process.isRunning { self.running = nil }
        guard running == nil else { throw ServiceFailure.interruptedUpdate }
        let code = try validator.verify(bundle: bundle)
        guard code.identifier == manifest.identity, code.build == manifest.build,
              code.minimumSystemVersion == manifest.minimumSystemVersion,
              let executable = Bundle(url: bundle)?.executableURL else { throw ServiceFailure.untrustedIdentity }
        var random = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else { throw ServiceFailure.invalidData }
        let request = try UpdateLaunchRequest(receipt: receipt, identity: manifest.identity, build: manifest.build,
                                              minimumSystemVersion: manifest.minimumSystemVersion, challenge: Data(random))
        let input = Pipe(), output = Pipe()
        let process = Process(); process.executableURL = executable
        process.arguments = ["--watt-update-handshake"]
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        try input.fileHandleForReading.close(); try output.fileHandleForWriting.close()
        defer { try? input.fileHandleForWriting.close(); try? output.fileHandleForReading.close() }
        do {
            let before = try MaintenanceProcessWitness.observe(pid: process.processIdentifier)
            guard before.uid == geteuid(), before.codeDirectoryHash == code.codeHash else { throw ServiceFailure.untrustedIdentity }
            try MaintenanceChannel.write(JSONEncoder().encode(request), to: input.fileHandleForWriting.fileDescriptor)
            let response = try UpdateLaunchAcknowledgement.decode(MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor, timeout: 5))
            guard response.request == request, process.isRunning,
                  try MaintenanceProcessWitness.observe(pid: process.processIdentifier) == before,
                  try validator.verify(bundle: bundle) == code else { throw ServiceFailure.untrustedIdentity }
            running = Running(process: process, identity: before, bundle: bundle, manifest: manifest, request: request)
            try MaintenanceChannel.write(Data("launch-accepted".utf8), to: input.fileHandleForWriting.fileDescriptor)
            guard try MaintenanceChannel.read(from: output.fileHandleForReading.fileDescriptor, timeout: 5) == Data("startup-confirmed".utf8),
                  try MaintenanceProcessWitness.matches(before) else { throw ServiceFailure.untrustedIdentity }
        } catch {
            // Only terminate the child created by this invocation, never a PID supplied by a receipt.
            if process.isRunning { process.terminate() }
            throw error
        }
    }
    func authenticatedRunning(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool {
        guard let running, running.bundle == bundle, running.manifest == manifest, running.request.receipt == receipt,
              running.process.isRunning else { return false }
        let code = try validator.verify(bundle: bundle)
        let matches = try MaintenanceProcessWitness.matches(running.identity)
        return code.identifier == manifest.identity && code.build == manifest.build
            && code.minimumSystemVersion == manifest.minimumSystemVersion
            && code.codeHash == running.identity.codeDirectoryHash
            && matches
    }
}
