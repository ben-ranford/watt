import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattMaintenanceShared
import WattHelperShared
#endif

@MainActor
enum UpdateLaunchAcknowledgementService {
    static private(set) var acceptedRequest: UpdateLaunchRequest?
    /// Called before ordinary stores open, while the authenticated observer is still alive.
    static func acknowledge(bundle: Bundle = .main) throws {
        if LaunchPathPolicy.isPrivacyProtected(bundle.bundleURL) { throw ServiceFailure.untrustedIdentity }
        let parent = try MaintenanceProcessWitness.observe(pid: getppid())
        guard parent.uid == geteuid(), parent.pid > 1 else { throw ServiceFailure.untrustedIdentity }
        let request = try UpdateLaunchRequest.decode(MaintenanceChannel.read(from: STDIN_FILENO))
        let actual = try SecurityUpdateCodeValidator().verify(bundle: bundle.bundleURL)
        guard actual.identifier == request.identity, actual.build == request.build,
              actual.minimumSystemVersion == request.minimumSystemVersion,
              try MaintenanceProcessWitness.matches(parent) else { throw ServiceFailure.untrustedIdentity }
        if bundle.bundleURL.path.hasPrefix(ProtectedHelperRecord.directory.path + "/generations/") {
            let record = try ProtectedHelperRecord.read()
            guard record.applicationURL == bundle.bundleURL,
                  let binding = record.maintenanceBinding,
                  binding.receipt.id == request.receipt.id, binding.receipt.createdAt == request.receipt.createdAt,
                  binding.build == request.build else { throw ServiceFailure.untrustedIdentity }
            if !record.maintenanceHashes.contains(parent.codeDirectoryHash) {
                let previous = try ProtectedHelperRecord.readGenerationRecord(installationID: record.installationID,
                    generation: binding.previousGeneration)
                guard previous.maintenanceHashes.contains(parent.codeDirectoryHash) else { throw ServiceFailure.untrustedIdentity }
            }
        }
        try MaintenanceChannel.write(JSONEncoder().encode(UpdateLaunchAcknowledgement(request: request)), to: STDOUT_FILENO)
        guard try MaintenanceChannel.read(from: STDIN_FILENO) == Data("launch-accepted".utf8),
              try MaintenanceProcessWitness.matches(parent) else { throw ServiceFailure.untrustedIdentity }
        // The observer waits for this bounded response before exiting, so the liveness
        // check above cannot race its successful completion. No GUI readiness is inferred.
        try MaintenanceChannel.write(Data("startup-confirmed".utf8), to: STDOUT_FILENO)
        // The parent can quit once it reads this. The launch argument stays on
        // the process, but it is not an ongoing handshake-child mode: startup
        // recovery reads `acceptedRequest` once, then retires it.
        acceptedRequest = request
    }

    static var isHandshakeChild: Bool { acceptedRequest != nil }

    /// Drops one-shot launch evidence so later recovery does not treat this
    /// long-lived process as the handshake child.
    static func retireHandshakeEvidence() {
        acceptedRequest = nil
    }

    static func retainStartupEvidenceForTesting(_ request: UpdateLaunchRequest?) {
        acceptedRequest = request
    }
}
