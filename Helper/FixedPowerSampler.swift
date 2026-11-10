import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

public protocol HelperCaptureRunning: Sendable {
    func capture() async -> HelperCapture
}

/// Never accepts executable names, command arguments, environment, or output paths from a peer.
public struct FixedPowerSampler: HelperCaptureRunning {
    public static let executable = "/usr/bin/powermetrics"
    public static let arguments = ["-f", "plist", "-n", "1", "-i", "1000", "-s", "cpu_power,gpu_power"]

    public init() {}

    public func capture() async -> HelperCapture {
        await Self.captureCommand(executable: Self.executable, arguments: Self.arguments)
    }

    // Internal, fixed fixtures for adversarial process tests; no XPC surface or caller-selected command.
    enum TestFixture: Sendable {
        case ignoresTermination, overflowingStreams, successful

        var script: String {
            switch self {
            case .ignoresTermination: return "trap '' TERM; echo $$; while :; do :; done"
            case .overflowingStreams: return "while :; do printf '0123456789abcdef0123456789abcdef'; printf 'fedcba9876543210fedcba9876543210' >&2; done"
            case .successful: return "printf 'fixture complete'"
            }
        }
    }

    static func captureFixture(_ fixture: TestFixture) async -> HelperCapture {
        await captureCommand(executable: "/bin/sh", arguments: ["-c", fixture.script])
    }

