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
/// `LaunchHelperPolicy` decides whether launch updates that helper or opens the copy.
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

    /// Opens the protected copy as a new instance and waits until it has launched.
    /// The caller quits only after this returns true. Quitting before the launch
    /// finished dropped the request, so neither copy was left running. If the
    /// protected copy can't be opened, this copy keeps running.
    @MainActor
    static func openManagedCopy(_ managed: URL,
                                open: @MainActor (URL) async throws -> Void = launchNewInstance) async -> Bool {
        guard FileManager.default.fileExists(atPath: managed.path) else { return false }
        do { try await open(managed); return true } catch { return false }
    }

    @MainActor
    static func launchNewInstance(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}

/// What launch knows about the installed helper before it opens another copy.
struct LaunchHelperFacts: Equatable, Sendable {
    var helperInstalled: Bool
    var launchingBuild: UInt64?
    var installedBuild: UInt64?
    /// This process is the bundle recorded in helper-trust.json.
    var runningIsProtectedCopy: Bool
    var protectedCopyURL: URL?
    /// The protected copy still matches the helper's own pins.
    var protectedCopyMatchesPins: Bool
    /// This process matches the helper's app pins.
    var runningMatchesPins: Bool
    /// `installer-journal.json` is still on disk from an install that did not finish.
    var unfinishedInstallJournal: Bool
    /// Release builds may rotate the protected helper. Certificate builds do not.
    var automaticHelperUpdateAllowed: Bool

    static let inactive = LaunchHelperFacts(
        helperInstalled: false, launchingBuild: nil, installedBuild: nil,
        runningIsProtectedCopy: false, protectedCopyURL: nil,
        protectedCopyMatchesPins: false, runningMatchesPins: false,
        unfinishedInstallJournal: false, automaticHelperUpdateAllowed: false)

    /// Reads the root-owned helper record and this bundle. A privacy-protected
    /// bundle is left untouched, the same way managed-copy placement skips it.
    static func current(bundle: Bundle = .main) -> LaunchHelperFacts {
        let running = bundle.bundleURL
        if LaunchPathPolicy.isPrivacyProtected(running) { return .inactive }
        let launchingBuild = BundleBuildNumber.read(bundleURL: running)
        let automatic = bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String != "certificate"
        let journal = installerJournalPresent()
        guard FileManager.default.fileExists(atPath: ProtectedHelperRecord.publicURL.path),
              let record = try? ProtectedHelperRecord.read() else {
            return LaunchHelperFacts(
                helperInstalled: false, launchingBuild: launchingBuild, installedBuild: nil,
                runningIsProtectedCopy: false, protectedCopyURL: nil,
                protectedCopyMatchesPins: false, runningMatchesPins: false,
                unfinishedInstallJournal: journal, automaticHelperUpdateAllowed: automatic)
        }
        let managed = record.applicationURL
        let policy = HelperTrustPolicy.protectedInstallation(record)
        func matches(_ executable: URL?) -> Bool {
            guard let executable else { return false }
            return (try? policy.verifyExecutable(at: executable, helper: false)) != nil
        }
        let runningIsProtected = ManagedCopyPolicy.samePath(running, managed)
        return LaunchHelperFacts(
            helperInstalled: true,
            launchingBuild: launchingBuild,
            installedBuild: record.build,
            runningIsProtectedCopy: runningIsProtected,
            protectedCopyURL: managed,
            protectedCopyMatchesPins: matches(managed.appendingPathComponent("Contents/MacOS/Watt")),
            runningMatchesPins: runningIsProtected || matches(bundle.executableURL),
            unfinishedInstallJournal: journal,
            automaticHelperUpdateAllowed: automatic)
    }

    /// Existence only. The journal is root-owned, so launch does not open it.
    static func installerJournalPresent() -> Bool {
        var info = stat()
        let path = ProtectedHelperRecord.directory.appendingPathComponent("installer-journal.json").path
        return lstat(path, &info) == 0
    }
}

/// Launch either stays here, opens the protected copy, or updates the helper first.
enum LaunchHelperPlan: Equatable, Sendable {
    case stay
    case handOver(URL)
    /// Rotate the installed helper to this build before any handover.
    case updateInstalledHelper
}

