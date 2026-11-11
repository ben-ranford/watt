import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
#endif
#if canImport(WattMaintenanceShared)
import WattMaintenanceShared
#endif

/// Runs launch file work away from the main thread and stops waiting after a timeout.
/// A stuck `openat` cannot be cancelled; the caller keeps the fallback and the
/// background attempt releases any lock it acquired when its result is dropped.
@MainActor
enum LaunchFileAccess {
    static let launchTimeout: Duration = .seconds(2)

    private enum Kind: Sendable {
        case service(ServiceFailure)
        case trust(ProtectedTrustError)
        case signing(HelperSigningError)
        case archive
        case opaque
        var error: Error {
            switch self {
            case .service(let failure): return failure
            case .trust(let failure): return failure
            case .signing(let failure): return failure
            case .archive: return ArchiveValidationError.unsafeDestination
            case .opaque: return ServiceFailure.untrustedIdentity
            }
        }
    }

    private enum Outcome<T: Sendable>: Sendable {
        case success(T)
        case failure(Kind)
    }

    private enum Race<T: Sendable>: Sendable {
        case finished(Outcome<T>)
        case timedOut
    }

    static func value<T: Sendable>(timeout: Duration = launchTimeout,
                                   _ body: @escaping @Sendable () throws -> T) async -> Result<T, Error> {
        let outcome: Outcome<T> = await withTaskGroup(of: Race<T>.self) { group in
            group.addTask {
                do { return .finished(.success(try await Task.detached(priority: .userInitiated, operation: body).value)) }
                catch let failure as ServiceFailure { return .finished(.failure(.service(failure))) }
                catch let failure as ProtectedTrustError { return .finished(.failure(.trust(failure))) }
                catch let failure as HelperSigningError { return .finished(.failure(.signing(failure))) }
                catch is ArchiveValidationError { return .finished(.failure(.archive)) }
                catch { return .finished(.failure(.opaque)) }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            switch first {
            case .finished(let outcome): return outcome
            case .timedOut: return .failure(.service(.timedOut))
            }
        }
        switch outcome {
        case .success(let value): return .success(value)
        case .failure(let kind): return .failure(kind.error)
        }
    }

    static func require<T: Sendable>(timeout: Duration = launchTimeout,
                                     _ body: @escaping @Sendable () throws -> T) async throws -> T {
        switch await value(timeout: timeout, body) {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Handshake child only. The GUI launch path does not call this.
    /// The blocking `openat` runs on another thread; this wait is bounded.
    static func blockingValue<T: Sendable>(timeout: TimeInterval = 4,
                                           _ body: @escaping @Sendable () throws -> T) throws -> T {
        let box = LockedBox<Result<T, Kind>>()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<T, Kind>
            do { result = .success(try body()) }
            catch let failure as ServiceFailure { result = .failure(.service(failure)) }
            catch let failure as ProtectedTrustError { result = .failure(.trust(failure)) }
            catch let failure as HelperSigningError { result = .failure(.signing(failure)) }
            catch is ArchiveValidationError { result = .failure(.archive) }
            catch { result = .failure(.opaque) }
            box.set(result)
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success, let result = box.get() else {
            throw ServiceFailure.timedOut
        }
        switch result {
        case .success(let value): return value
        case .failure(let kind): throw kind.error
        }
    }
}

private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?
    func set(_ value: T) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> T? { lock.lock(); defer { lock.unlock() }; return value }
}

/// No in-app "move Watt to Applications" window exists. Launch still reaches the
/// status item. A test or a later presenter can observe the path decision here
/// without opening the folder.
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

    static func configured(bundle: Bundle = .main) async throws -> Self {
        let configuration = try UpdateConfiguration.configured(bundle: bundle)
        let bundleURL = bundle.bundleURL
        if LaunchPathPolicy.isPrivacyProtected(bundleURL) { throw ServiceFailure.untrustedIdentity }
        let executable = bundle.executableURL
        let opened = try await LaunchFileAccess.require { () throws -> UpdateLaunchFiles in
            try UpdateLaunchFiles.open(bundleURL: bundleURL, executable: executable)
        }
        let record = opened.record
        let driver = try ProductionUpdateInstallationDriver(application: opened.application,
            adoptingStaging: opened.staging, verified: opened.verified,
            applicationOwnerUID: record == nil ? geteuid() : 0, witness: AuthenticatedUpdateProcessWitness(),
            requiresAdministrator: { _, _ in record != nil })
        let journal = AtomicMaintenanceStorage(adopting: opened.journal)
        opened.consume()
        let source = try ProductionUpdateSource(manifestURL: configuration.manifestURL,
            artifactURL: configuration.artifactURL, trust: configuration.trust)
        let coordinator = record.map { ProtectedUpdateCoordinator(installation: $0, driver: driver, journal: journal) }
        return Self(adapter: UpdateAdapter(source: source, driver: driver, storage: journal,
            trust: configuration.trust, protectedUpdates: coordinator), coordinator: coordinator)
    }
}

/// Journal and staging locks opened off the main thread. Released if launch times out
/// before the main actor adopts them. One lock per directory: adopting reuses these objects.
private final class UpdateLaunchFiles: @unchecked Sendable {
    let application: URL
    let record: ProtectedHelperRecord?
    let verified: VerifiedUpdateBundle
    let journal: HeldLock
    let staging: HeldLock
    private var consumed = false

