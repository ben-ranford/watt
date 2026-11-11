import AppKit
import Darwin

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

@MainActor
protocol AppInstanceRegistry {
    func runningInstances(bundleIdentifier: String) -> [AppInstance]
    /// Asks the instance to quit. Returns true only when it is no longer running.
    func requestTermination(_ instance: AppInstance) -> Bool
    /// Ends an instance that ignored the quit request.
    func forceTermination(_ instance: AppInstance) -> Bool
}

/// One Watt process. A freshly started copy asks any other instance of the
/// same bundle id to quit, then terminates it if it is still running. That
/// clears an older copy left behind when an update handoff did not exit.
enum SingleInstanceClaim {
    /// Production entry. Runs after launch so the handshake parent has already
    /// left its pipe wait before this process asks it to quit.
    @MainActor
    static func becomeOnlyInstance() {
        _ = becomeOnlyInstance(bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
                               currentProcessIdentifier: getpid(),
                               registry: RunningApplicationRegistry())
    }

    @MainActor
    @discardableResult
    static func becomeOnlyInstance(bundleIdentifier: String,
                                   currentProcessIdentifier: Int32,
                                   registry: any AppInstanceRegistry) -> [Int32] {
        guard !bundleIdentifier.isEmpty, currentProcessIdentifier > 0 else { return [] }
        let others = registry.runningInstances(bundleIdentifier: bundleIdentifier).filter {
            $0.bundleIdentifier == bundleIdentifier && $0.processIdentifier > 0
                && $0.processIdentifier != currentProcessIdentifier
        }
        var stopped: [Int32] = []
        for instance in others {
            if registry.requestTermination(instance) || registry.forceTermination(instance) {
                stopped.append(instance.processIdentifier)
            }
        }
        return stopped
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

    private func runningApplication(_ instance: AppInstance) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: instance.bundleIdentifier)
            .first { $0.processIdentifier == instance.processIdentifier }
    }
}

/// A finished update handoff quits this process. A confirm-quit prompt must not cancel it.
enum UpdateHandoffQuit {
    static func reply(handoffRequiresQuit: Bool, confirmationAllowsQuit: Bool) -> NSApplication.TerminateReply {
        if handoffRequiresQuit { return .terminateNow }
        return confirmationAllowsQuit ? .terminateNow : .terminateCancel
    }
}
