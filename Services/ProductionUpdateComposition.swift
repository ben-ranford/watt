import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

@MainActor
struct ProductionUpdateComposition {
    let adapter: UpdateAdapter
    let coordinator: ProtectedUpdateCoordinator?

    static func configured(bundle: Bundle = .main) throws -> Self {
        let configuration = try UpdateConfiguration.configured(bundle: bundle)
        let application = bundle.bundleURL.standardizedFileURL
        let record = FileManager.default.fileExists(atPath: ProtectedHelperRecord.publicURL.path)
            ? try ProtectedHelperRecord.read() : nil
        if let record {
            guard application == record.applicationURL, let executable = bundle.executableURL else { throw ServiceFailure.untrustedIdentity }
            _ = try HelperTrustPolicy.protectedInstallation(record).verifyExecutable(at: executable, helper: false)
        }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("Watt", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let journal = try AtomicMaintenanceStorage(directory: directory.appendingPathComponent("update-journal", isDirectory: true))
        let driver = try ProductionUpdateInstallationDriver(application: application,
            stagingDirectory: directory.appendingPathComponent("update-staging", isDirectory: true),
            applicationOwnerUID: record == nil ? geteuid() : 0, witness: AuthenticatedUpdateProcessWitness(),
            requiresAdministrator: { _, _ in
                // A protected installation is rotated by the administrator installer.
                // That path re-verifies the Ed25519 manifest and archive sha256, then
                // restarts the helper with the new cdhash. An ordinary ad-hoc app
                // with no helper record replaces its own bundle in place.
                record != nil
            })
        let source = try ProductionUpdateSource(manifestURL: configuration.manifestURL,
            artifactURL: configuration.artifactURL, trust: configuration.trust)
        let coordinator = record.map { ProtectedUpdateCoordinator(installation: $0, driver: driver, journal: journal) }
        return Self(adapter: UpdateAdapter(source: source, driver: driver, storage: journal,
            trust: configuration.trust, protectedUpdates: coordinator), coordinator: coordinator)
    }
}
