import AppKit
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Published builds store the marketing version in `CFBundleVersion` as
/// `MAJOR * 1_000_000 + MINOR * 1_000 + PATCH`. The update offer shows that
/// version. A build that is not in that shape keeps its decimal form so
/// fixture tokens such as "2" stay stable.
enum UpdateVersionDisplay {
    static func marketing(build: UInt64) -> String {
        let major = build / 1_000_000
        let minor = (build / 1_000) % 1_000
        let patch = build % 1_000
        guard major >= 1 else { return String(build) }
        return "\(major).\(minor).\(patch)"
    }
}

/// Another copy of this app. The current process is never one of these.
struct AppInstance: Equatable, Sendable {
    let processIdentifier: Int32
    let bundleIdentifier: String
}

struct SingleInstanceOutcome: Equatable, Sendable {
    var stopped: [Int32] = []
    var activated: Int32?
    var terminatedSelf = false
}

@MainActor
protocol AppInstanceRegistry {
    func runningInstances(bundleIdentifier: String) -> [AppInstance]
    /// CFBundleVersion of this process. Nil when it cannot be read.
    func currentBundleVersion() -> UInt64?
    /// CFBundleVersion from that instance's bundle. Nil when it cannot be read.
    func bundleVersion(of instance: AppInstance) -> UInt64?
    /// Asks the instance to quit. Returns true only when it is no longer running.
    func requestTermination(_ instance: AppInstance) -> Bool
    /// Ends an instance that ignored the quit request.
    func forceTermination(_ instance: AppInstance) -> Bool
    /// Brings an existing instance forward and asks it to show its panel.
    func activate(_ instance: AppInstance)
    /// Quits the process that is deciding. Used when another copy should stay.
    func terminateCurrentProcess()
}

/// A new Watt replaces only an older copy of the same bundle id.
/// A same or newer copy is left running, brought forward, and this process quits.
/// A build that cannot be read counts as same-or-newer, so this process yields.
enum SingleInstanceClaim {
    /// Production entry. Bundle versions are read off the main thread. A protected
    /// path or a read that does not finish is an unreadable build, so this process yields.
    @MainActor
    static func becomeOnlyInstance() async {
        let registry = RunningApplicationRegistry()
        let identifier = Bundle.main.bundleIdentifier ?? ""
        let current = await BundleBuildNumber.readOffMain(bundleURL: Bundle.main.bundleURL)
        let others = registry.runningInstances(bundleIdentifier: identifier)
        var versions: [Int32: UInt64?] = [:]
        for instance in others {
            guard let url = registry.bundleURL(of: instance) else { continue }
            versions[instance.processIdentifier] = await BundleBuildNumber.readOffMain(bundleURL: url)
        }
        _ = becomeOnlyInstance(bundleIdentifier: identifier, currentProcessIdentifier: getpid(),
                               registry: PrefetchedInstanceRegistry(base: registry, current: current, versions: versions))
    }

    @MainActor
    @discardableResult
    static func becomeOnlyInstance(bundleIdentifier: String,
                                   currentProcessIdentifier: Int32,
                                   registry: any AppInstanceRegistry) -> SingleInstanceOutcome {
        guard !bundleIdentifier.isEmpty, currentProcessIdentifier > 0 else { return SingleInstanceOutcome() }
        let others = registry.runningInstances(bundleIdentifier: bundleIdentifier).filter {
            $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier > 0
                && $0.processIdentifier != currentProcessIdentifier
        }
        let current = registry.currentBundleVersion()
        var outcome = SingleInstanceOutcome()
        var keepers: [AppInstance] = []
        for instance in others {
            if isOlder(registry.bundleVersion(of: instance), than: current) {
                if registry.requestTermination(instance) || registry.forceTermination(instance) {
                    outcome.stopped.append(instance.processIdentifier)
                }
            } else {
                keepers.append(instance)
            }
        }
        if let keeper = preferredKeeper(keepers, version: { registry.bundleVersion(of: $0) }) {
            registry.activate(keeper)
            outcome.activated = keeper.processIdentifier
            registry.terminateCurrentProcess()
            outcome.terminatedSelf = true
        }
        return outcome
    }

    /// True only when both builds are known and the other one is strictly older.
    static func isOlder(_ other: UInt64?, than current: UInt64?) -> Bool {
        guard let other, let current else { return false }
        return other < current
    }

    /// Highest known build wins. An unreadable build loses to a known one.
    /// Equal builds keep the lower pid, the copy that was already running.
    static func preferredKeeper(_ instances: [AppInstance], version: (AppInstance) -> UInt64?) -> AppInstance? {
        instances.min { lhs, rhs in
            switch (version(lhs), version(rhs)) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.processIdentifier < rhs.processIdentifier
            }
        }
    }
}