enum LaunchHelperPolicy {
    /// One decision for the whole launch. A missing helper is never installed here.
    /// An older launching app never rotates the helper down. A newer app updates
    /// first, so launch does not open the older protected copy.
    static func plan(for facts: LaunchHelperFacts) -> LaunchHelperPlan {
        guard facts.helperInstalled else { return .stay }
        // This process is the protected copy. It does not install over itself.
        if facts.runningIsProtectedCopy { return .stay }
        if let launching = facts.launchingBuild, let installed = facts.installedBuild {
            if launching > installed {
                return facts.automaticHelperUpdateAllowed ? .updateInstalledHelper : .stay
            }
            if launching < installed {
                if facts.protectedCopyMatchesPins, let url = facts.protectedCopyURL {
                    return .handOver(url)
                }
                return .stay
            }
            // Same build keeps the normal handover. A leftover journal is not a
            // second install: the next newer launch rotates, and that installer
            // finishes the journal before it writes the new generation.
            if facts.runningMatchesPins, facts.protectedCopyMatchesPins, let url = facts.protectedCopyURL {
                return .handOver(url)
            }
            return .stay
        }
        // Unreadable builds are not treated as newer or older. Pin handover stays.
        if facts.runningMatchesPins, facts.protectedCopyMatchesPins, let url = facts.protectedCopyURL {
            return .handOver(url)
        }
        return .stay
    }

    static func placement(for facts: LaunchHelperFacts, running: URL) -> ManagedCopyPolicy.Placement {
        guard facts.helperInstalled else { return .noProtectedInstallation }
        return ManagedCopyPolicy.placement(
            running: running, managed: facts.protectedCopyURL,
            runningMatchesPins: facts.runningMatchesPins,
            managedMatchesPins: facts.protectedCopyMatchesPins)
    }

    /// After a successful update, only an exact pinned copy elsewhere is opened.
    /// A still-different protected copy is left alone.
    static func sameBuildHandoverURL(_ placement: ManagedCopyPolicy.Placement) -> URL? {
        if case .sameBuildElsewhere(let url) = placement { return url }
        return nil
    }

    /// An older launching app must not be told to turn the helper on for this copy.
    /// That rotation would be a downgrade, and the installer refuses it.
    static func updateCause(facts: LaunchHelperFacts, placement: ManagedCopyPolicy.Placement) -> UpdateUnavailableCause {
        if case .differentBuildElsewhere = placement,
           let launching = facts.launchingBuild, let installed = facts.installedBuild, launching < installed {
            return .helperCopyElsewhere
        }
        return ManagedCopyPolicy.updateCause(for: placement)
    }
}

/// What launch does after the version check. The helper update runs at most once.
enum LaunchHelperContinuation: Equatable, Sendable {
    case handOver(URL, helperUpdated: Bool)
    case stay(helperUpdated: Bool, failure: ServiceFailure?)
}

@MainActor
enum LaunchHelperStartup {
    static func continuation(
        plan: LaunchHelperPlan,
        update: () async -> ServiceFailure?,
        protectedCopyAfterUpdate: () async -> URL?
    ) async -> LaunchHelperContinuation {
        switch plan {
        case .stay:
            return .stay(helperUpdated: false, failure: nil)
        case .handOver(let url):
            return .handOver(url, helperUpdated: false)
        case .updateInstalledHelper:
            if let failure = await update() {
                return .stay(helperUpdated: false, failure: failure)
            }
            if let url = await protectedCopyAfterUpdate() {
                return .handOver(url, helperUpdated: true)
            }
            return .stay(helperUpdated: true, failure: nil)
        }
    }
}

/// The launch-time helper update. It always rotates, so the administrator
/// installer finishes an interrupted install journal before it writes this build.
@MainActor
enum LaunchHelperUpdate {
    static func install(
        bundle: URL,
        executable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        run: @escaping (HelperBundleInstall.Command) async -> Result<String, ServiceFailure> = HelperBundleInstall.run
    ) async -> ServiceFailure? {
        let installer = bundle.appendingPathComponent("Contents/MacOS/WattHelperInstaller")
        guard executable(installer.path) else { return .unknownStatus }
        return await HelperBundleInstall.install(installer: installer, source: bundle, rotate: true, run: run)
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
