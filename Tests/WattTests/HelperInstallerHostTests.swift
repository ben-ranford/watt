import Foundation
import XCTest

/// Drives the built installer. The Xcode test bundle hosts the app, which embeds
/// this executable; launching it is what the coverage run records for that target.
final class HelperInstallerHostTests: XCTestCase {
    private func installerURL() throws -> URL {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/WattHelperInstaller")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: url.path), "Installer is embedded only in the app host")
        return url
    }

    private func runInstaller(_ arguments: [String]) throws -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = try installerURL()
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func command(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["COPYFILE_DISABLE": "1"]) { _, new in new }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            XCTFail(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
            return
        }
    }

    /// A local ad-hoc app with the identifiers and positive build the installer requires.
    private func signedApp(build: UInt64) throws -> URL {
        // The installer refuses a symlink anywhere in the source path. The
        // temporary directory is often reached through one, so start from the
        // home directory and use the resolved path.
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".watt-installer-host-" + UUID().uuidString)
            .resolvingSymlinksInPath()
        let app = root.appendingPathComponent("Watt.app")
        let binaries = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: binaries, withIntermediateDirectories: true)
        let fields: [String: String] = [
            "CFBundleIdentifier": "io.github.ben-ranford.watt",
            "CFBundleExecutable": "Watt",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": String(build),
            "LSMinimumSystemVersion": "13.0"
        ]
        try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let source = root.appendingPathComponent("fixture.c")
        try Data("int main(void) { return \(build); }\n".utf8).write(to: source)
        for (name, identifier) in [
            ("Watt", "io.github.ben-ranford.watt"),
            ("WattHelper", "io.github.ben-ranford.watt.helper"),
            ("WattMaintenance", "io.github.ben-ranford.watt.maintenance")
        ] {
            let binary = binaries.appendingPathComponent(name)
            try command("/usr/bin/clang", [source.path, "-o", binary.path])
            try command("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", identifier, binary.path])
        }
        try command("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "io.github.ben-ranford.watt", app.path])
        return app
    }

    private func approval(in output: String) throws -> String {
        let line = try XCTUnwrap(output.split(separator: "\n").first { $0.hasPrefix("Approval: ") })
        return String(line.dropFirst("Approval: ".count))
    }

    func testUsageAndMalformedCommandsExitWithoutWritingProtectedState() throws {
        let refused = try runInstaller([])
        XCTAssertEqual(refused.status, 78)
        XCTAssertTrue(refused.error.contains("Usage:"))
        XCTAssertTrue(refused.error.contains("--preflight"))
        let relative = try runInstaller(["--preflight", "--source", "Watt.app"])
        XCTAssertEqual(relative.status, 78)
        let uppercase = try runInstaller([
            "--bootstrap-reviewed", "--source", "/Applications/Watt.app",
            "--approval", String(repeating: "AB", count: 32)
        ])
        XCTAssertEqual(uppercase.status, 78)
    }

    func testPreflightPrintsTheApprovalAndRefusesADifferentTree() throws {
        let app = try signedApp(build: 7)
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        let first = try runInstaller(["--preflight", "--source", app.path])
        XCTAssertEqual(first.status, 0, first.error)
        let digest = try approval(in: first.output)
        XCTAssertEqual(digest.count, 64)
        XCTAssertTrue(digest.allSatisfy { $0.isHexDigit })
        XCTAssertTrue(first.output.contains("\"build\":7"))
        let note = app.appendingPathComponent("Contents/MacOS/note.txt")
        try Data("changed".utf8).write(to: note)
        let second = try runInstaller(["--preflight", "--source", app.path])
        XCTAssertEqual(second.status, 0, second.error)
        XCTAssertNotEqual(try approval(in: second.output), digest)
    }

    func testBootstrapWithoutAdministratorLeavesTheReviewedAppUntouched() throws {
        let app = try signedApp(build: 8)
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        let preview = try runInstaller(["--preflight", "--source", app.path])
        let digest = try approval(in: preview.output)
        let before = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        let refused = try runInstaller(["--bootstrap-reviewed", "--source", app.path, "--approval", digest])
        XCTAssertEqual(refused.status, 78)
        XCTAssertTrue(refused.error.contains("administratorRequired"))
        XCTAssertEqual(try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), before)
    }
}