/// CFBundleVersion from a bundle's Info.plist. Missing or non-numeric values are nil.
enum BundleBuildNumber {
    static func read(bundleURL: URL, home: String = NSHomeDirectory()) -> UInt64? {
        if LaunchPathPolicy.isPrivacyProtected(bundleURL, home: home) { return nil }
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        if LaunchPathPolicy.isPrivacyProtected(plistURL, home: home) { return nil }
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return parse(plist["CFBundleVersion"])
    }

    static func parse(_ value: Any?) -> UInt64? {
        let text: String?
        switch value {
        case let string as String:
            text = string
        case let number as NSNumber:
            text = number.stringValue
        default:
            text = nil
        }
        guard let text, !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
              text.first != "0", let build = UInt64(text), build > 0 else { return nil }
        return build
    }

    /// Nil when the plist is in a privacy-protected folder or the read does not finish.
    /// An unreadable build is the existing same-or-newer fallback.
    static func readOffMain(bundleURL: URL, home: String = NSHomeDirectory(), timeout: Duration = LaunchFileAccess.launchTimeout) async -> UInt64? {
        if LaunchPathPolicy.isPrivacyProtected(bundleURL, home: home) { return nil }
        let result = await LaunchFileAccess.value(timeout: timeout) { BundleBuildNumber.read(bundleURL: bundleURL, home: home) }
        if case .success(let build) = result { return build }
        return nil
    }
}

@MainActor
struct RunningApplicationRegistry: AppInstanceRegistry {
    var settleTimeout: TimeInterval = 1.5

    func runningInstances(bundleIdentifier: String) -> [AppInstance] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).map {
            AppInstance(processIdentifier: $0.processIdentifier, bundleIdentifier: bundleIdentifier)
        }
    }

    func currentBundleVersion() -> UInt64? {
        BundleBuildNumber.read(bundleURL: Bundle.main.bundleURL)
    }

    func bundleURL(of instance: AppInstance) -> URL? {
        runningApplication(instance)?.bundleURL
    }

    func bundleVersion(of instance: AppInstance) -> UInt64? {
        guard let bundleURL = bundleURL(of: instance) else { return nil }
        return BundleBuildNumber.read(bundleURL: bundleURL)
    }

    func requestTermination(_ instance: AppInstance) -> Bool {
        guard let application = runningApplication(instance) else { return true }
        application.terminate()
        let deadline = Date().addingTimeInterval(settleTimeout)
        while Date() < deadline {
            if application.isTerminated { return true }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return application.isTerminated
    }

    func forceTermination(_ instance: AppInstance) -> Bool {
        guard let application = runningApplication(instance) else { return true }
        return application.forceTerminate()
    }

    func activate(_ instance: AppInstance) {
        guard let application = runningApplication(instance) else { return }
        application.activate(options: [.activateAllWindows])
        postReopen(processIdentifier: instance.processIdentifier)
    }

    func terminateCurrentProcess() {
        NSApp.terminate(nil)
    }

    /// `applicationShouldHandleReopen` is what shows the running app's panel.
    /// Core event 'aevt' / 'rapp' is kAEReopenApplication.
    private func postReopen(processIdentifier: Int32) {
        let target = NSAppleEventDescriptor(processIdentifier: processIdentifier)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(0x61657674),
            eventID: AEEventID(0x72617070),
            targetDescriptor: target,
            returnID: -1,
            transactionID: 0
        )
        try? event.sendEvent(options: .noReply, timeout: 1)
    }

    private func runningApplication(_ instance: AppInstance) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: instance.bundleIdentifier)
            .first { $0.processIdentifier == instance.processIdentifier }
    }
}

/// Versions already read off the main thread. Termination and activation stay on the caller.
@MainActor
private struct PrefetchedInstanceRegistry: AppInstanceRegistry {
    let base: RunningApplicationRegistry
    let current: UInt64?
    let versions: [Int32: UInt64?]

    func runningInstances(bundleIdentifier: String) -> [AppInstance] {
        base.runningInstances(bundleIdentifier: bundleIdentifier)
    }
    func currentBundleVersion() -> UInt64? { current }
    func bundleVersion(of instance: AppInstance) -> UInt64? { versions[instance.processIdentifier] ?? nil }
    func requestTermination(_ instance: AppInstance) -> Bool { base.requestTermination(instance) }
    func forceTermination(_ instance: AppInstance) -> Bool { base.forceTermination(instance) }
    func activate(_ instance: AppInstance) { base.activate(instance) }
    func terminateCurrentProcess() { base.terminateCurrentProcess() }
}

/// A finished update handoff quits this process. A confirm-quit prompt must not cancel it.
enum UpdateHandoffQuit {
    static func reply(handoffRequiresQuit: Bool, confirmationAllowsQuit: Bool) -> NSApplication.TerminateReply {
        if handoffRequiresQuit { return .terminateNow }
        return confirmationAllowsQuit ? .terminateNow : .terminateCancel
    }
}