    private static func captureCommand(executable: String, arguments: [String]) async -> HelperCapture {
        let cancellation = CaptureCancellation()
        return await withTaskCancellationHandler {
            await Task.detached { Self.run(cancellation, executable: executable, arguments: arguments) }.value
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func run(_ cancellation: CaptureCancellation, executable: String, arguments: [String]) -> HelperCapture {
        let startedAt = Date()
        let start = DispatchTime.now().uptimeNanoseconds
        func elapsed() -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000 }
        var out: [Int32] = [-1, -1]
        var err: [Int32] = [-1, -1]
        var stdout = Data(), stderr = Data()
        var status: HelperCaptureStatus = .launchFailed
        var exitStatus: Int32?
        var reaped = true
        defer {
            for fd in out + err where fd >= 0 { close(fd) }
        }
        func result() -> HelperCapture {
            .init(startedAt: startedAt, duration: elapsed(), stdout: stdout, stderr: stderr,
                  exitStatus: exitStatus, status: status, terminationConfirmed: reaped)
        }
        guard !cancellation.isCancelled else {
            status = .cancelled
            reaped = true // No child was created.
            return result()
        }
        guard pipe(&out) == 0, pipe(&err) == 0 else { return result() }
        for fd in out + err {
            guard fcntl(fd, F_SETFD, FD_CLOEXEC) != -1 else { return result() }
        }
        for fd in [out[0], err[0]] {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) != -1 else { return result() }
        }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { return result() }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { return result() }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0) == 0,
              posix_spawn_file_actions_adddup2(&actions, out[1], STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, err[1], STDERR_FILENO) == 0,
              posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0 else { return result() }
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        // Deliberately fixed minimal environment; no inherited DYLD or caller state.
        let env = [strdup("PATH=/usr/bin:/bin"), strdup("LC_ALL=C"), nil]
        defer { for pointer in argv + env { free(pointer) } }
        var pid: pid_t = 0
        let spawnResult = argv.withUnsafeBufferPointer { args in
            env.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable, &actions, &attributes,
                            UnsafeMutablePointer(mutating: args.baseAddress!),
                            UnsafeMutablePointer(mutating: environment.baseAddress!))
            }
        }
        close(out[1]); out[1] = -1
        close(err[1]); err[1] = -1
        guard spawnResult == 0 else { reaped = true; return result() }
        reaped = false
        status = .completed
        var ownsChild = true
        var terminationStarted: Double?
        var sentKill = false
        var outEOF = false, errEOF = false
        var buffer = [UInt8](repeating: 0, count: 8192)

        func drain(_ fd: Int32, into data: inout Data, eof: inout Bool) {
            // Limit each drain pass so a continuously writing child cannot starve deadlines.
            for _ in 0..<16 {
                let count = read(fd, &buffer, buffer.count)
                if count == 0 { eof = true; return }
                if count < 0 {
                    if errno != EAGAIN && errno != EINTR { eof = true }
                    return
                }
                let room = HelperLimits.captureBytes - stdout.count - stderr.count - data.count
                data.append(contentsOf: buffer.prefix(min(count, max(0, room))))
                if count > room { status = .outputLimit; return }
            }
        }

        while elapsed() < HelperLimits.runtimeSeconds {
            // Use local copies to avoid Swift exclusivity conflict with total byte accounting.
            var nextOut = Data(), nextErr = Data()
            drain(out[0], into: &nextOut, eof: &outEOF)
            stdout.append(nextOut)
            drain(err[0], into: &nextErr, eof: &errEOF)
            stderr.append(nextErr)
            var rawStatus: Int32 = 0
            if !reaped {
                let waited = waitpid(pid, &rawStatus, WNOHANG)
                if waited == pid { reaped = true; exitStatus = (rawStatus & 0x7f) == 0 ? (rawStatus >> 8) & 0xff : 128 + (rawStatus & 0x7f) }
                else if waited < 0 && errno != EINTR {
                    // An unexpected external reaper invalidates PID ownership. Never signal again.
                    ownsChild = false
                    status = .interrupted
                    break
                }
            }
            if reaped && outEOF && errEOF { break }
            if cancellation.isCancelled { status = .cancelled }
            // Reserve the final second of the four-second budget for termination and drain.
            if elapsed() >= HelperLimits.runtimeSeconds - 1 && status == .completed { status = .timedOut }
            if status != .completed, terminationStarted == nil {
                terminationStarted = elapsed()
                if !reaped { _ = kill(pid, SIGTERM) }
            }
            if let terminationStarted, elapsed() - terminationStarted >= 0.5, !sentKill {
                // Child remains unreaped here, so its PID cannot have been reused.
                if !reaped { _ = kill(pid, SIGKILL) }
                sentKill = true
            }
            usleep(5_000)
        }
        if !reaped && ownsChild {
            // Never report absence unless waitpid proves it. Admission must close on interrupted.
            _ = kill(pid, SIGKILL)
            var rawStatus: Int32 = 0
            if waitpid(pid, &rawStatus, WNOHANG) == pid { reaped = true; exitStatus = (rawStatus & 0x7f) == 0 ? (rawStatus >> 8) & 0xff : 128 + (rawStatus & 0x7f) }
            if !reaped {
                status = .interrupted
                // Keep ownership of the unreaped child after bounded return; do not leak a zombie.
                // This worker has no admission and sends no further signals.
                let unreapedPID = pid
                DispatchQueue.global(qos: .utility).async {
                    var ignored: Int32 = 0
                    while waitpid(unreapedPID, &ignored, 0) < 0 && errno == EINTR {}
                }
            }
        }
        if !(outEOF && errEOF), status == .completed { status = .interrupted }
        return result()
    }
}

private final class CaptureCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isCancelled: Bool { lock.withLock { value } }
    func cancel() { lock.withLock { value = true } }
}

/// One instance belongs to the daemon, shared by every authenticated connection.
public actor HelperSamplerCoordinator {
    private let runner: any HelperCaptureRunning
    private let now: @Sendable () -> Double
    private var lastStart: Double?
    private var active: Task<HelperCapture, Never>?
    private var accepting = true
    private var waitingRequests = 0

    public init(runner: any HelperCaptureRunning = FixedPowerSampler(),
                now: @escaping @Sendable () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.runner = runner
        self.now = now
    }

    /// Returns nil during the minimum interval; never queues or bursts missed acquisitions.
    public func capture() async -> HelperCapture? {
        guard accepting, waitingRequests < 16 else { return nil }
        waitingRequests += 1
        defer { waitingRequests -= 1 }
        if let active { return await active.value }
        let start = now()
        if let lastStart, start - lastStart < HelperLimits.minimumStartInterval { return nil }
        lastStart = start
        let task = Task { await runner.capture() }
        active = task
        let capture = await task.value
        active = nil
        if !capture.terminationConfirmed { accepting = false }
        return capture
    }

    public func stop() async {
        accepting = false
        guard let active else { return }
        active.cancel()
        _ = await active.value
        self.active = nil
    }
}
