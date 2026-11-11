import Foundation

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

    static func run(_ command: Command) async -> Result<String, ServiceFailure> {
        await Task.detached { command.privileged ? runPrivileged(command) : runDirect(command) }.value
    }

    private static func runDirect(_ command: Command) -> Result<String, ServiceFailure> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() } catch { return .failure(.unknownStatus) }
        process.waitUntilExit()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { return .failure(.unknownStatus) }
        return .success(text)
    }

    /// macOS shows the standard administrator password dialog. The installer still
    /// re-checks the preflight digest against the staged bytes before it writes.
    private static func runPrivileged(_ command: Command) -> Result<String, ServiceFailure> {
        let shell = ([command.executable] + command.arguments).map(shellQuote).joined(separator: " ")
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() } catch { return .failure(.unknownStatus) }
        process.waitUntilExit()
        let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            if errorText.localizedCaseInsensitiveContains("User canceled")
                || errorText.contains("-128") { return .failure(.cancelled) }
            return .failure(.adminRequired)
        }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return .success(text)
    }

    private static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
