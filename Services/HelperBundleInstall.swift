import Foundation
import Darwin

/// Runs the bundled administrator installer. Ad-hoc releases pin the helper to
/// an exact code hash, which `SMAppService` registration does not write, so the
/// reviewed installer is the supported way to put the helper on a Homebrew Mac.
enum HelperBundleInstall {
    struct Command: Equatable, Sendable {
        var executable: String
        var arguments: [String]
        var privileged: Bool
    }

    static func preflight(installer: URL, source: URL) -> Command {
        Command(executable: installer.path, arguments: ["--preflight", "--source", source.path], privileged: false)
    }

    static func reviewed(installer: URL, source: URL, approval: String, rotate: Bool) -> Command {
        Command(executable: installer.path, arguments: [
            rotate ? "--rotate-reviewed" : "--bootstrap-reviewed",
            "--source", source.path,
            "--approval", approval
        ], privileged: true)
    }

    /// The installer prints `Approval: <64 lowercase hex>` after a successful preflight.
    static func approvalDigest(in output: String) -> String? {
        for line in output.split(whereSeparator: \.isNewline) {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("Approval: ") else { continue }
            let digest = String(text.dropFirst("Approval: ".count))
            let hex = Set("0123456789abcdef")
            guard digest.count == 64, digest.allSatisfy({ hex.contains($0) }) else { return nil }
            return digest
        }
        return nil
    }

    @MainActor
    static func install(installer: URL, source: URL, rotate: Bool,
                        run: @escaping (Command) async -> Result<String, ServiceFailure> = Self.run) async -> ServiceFailure? {
        let preflight = await run(preflight(installer: installer, source: source))
        let output: String
        switch preflight {
        case .success(let text): output = text
        case .failure(let failure): return failure
        }
        guard let approval = approvalDigest(in: output) else { return .invalidData }
        switch await run(reviewed(installer: installer, source: source, approval: approval, rotate: rotate)) {
        case .success: return nil
        case .failure(let failure): return failure
        }
    }

    /// Preflight only copies and hashes the bundle.
    static let preflightTimeout: TimeInterval = 120
    /// Includes the time the macOS password prompt is on screen.
    static let administratorTimeout: TimeInterval = 600

    static func run(_ command: Command) async -> Result<String, ServiceFailure> {
        await Task.detached {
            command.privileged
                ? runPrivileged(command, timeout: administratorTimeout)
                : runDirect(command, timeout: preflightTimeout)
        }.value
    }

    enum ProcessRun: Equatable, Sendable {
        case exited(status: Int32, output: String, errors: String)
        case timedOut
        case launchFailed
    }

    /// Runs a tool and waits at most `timeout`. A tool still running then is
    /// stopped, so a caller is never left waiting without an answer.
    static func execute(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> ProcessRun {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return .launchFailed }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 2)
            }
            return .timedOut
        }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return .exited(status: process.terminationStatus, output: text, errors: errorText)
    }

    static func runDirect(_ command: Command, timeout: TimeInterval) -> Result<String, ServiceFailure> {
        switch execute(command.executable, command.arguments, timeout: timeout) {
        case .exited(0, let text, _): return .success(text)
        case .exited: return .failure(.unknownStatus)
        case .timedOut: return .failure(.timedOut)
        case .launchFailed: return .failure(.unknownStatus)
        }
    }

    /// macOS shows the standard administrator password dialog. The installer still
    /// re-checks the preflight digest against the staged bytes before it writes.
    static func runPrivileged(_ command: Command, timeout: TimeInterval) -> Result<String, ServiceFailure> {
        let shell = ([command.executable] + command.arguments).map(shellQuote).joined(separator: " ")
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        return privilegedOutcome(execute("/usr/bin/osascript", ["-e", source], timeout: timeout))
    }

    static func privilegedOutcome(_ run: ProcessRun) -> Result<String, ServiceFailure> {
        switch run {
        case .exited(0, let text, _): return .success(text)
        case .exited(_, _, let errorText):
            if errorText.localizedCaseInsensitiveContains("User canceled")
                || errorText.contains("-128") { return .failure(.cancelled) }
            return .failure(.adminRequired)
        case .timedOut: return .failure(.timedOut)
        case .launchFailed: return .failure(.unknownStatus)
        }
    }

    private static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
