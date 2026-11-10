import Foundation
import CryptoKit
@testable import Watt
import Darwin
import XCTest
import WattHelperShared
@testable import WattHelperInstaller

@MainActor
final class HelperInstallerTransactionTests: XCTestCase {
    private enum Simulated: Error { case interruption, processPresent }
    private func command(_ executable: String, _ arguments: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["COPYFILE_DISABLE": "1"]) { _, new in new }
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            XCTFail(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)); throw Simulated.interruption
        }
    }
    private func fixture() throws -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".watt-installer-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        for name in ["helpers", "launchd"] { try FileManager.default.createDirectory(at: url.appendingPathComponent(name), withIntermediateDirectories: false) }
        installerEnvironment = InstallerEnvironment(root: url.appendingPathComponent("protected"),
            helperURL: url.appendingPathComponent("helpers/WattHelper"), plistURL: url.appendingPathComponent("launchd/helper.plist"),
            owner: geteuid(), launchd: { _ in }, stopped: { _, _ in })
        return url
    }
    private func app(_ directory: URL, build: UInt64) throws -> URL {
        let app = directory.appendingPathComponent("source-\(build).app")
        let binaries = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: binaries, withIntermediateDirectories: true)
        let fields = ["CFBundleIdentifier": HelperIdentity.appIdentifier, "CFBundleExecutable": "Watt", "CFBundlePackageType": "APPL", "CFBundleVersion": String(build), "LSMinimumSystemVersion": "13.0"]
        try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        let c = directory.appendingPathComponent("fixture.c")
        try Data("int main(void) { return \(build); }".utf8).write(to: c)
        for (name, identifier) in [("Watt", HelperIdentity.appIdentifier), ("WattHelper", HelperIdentity.helperIdentifier), ("WattMaintenance", HelperIdentity.appIdentifier + ".maintenance")] {
            let binary = binaries.appendingPathComponent(name)
            try command("/usr/bin/clang", [c.path, "-o", binary.path])
            try command("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", identifier, binary.path])
        }
        try command("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", HelperIdentity.appIdentifier, app.path])
        return app
    }
    private func approve(_ app: URL, in directory: URL) throws -> String {
        let copied = directory.appendingPathComponent("preflight-" + UUID().uuidString)
        let tree = try stage(app, at: copied)
        return try inventory(copied, tree: tree).approval
    }
    private func record() throws -> ProtectedHelperRecord {
        try ProtectedHelperRecord.read(at: installerEnvironment.root.appendingPathComponent("helper-trust.json"), requiredOwner: geteuid())
    }
    func testBootstrapRotationAndExactUninstallWithInjectedAuthority() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let first = try app(directory, build: 1)
        try install(source: first, approval: approve(first, in: directory), rotate: false)
        let original = try record()
        let second = try app(directory, build: 2)
        try install(source: second, approval: approve(second, in: directory), rotate: true)
        let replacement = try record()
        XCTAssertEqual(replacement.installationID, original.installationID)
        XCTAssertEqual(replacement.generation, 2)
        for expected in [original, replacement] {
            let path = installerEnvironment.root.appendingPathComponent("generations/\(expected.installationID.uuidString)-\(expected.generation)/record.json")
            let stored = try ProtectedHelperRecord.read(at: path, expectedInstallationID: expected.installationID, requiredOwner: geteuid())
            XCTAssertEqual(stored, expected)
            XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: path.path)[.posixPermissions] as? NSNumber)?.intValue, 0o644)
        }
        XCTAssertNotEqual(replacement.appHashes, original.appHashes)
        let unrelated = directory.appendingPathComponent("unrelated")
        try Data("preserve".utf8).write(to: unrelated)
        try removeHelper(installation: replacement.installationID, generation: replacement.generation, uninstall: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.helperURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.plistURL.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("preserve".utf8))
    }
    func testInterruptedPlacementRetainsOldPinsAndRecoveryActivatesOneGeneration() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let first = try app(directory, build: 1)
        try install(source: first, approval: approve(first, in: directory), rotate: false)
        let original = try record()
        let second = try app(directory, build: 2)
        installerEnvironment.journalCheckpoint = { if $0 == "placed" { throw Simulated.interruption } }
        XCTAssertThrowsError(try install(source: second, approval: approve(second, in: directory), rotate: true))
        XCTAssertEqual(try record(), original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: installerEnvironment.root.appendingPathComponent("installer-journal.json").path))
        installerEnvironment.journalCheckpoint = nil
        try recover(installation: original.installationID, generation: 2)
        XCTAssertEqual(try record().generation, 2)
        let oldRecordURL = installerEnvironment.root.appendingPathComponent("generations/\(original.installationID.uuidString)-1/record.json")
        XCTAssertEqual(try ProtectedHelperRecord.read(at: oldRecordURL, requiredOwner: geteuid()), original)
        let nextRecordURL = installerEnvironment.root.appendingPathComponent("generations/\(original.installationID.uuidString)-2/record.json")
        XCTAssertEqual(try ProtectedHelperRecord.read(at: nextRecordURL, requiredOwner: geteuid()), try record())
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.appendingPathComponent("installer-journal.json").path))
    }
    func testChangedApprovalAndForeignResourceAndLiveProcessRefuseEffects() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let source = try app(directory, build: 1)
        XCTAssertThrowsError(try install(source: source, approval: String(repeating: "0", count: 64), rotate: false))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.helperURL.path))
        try install(source: source, approval: approve(source, in: directory), rotate: false)
        let installed = try record()
        let foreign = installerEnvironment.root.appendingPathComponent("foreign")
        try Data("preserve".utf8).write(to: foreign)
        XCTAssertThrowsError(try removeHelper(installation: installed.installationID, generation: 1, uninstall: true))
        XCTAssertEqual(try Data(contentsOf: foreign), Data("preserve".utf8))
        try FileManager.default.removeItem(at: foreign)
        installerEnvironment.stopped = { _, _ in throw Simulated.processPresent }
        XCTAssertThrowsError(try removeHelper(installation: installed.installationID, generation: 1, uninstall: true))
        XCTAssertEqual(try record(), installed)
    }
    func testInitialStagingInterruptionAndRemovalInterruptionRecoverFromJournal() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let source = try app(directory, build: 1)
        installerEnvironment.journalCheckpoint = { if $0 == "staged" { throw Simulated.interruption } }
        XCTAssertThrowsError(try install(source: source, approval: approve(source, in: directory), rotate: false))
        let journalURL = installerEnvironment.root.appendingPathComponent("installer-journal.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: journalURL)) as? [String: Any])
        let installation = try XCTUnwrap(UUID(uuidString: XCTUnwrap(json["installationID"] as? String)))
        installerEnvironment.journalCheckpoint = nil
        try recover(installation: installation, generation: 1)
        XCTAssertEqual(try record().installationID, installation)
        installerEnvironment.journalCheckpoint = { if $0 == "removed" { throw Simulated.interruption } }
        XCTAssertThrowsError(try removeHelper(installation: installation, generation: 1, uninstall: true))
        XCTAssertTrue(FileManager.default.fileExists(atPath: journalURL.path))
        installerEnvironment.journalCheckpoint = nil
        try recover(installation: installation, generation: 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.path))
    }

    func testChangedInstalledHelperIsPreservedAndRefused() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let source = try app(directory, build: 1)
        try install(source: source, approval: approve(source, in: directory), rotate: false)
        let installed = try record()
        try Data("foreign object".utf8).write(to: installerEnvironment.helperURL)
        XCTAssertThrowsError(try removeHelper(installation: installed.installationID, generation: 1, uninstall: true))
        XCTAssertEqual(try Data(contentsOf: installerEnvironment.helperURL), Data("foreign object".utf8))
        XCTAssertEqual(try record(), installed)
    }

    func testSignedReleaseRotationUsesSeparatelyProvisionedKeyAndStagedArchive() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let first = try app(directory, build: 1)
        try install(source: first, approval: approve(first, in: directory), rotate: false)
        let original = try record()
        let second = try app(directory, build: 2)
        let package = directory.appendingPathComponent("package")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false)
        try FileManager.default.copyItem(at: second, to: package.appendingPathComponent("Watt.app"))
        let archive = directory.appendingPathComponent("release.tar")
        try command("/usr/bin/tar", ["--format", "ustar", "--no-xattrs", "--no-acls", "--no-fflags", "-cf", archive.path, "-C", package.path, "Watt.app"])
        let bytes = try Data(contentsOf: archive)
        let key = Curve25519.Signing.PrivateKey()
        let manifestFile = directory.appendingPathComponent("manifest.json")
        func writeManifest(key signer: Curve25519.Signing.PrivateKey, digest: Data, minimum: String = "13.0") throws {
            let manifest = UpdateManifest(identity: HelperIdentity.appIdentifier, build: 2, sha256: digest, minimumSystemVersion: minimum)
            let payload = try JSONEncoder().encode(manifest)
            try JSONEncoder().encode(SignedUpdate(payload: payload, signature: signer.signature(for: payload))).write(to: manifestFile)
        }
        try writeManifest(key: key, digest: Data(SHA256.hash(data: bytes)))
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID))
        XCTAssertEqual(try record(), original) // Local helper bootstrap did not require this key.
        try provisionReleaseKey(installation: original.installationID, identity: HelperIdentity.appIdentifier, publicKey: key.publicKey.rawRepresentation)
        XCTAssertThrowsError(try provisionReleaseKey(installation: original.installationID, identity: HelperIdentity.appIdentifier, publicKey: key.publicKey.rawRepresentation))
        try writeManifest(key: Curve25519.Signing.PrivateKey(), digest: Data(SHA256.hash(data: bytes)))
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID))
        try writeManifest(key: key, digest: Data(repeating: 0, count: 32))
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID))
        try writeManifest(key: key, digest: Data(SHA256.hash(data: bytes)), minimum: "14.0")
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID))
        XCTAssertEqual(try record(), original)
        try writeManifest(key: key, digest: Data(SHA256.hash(data: bytes)))
        let signed = try JSONDecoder().decode(SignedUpdate.self, from: Data(contentsOf: manifestFile))
        let binaries = second.appendingPathComponent("Contents/MacOS")
        let binding = try ProtectedMaintenanceBinding(receipt: .init(id: UUID(), createdAt: Date(timeIntervalSince1970: 123456789)),
            installationID: original.installationID, previousGeneration: 1, nextGeneration: 2, operation: .update,
            signedPayloadSHA256: Data(SHA256.hash(data: signed.payload)), archiveSHA256: Data(SHA256.hash(data: bytes)), build: 2,
            replacementAppHashes: ExactCodeIdentity.allHashes(at: binaries.appendingPathComponent("Watt"), identifier: HelperIdentity.appIdentifier),
            replacementHelperHashes: ExactCodeIdentity.allHashes(at: binaries.appendingPathComponent("WattHelper"), identifier: HelperIdentity.helperIdentifier),
            replacementMaintenanceHashes: ExactCodeIdentity.allHashes(at: binaries.appendingPathComponent("WattMaintenance"), identifier: HelperIdentity.appIdentifier + ".maintenance"))
        let request = directory.appendingPathComponent("request.json")
        let bindingData = try JSONEncoder().encode(binding)
        var corrupted = try XCTUnwrap(JSONSerialization.jsonObject(with: bindingData) as? [String: Any])
        corrupted["archiveSHA256"] = Data(repeating: 0, count: 32).base64EncodedString()
        try JSONSerialization.data(withJSONObject: corrupted).write(to: request)
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID, request: request))
        corrupted = try XCTUnwrap(JSONSerialization.jsonObject(with: bindingData) as? [String: Any])
        corrupted["replacementAppHashes"] = [Data(repeating: 0, count: 20).base64EncodedString()]
        try JSONSerialization.data(withJSONObject: corrupted).write(to: request)
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID, request: request))
        XCTAssertEqual(try record(), original)
        try bindingData.write(to: request)
        installerEnvironment.journalCheckpoint = { if $0 == "activated" { throw Simulated.interruption } }
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID, request: request))
        XCTAssertEqual(try record().maintenanceBinding, binding)
        installerEnvironment.journalCheckpoint = nil
        try recover(installation: original.installationID, generation: 2)
        XCTAssertEqual(try record().maintenanceBinding, binding)
        XCTAssertEqual(try record().generation, 2)
        XCTAssertEqual(try record().build, 2)
        XCTAssertThrowsError(try rotateRelease(manifest: manifestFile, archive: archive, installation: original.installationID, request: request))
        let reused = try ProtectedMaintenanceBinding(receipt: binding.receipt, installationID: original.installationID,
            previousGeneration: 2, nextGeneration: 2, operation: .uninstall, build: 2, removalPlanSHA256: Data(repeating: 8, count: 32))
        try JSONEncoder().encode(reused).write(to: request)
        XCTAssertThrowsError(try removeHelper(installation: original.installationID, generation: 2, uninstall: true, request: request))
        let removal = try ProtectedMaintenanceBinding(receipt: .init(id: UUID(), createdAt: Date(timeIntervalSince1970: 223456789)),
            installationID: original.installationID, previousGeneration: 2, nextGeneration: 2, operation: .uninstall,
            build: 2, removalPlanSHA256: Data(repeating: 8, count: 32))
        try JSONEncoder().encode(removal).write(to: request)
        installerEnvironment.journalCheckpoint = { if $0 == "removed" { throw Simulated.interruption } }
        XCTAssertThrowsError(try removeHelper(installation: original.installationID, generation: 2, uninstall: true, request: request))
        installerEnvironment.journalCheckpoint = nil
        try recover(installation: original.installationID, generation: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.path))
        let resultURL = directory.appendingPathComponent("Watt-maintenance-result.json")
        let result = try ProtectedMaintenanceBinding.decode(ProtectedHelperRecord.readProtectedFile(at: resultURL, requiredOwner: geteuid()))
        XCTAssertEqual(result, removal)
        let permissions = try FileManager.default.attributesOfItem(atPath: resultURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o644)
    }

    func testSwappedHistoricalGenerationRecordRefusesRotationBeforeHelperReplacement() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let first = try app(directory, build: 1)
        try install(source: first, approval: approve(first, in: directory), rotate: false)
        let original = try record()
        let originalHelper = try Data(contentsOf: installerEnvironment.helperURL)
        let path = installerEnvironment.root.appendingPathComponent("generations/\(original.installationID.uuidString)-1/record.json")
        let changed = try ProtectedHelperRecord(installationID: original.installationID, generation: 1, build: 1,
            appHashes: [Data(repeating: 9, count: 20)], helperHashes: original.helperHashes, maintenanceHashes: original.maintenanceHashes)
        try JSONEncoder().encode(changed).write(to: path)
        let second = try app(directory, build: 2)
        XCTAssertThrowsError(try install(source: second, approval: approve(second, in: directory), rotate: true))
        XCTAssertEqual(try record(), original)
        XCTAssertEqual(try Data(contentsOf: installerEnvironment.helperURL), originalHelper)
        XCTAssertEqual(try ProtectedHelperRecord.read(at: path, requiredOwner: geteuid()), changed)
    }

    func testBoundFullUninstallUsesHistoricalRecordAfterHelperOnlyRemoval() throws {
        let directory = try fixture()
        defer { installerEnvironment = .production; try? FileManager.default.removeItem(at: directory) }
        let source = try app(directory, build: 1)
        try install(source: source, approval: approve(source, in: directory), rotate: false)
        let installed = try record()
        try removeHelper(installation: installed.installationID, generation: installed.generation)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.appendingPathComponent("helper-trust.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.helperURL.path))
        let historicalURL = installerEnvironment.root.appendingPathComponent("generations/\(installed.installationID.uuidString)-1/record.json")
        XCTAssertEqual(try ProtectedHelperRecord.read(at: historicalURL, requiredOwner: geteuid()), installed)
        let binding = try ProtectedMaintenanceBinding(receipt: .init(id: UUID(), createdAt: Date(timeIntervalSince1970: 323456789)),
            installationID: installed.installationID, previousGeneration: installed.generation, nextGeneration: installed.generation,
            operation: .uninstall, build: installed.build, removalPlanSHA256: Data(repeating: 4, count: 32))
        let request = directory.appendingPathComponent("request.json")
        try JSONEncoder().encode(binding).write(to: request)
        try removeHelper(installation: installed.installationID, generation: installed.generation, uninstall: true, request: request)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.root.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installerEnvironment.plistURL.path))
        let result = try ProtectedMaintenanceBinding.decode(ProtectedHelperRecord.readProtectedFile(
            at: directory.appendingPathComponent("Watt-maintenance-result.json"), requiredOwner: geteuid()))
        XCTAssertEqual(result, binding)
    }

}
