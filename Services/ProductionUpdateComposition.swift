import AppKit
import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// There is no move-to-Applications window in the app. This is the launch signal
/// for Downloads, Desktop, Documents, iCloud Drive, and App Translocation.
/// It does not open the folder.
@MainActor
enum ApplicationsFolderGuidance {
    static var presenter: ((URL) -> Void)?
    static func presentIfNeeded(bundleURL: URL, home: String = NSHomeDirectory()) {
        guard LaunchPathPolicy.shouldSuggestApplicationsFolder(bundleURL, home: home) else { return }
        presenter?(bundleURL)
    }
}

@MainActor
struct ProductionUpdateComposition {
    let adapter: UpdateAdapter
    let coordinator: ProtectedUpdateCoordinator?

    static func configured(bundle: Bundle = .main, home: String = NSHomeDirectory()) throws -> Self {
        // A bundle in Desktop, Documents, Downloads, or iCloud Drive must not be opened.
        // standardizedFileURL and the staging lock both walk that path with openat.
        if LaunchPathPolicy.isPrivacyProtected(bundle.bundleURL, home: home) { throw ServiceFailure.untrustedIdentity }
        let configuration = try UpdateConfiguration.configured(bundle: bundle)
        let application = bundle.bundleURL.standardizedFileURL
        if LaunchPathPolicy.isPrivacyProtected(application, home: home) { throw ServiceFailure.untrustedIdentity }
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
                // restarts the helper with the new cdhash. An app with no helper
                // record replaces its own bundle in place.
                record != nil
            })
        let source = try ProductionUpdateSource(manifestURL: configuration.manifestURL,
            artifactURL: configuration.artifactURL, trust: configuration.trust)
        let coordinator = record.map { ProtectedUpdateCoordinator(installation: $0, driver: driver, journal: journal) }
        return Self(adapter: UpdateAdapter(source: source, driver: driver, storage: journal,
            trust: configuration.trust, protectedUpdates: coordinator), coordinator: coordinator)
    }
}

/// With the helper on, the protected copy under /Library/Application Support/Watt
/// is the one that can update and remove itself. A copy anywhere else, such as the
/// Homebrew copy in /Applications, is a separate bundle at a separate path.
enum ManagedCopyPolicy {
    enum Placement: Equatable {
        case noProtectedInstallation
        /// This process runs from the helper's protected copy.
        case managed
        /// Another copy of the exact pinned build. Launch hands over to the protected copy.
        case sameBuildElsewhere(managed: URL)
        /// A copy that does not match the helper's pins, so it cannot hand over.
        case differentBuildElsewhere(managed: URL)
    }

    static func placement(running: URL, managed: URL?, runningMatchesPins: Bool,
                          managedMatchesPins: Bool) -> Placement {
        guard let managed else { return .noProtectedInstallation }
        if samePath(running, managed) { return .managed }
        return runningMatchesPins && managedMatchesPins
            ? .sameBuildElsewhere(managed: managed) : .differentBuildElsewhere(managed: managed)
    }

    static func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }

    static func updateCause(for placement: Placement) -> UpdateUnavailableCause {
        switch placement {
        case .noProtectedInstallation, .managed: return .notConfigured
        case .sameBuildElsewhere: return .helperCopyElsewhere
        case .differentBuildElsewhere: return .helperCopyDiffers
        }
    }

    /// Reads only root-owned protected paths and this bundle. Callers skip this for
    /// a bundle in a privacy-protected folder.
    static func current(bundle: Bundle = .main) -> Placement {
        let running = bundle.bundleURL
        if LaunchPathPolicy.isPrivacyProtected(running) { return .noProtectedInstallation }
        guard FileManager.default.fileExists(atPath: ProtectedHelperRecord.publicURL.path),
              let record = try? ProtectedHelperRecord.read() else { return .noProtectedInstallation }
        let managed = record.applicationURL
        if samePath(running, managed) { return .managed }
        let policy = HelperTrustPolicy.protectedInstallation(record)
        func matches(_ executable: URL?) -> Bool {
            guard let executable else { return false }
            do { _ = try policy.verifyExecutable(at: executable, helper: false); return true } catch { return false }
        }
        return placement(running: running, managed: managed,
                         runningMatchesPins: matches(bundle.executableURL),
                         managedMatchesPins: matches(managed.appendingPathComponent("Contents/MacOS/Watt")))
    }

    /// Opens the protected copy as a new instance. The caller quits after this returns true.
    @MainActor
    static func openManagedCopy(_ managed: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: managed.path) else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: managed, configuration: configuration) { _, _ in }
        return true
    }
}

/// Why Check for Updates is unavailable. Each cause has its own next step.
enum UpdateUnavailableCause: Equatable, Sendable, CaseIterable {
    case notConfigured
    case privacyProtectedFolder
    case helperCopyElsewhere
    case helperCopyDiffers

    var message: String {
        switch self {
        case .notConfigured: return "Updates aren’t configured in this build."
        case .privacyProtectedFolder: return "Move Watt? to Applications to get updates."
        case .helperCopyElsewhere: return "Updates run from the copy the helper uses. Quit Watt? and open it again to switch to that copy."
        case .helperCopyDiffers: return "This copy of Watt? doesn’t match the copy the helper uses. Turn on the helper in Settings to switch to this copy."
        }
    }
}