    fileprivate static func open(bundleURL: URL, executable: URL?) throws -> UpdateLaunchFiles {
        if LaunchPathPolicy.isPrivacyProtected(bundleURL) { throw ServiceFailure.untrustedIdentity }
        let application = bundleURL.standardizedFileURL
        if LaunchPathPolicy.isPrivacyProtected(application) { throw ServiceFailure.untrustedIdentity }
        guard application.isFileURL, application.pathExtension == "app" else { throw ServiceFailure.invalidData }
        let record = FileManager.default.fileExists(atPath: ProtectedHelperRecord.publicURL.path)
            ? try ProtectedHelperRecord.read() : nil
        if let record {
            guard application == record.applicationURL, let executable else { throw ServiceFailure.untrustedIdentity }
            if LaunchPathPolicy.isPrivacyProtected(executable) { throw ServiceFailure.untrustedIdentity }
            _ = try HelperTrustPolicy.protectedInstallation(record).verifyExecutable(at: executable, helper: false)
        }
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("Watt", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let journalDirectory = directory.appendingPathComponent("update-journal", isDirectory: true)
        let stagingDirectory = directory.appendingPathComponent("update-staging", isDirectory: true)
        guard !application.path.hasPrefix(stagingDirectory.path + "/"),
              !stagingDirectory.path.hasPrefix(application.path + "/") else { throw ServiceFailure.invalidData }
        let journal = try HeldLock.acquire(directory: journalDirectory)
        let staging: HeldLock
        do { staging = try HeldLock.acquire(directory: stagingDirectory) }
        catch { journal.release(); throw error }
        let owner: uid_t = record == nil ? geteuid() : 0
        do {
            let identity = try RunningBundleCheck.verify(url: application, owner: owner) {
                try SecurityUpdateCodeValidator().verify(bundle: $0)
            }
            return UpdateLaunchFiles(application: application, record: record, verified: identity, journal: journal, staging: staging)
        } catch {
            journal.release()
            staging.release()
            throw error
        }
    }

    private init(application: URL, record: ProtectedHelperRecord?, verified: VerifiedUpdateBundle, journal: HeldLock, staging: HeldLock) {
        self.application = application
        self.record = record
        self.verified = verified
        self.journal = journal
        self.staging = staging
    }
    func consume() { consumed = true }
    deinit {
        if !consumed {
            journal.release()
            staging.release()
        }
    }
}
