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

    private func runInstaller(_ arguments: [String], environment: [String: String] = [:]) throws -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = try installerURL()
        process.arguments = arguments
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
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
    private func signedApp(build: UInt64, directory: URL? = nil) throws -> URL {
        // The installer refuses a symlink anywhere in the source path. The
        // temporary directory is often reached through one, so start from the
        // home directory and use the resolved path.
        let root = directory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".watt-installer-host-" + UUID().uuidString)
            .resolvingSymlinksInPath()
        let app = root.appendingPathComponent(directory == nil ? "Watt.app" : "source-\(build).app")
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

    func testPreflightPrintsTheApprovalAndRefusesABrokenSignature() throws {
        let app = try signedApp(build: 7)
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }
        let first = try runInstaller(["--preflight", "--source", app.path])
        XCTAssertEqual(first.status, 0, first.error)
        let digest = try approval(in: first.output)
        XCTAssertEqual(digest.count, 64)
        XCTAssertTrue(digest.allSatisfy { $0.isHexDigit })
        XCTAssertTrue(first.output.contains("\"build\":7"))
        // A new file inside the bundle changes the sealed contents. Preflight
        // must refuse that bundle instead of printing a replacement approval.
        try Data("changed".utf8).write(to: app.appendingPathComponent("Contents/MacOS/note.txt"))
        let second = try runInstaller(["--preflight", "--source", app.path])
        XCTAssertEqual(second.status, 78, second.error)
        XCTAssertTrue(second.error.contains("invalidCode"))
        XCTAssertFalse(second.output.contains("Approval:"))
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

    /// A private 0700 directory the Debug installer may use instead of `/Library`.
    private func privateInstallRoot() throws -> URL {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".watt-installer-root-" + UUID().uuidString)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        for name in ["helpers", "launchd"] {
            let directory = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        try Data("preserve".utf8).write(to: root.appendingPathComponent("keep.txt"))
        return root
    }

    private func trustRecord(in root: URL) throws -> (installation: String, generation: Int, build: Int) {
        let url = root.appendingPathComponent("protected/helper-trust.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return (
            try XCTUnwrap(json["installationID"] as? String),
            try XCTUnwrap(json["generation"] as? NSNumber).intValue,
            try XCTUnwrap(json["build"] as? NSNumber).intValue
        )
    }

    func testDebugInstallerBootstrapsRotatesAndRemovesInsideAPrivateDirectory() throws {
        _ = try installerURL()
        let root = try privateInstallRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = ["WATT_INSTALLER_TEST_ROOT": root.path]
        let library = try runInstaller([
            "--bootstrap-reviewed", "--source", "/Applications/Watt.app",
            "--approval", String(repeating: "ab", count: 32)
        ], environment: ["WATT_INSTALLER_TEST_ROOT": "/Library"])
        XCTAssertEqual(library.status, 78)
        XCTAssertTrue(library.error.contains("refused"))
        XCTAssertFalse(library.error.contains("Installed protected generation"))

        let first = try signedApp(build: 3, directory: root)
        let preview = try runInstaller(["--preflight", "--source", first.path], environment: environment)
        XCTAssertEqual(preview.status, 0, preview.error)
        let digest = try approval(in: preview.output)
        let before = try Data(contentsOf: first.appendingPathComponent("Contents/Info.plist"))
        let mismatch = try runInstaller([
            "--bootstrap-reviewed", "--source", first.path,
            "--approval", String(repeating: "0", count: 64)
        ], environment: environment)
        XCTAssertEqual(mismatch.status, 78, mismatch.error)
        XCTAssertTrue(mismatch.error.contains("approvalMismatch"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("helpers/WattHelper").path))

        let installed = try runInstaller([
            "--bootstrap-reviewed", "--source", first.path, "--approval", digest
        ], environment: environment)
        XCTAssertEqual(installed.status, 0, installed.error)
        XCTAssertTrue(installed.output.contains("Installed protected generation 1"))
        XCTAssertTrue(installed.output.contains(root.appendingPathComponent("protected").path))
        XCTAssertFalse(installed.output.contains("/Library/Application Support/Watt"))
        let record = try trustRecord(in: root)
        XCTAssertEqual(record.generation, 1)
        XCTAssertEqual(record.build, 3)
        let helper = root.appendingPathComponent("helpers/WattHelper")
        XCTAssertEqual(try Data(contentsOf: helper), try Data(contentsOf: first.appendingPathComponent("Contents/MacOS/WattHelper")))
        let plist = try Data(contentsOf: root.appendingPathComponent("launchd/helper.plist"))
        let fields = try XCTUnwrap(PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any])
        XCTAssertEqual(fields["Label"] as? String, "io.github.ben-ranford.watt.helper")
        XCTAssertEqual(fields["ProgramArguments"] as? [String], [helper.path])
        let services = try XCTUnwrap(fields["MachServices"] as? [String: Any])
        XCTAssertEqual(services.count, 1)
        XCTAssertEqual((services["io.github.ben-ranford.watt.helper"] as? NSNumber)?.boolValue, true)
        XCTAssertEqual(fields["UserName"] as? String, "root")
        XCTAssertEqual(try Data(contentsOf: first.appendingPathComponent("Contents/Info.plist")), before)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("keep.txt")), Data("preserve".utf8))

        let sameBuild = try runInstaller([
            "--rotate-reviewed", "--source", first.path, "--approval", digest
        ], environment: environment)
        XCTAssertEqual(sameBuild.status, 78, sameBuild.error)
        XCTAssertTrue(sameBuild.error.contains("refused"))
        XCTAssertEqual(try trustRecord(in: root).generation, 1)
        XCTAssertEqual(try Data(contentsOf: helper), try Data(contentsOf: first.appendingPathComponent("Contents/MacOS/WattHelper")))

        let second = try signedApp(build: 4, directory: root)
        let nextPreview = try runInstaller(["--preflight", "--source", second.path], environment: environment)
        XCTAssertEqual(nextPreview.status, 0, nextPreview.error)
        let nextDigest = try approval(in: nextPreview.output)
        let rotated = try runInstaller([
            "--rotate-reviewed", "--source", second.path, "--approval", nextDigest
        ], environment: environment)
        XCTAssertEqual(rotated.status, 0, rotated.error)
        XCTAssertTrue(rotated.output.contains("Installed protected generation 2"))
        let replacement = try trustRecord(in: root)
        XCTAssertEqual(replacement.installation, record.installation)
        XCTAssertEqual(replacement.generation, 2)
        XCTAssertEqual(replacement.build, 4)
        XCTAssertEqual(try Data(contentsOf: helper), try Data(contentsOf: second.appendingPathComponent("Contents/MacOS/WattHelper")))
        let kept = root.appendingPathComponent("protected/generations/\(record.installation)-1/Watt.app")
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))

        let wrongGeneration = try runInstaller([
            "--remove-helper", "--installation", record.installation, "--generation", "1"
        ], environment: environment)
        XCTAssertEqual(wrongGeneration.status, 78, wrongGeneration.error)
        XCTAssertTrue(wrongGeneration.error.contains("refused"))
        XCTAssertEqual(try Data(contentsOf: helper), try Data(contentsOf: second.appendingPathComponent("Contents/MacOS/WattHelper")))

        let removed = try runInstaller([
            "--remove-helper", "--installation", record.installation, "--generation", "2"
        ], environment: environment)
        XCTAssertEqual(removed.status, 0, removed.error)
        XCTAssertTrue(removed.output.contains("Application generations retained"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: helper.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("launchd/helper.plist").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("protected/helper-trust.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("keep.txt")), Data("preserve".utf8))

        // Helper removal kept the generations. Uninstall of an older generation
        // must refuse while a newer generation is still present, and must not
        // delete that newer generation.
        let staleUninstall = try runInstaller([
            "--uninstall", "--installation", record.installation, "--generation", "1"
        ], environment: environment)
        XCTAssertEqual(staleUninstall.status, 78, staleUninstall.error)
        XCTAssertTrue(staleUninstall.error.contains("refused"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        let currentGeneration = root.appendingPathComponent("protected/generations/\(record.installation)-2/Watt.app")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentGeneration.path))

        let uninstalled = try runInstaller([
            "--uninstall", "--installation", record.installation, "--generation", "2"
        ], environment: environment)
        XCTAssertEqual(uninstalled.status, 0, uninstalled.error)
        XCTAssertTrue(uninstalled.output.contains("Protected application generations and helper removed after process cessation."))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("protected").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: kept.path))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("keep.txt")), Data("preserve".utf8))
    }
}
