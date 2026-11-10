import Foundation
import Security
import XCTest
#if SWIFT_PACKAGE
import WattHelperShared
#endif
@testable import Watt

final class ProtectedHelperTrustTests: XCTestCase {
    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let output = Pipe(); process.standardError = output; process.standardOutput = output
        try process.run(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
    }
    func testActualUniversalAdHocCodeAcceptsExactHashesAndRejectsWrongHash() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("fixture.c")
        let binary = directory.appendingPathComponent("fixture")
        try Data("int main(void) { return 0; }".utf8).write(to: source)
        try run("/usr/bin/clang", ["-arch", "arm64", "-arch", "x86_64", source.path, "-o", binary.path])
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", HelperIdentity.appIdentifier, binary.path])
        let hashes = try ExactCodeIdentity.allHashes(at: binary, identifier: HelperIdentity.appIdentifier)
        XCTAssertEqual(hashes.count, 2)
        let requirement = try ExactCodeIdentity.requirement(hashes: hashes, identifier: HelperIdentity.appIdentifier)
        XCTAssertTrue(hashes.contains(try ExactCodeIdentity.verify(at: binary, requirement: requirement)))
        let wrong = try ExactCodeIdentity.requirement(hashes: [Data(repeating: 0, count: 20)], identifier: HelperIdentity.appIdentifier)
        XCTAssertThrowsError(try ExactCodeIdentity.verify(at: binary, requirement: wrong))
        XCTAssertThrowsError(try HelperSigningPolicy(team: "ABCDE12345").verifyExecutable(at: binary, helper: false))
        try Data("int main(void) { return 7; }".utf8).write(to: source)
        try run("/usr/bin/clang", ["-arch", "arm64", "-arch", "x86_64", source.path, "-o", binary.path])
        try run("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", HelperIdentity.appIdentifier, binary.path])
        XCTAssertThrowsError(try ExactCodeIdentity.verify(at: binary, requirement: requirement))
    }

    func testRootRecordRefusesUserOwnedAndSymlinkedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let record = try ProtectedHelperRecord(installationID: UUID(), generation: 1, build: 1,
            appHashes: [Data(repeating: 1, count: 20)], helperHashes: [Data(repeating: 2, count: 20)], maintenanceHashes: [Data(repeating: 3, count: 20)])
        let file = directory.appendingPathComponent("trust.json")
        try JSONEncoder().encode(record).write(to: file)
        XCTAssertThrowsError(try ProtectedHelperRecord.read(at: file))
        let link = directory.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try ProtectedHelperRecord.read(at: link))
    }

    func testInvalidPinSetsAndModesFailClosed() throws {
        XCTAssertThrowsError(try ProtectedHelperRecord(installationID: UUID(), generation: 0, build: 1,
            appHashes: [Data(repeating: 1, count: 20)], helperHashes: [Data(repeating: 2, count: 20)], maintenanceHashes: [Data(repeating: 3, count: 20)]))
        XCTAssertThrowsError(try ExactCodeIdentity.requirement(hashes: [Data(repeating: 1, count: 19)], identifier: HelperIdentity.appIdentifier))
        XCTAssertNotEqual(HelperPeer(identifier: "helper", team: "ABCDE12345", protocolVersion: 1).identity,
                          HelperPeerIdentity.protectedCodeHash(installationID: UUID(), generation: 1, cdhash: Data(repeating: 1, count: 20)))
    }

    func testReleaseRequirementPinsCdhashAndDoesNotAcceptAnyCaller() throws {
        XCTAssertEqual(HelperTrustMode(plistValue: nil), .protectedInstallation)
        XCTAssertEqual(HelperTrustMode(plistValue: "protected-installation"), .protectedInstallation)
        XCTAssertEqual(HelperTrustMode(plistValue: "certificate"), .certificate)
        XCTAssertNil(HelperTrustMode(plistValue: ""))
        XCTAssertNil(HelperTrustMode(plistValue: "identifier"))
        let hash = Data(repeating: 0xab, count: 20)
        let record = try ProtectedHelperRecord(installationID: UUID(), generation: 1, build: 1,
            appHashes: [hash], helperHashes: [hash], maintenanceHashes: [hash])
        let requirement = try HelperTrustPolicy.protectedInstallation(record).appRequirement
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertTrue(requirement.contains("identifier \"\(HelperIdentity.appIdentifier)\""))
        XCTAssertTrue(requirement.contains("cdhash H\"\(hex)\""))
        XCTAssertFalse(requirement.contains("anchor apple"))
        XCTAssertFalse(requirement.contains("certificate leaf"))
        XCTAssertThrowsError(try ExactCodeIdentity.requirement(hashes: [], identifier: HelperIdentity.appIdentifier))
    }

    func testVerifiedUpdateBindingReplacesAStaleCdhash() throws {
        let previous = Data(repeating: 1, count: 20)
        let replacement = Data(repeating: 2, count: 20)
        let stale = try ExactCodeIdentity.requirement(hashes: [previous], identifier: HelperIdentity.appIdentifier)
        XCTAssertFalse(stale.contains("cdhash H\"" + replacement.map { String(format: "%02x", $0) }.joined() + "\""))
        let receipt = ProtectedMaintenanceReceipt(id: UUID(), createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let payload = Data(repeating: 9, count: 32)
        let archive = Data(repeating: 8, count: 32)
        XCTAssertThrowsError(try ProtectedMaintenanceBinding(receipt: receipt, installationID: UUID(), previousGeneration: 1,
            nextGeneration: 2, operation: .update, build: 2, replacementAppHashes: [replacement],
            replacementHelperHashes: [replacement], replacementMaintenanceHashes: [replacement]))
        let installation = UUID()
        let binding = try ProtectedMaintenanceBinding(receipt: receipt, installationID: installation, previousGeneration: 1,
            nextGeneration: 2, operation: .update, signedPayloadSHA256: payload, archiveSHA256: archive, build: 2,
            replacementAppHashes: [replacement], replacementHelperHashes: [replacement], replacementMaintenanceHashes: [replacement])
        XCTAssertThrowsError(try ProtectedHelperRecord(installationID: installation, generation: 2, build: 2,
            appHashes: [previous], helperHashes: [replacement], maintenanceHashes: [replacement], maintenanceBinding: binding))
        let adopted = try ProtectedHelperRecord(installationID: installation, generation: 2, build: 2,
            appHashes: [replacement], helperHashes: [replacement], maintenanceHashes: [replacement], maintenanceBinding: binding)
        let requirement = try HelperTrustPolicy.protectedInstallation(adopted).appRequirement
        XCTAssertTrue(requirement.contains("cdhash H\"" + replacement.map { String(format: "%02x", $0) }.joined() + "\""))
        XCTAssertFalse(requirement.contains("cdhash H\"" + previous.map { String(format: "%02x", $0) }.joined() + "\""))
        XCTAssertFalse(requirement.contains("anchor apple"))
    }

    func testQuarantineClearLeavesOtherAttributesAndRejectsLinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = directory.appendingPathComponent("Watt.app")
        let contents = bundle.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let file = contents.appendingPathComponent("Watt")
        try Data("binary".utf8).write(to: file)
        let marker = "keep"
        XCTAssertEqual(setExtendedAttribute("user.watt-test", marker, at: file), 0)
        func quarantine(_ url: URL) {
            XCTAssertEqual(setExtendedAttribute(QuarantineAttribute.name, "0083;00000000;WattTest;", at: url), 0)
        }
        quarantine(bundle)
        quarantine(file)
        try QuarantineAttribute.clear(at: bundle)
        XCTAssertFalse(hasQuarantine(bundle))
        XCTAssertFalse(hasQuarantine(file))
        var kept = [UInt8](repeating: 0, count: 8)
        let keptCount = kept.withUnsafeMutableBytes { buffer in
            getxattr(file.path, "user.watt-test", buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
        }
        XCTAssertEqual(keptCount, marker.utf8.count)
        let outside = directory.appendingPathComponent("outside")
        try Data("secret".utf8).write(to: outside)
        quarantine(outside)
        let link = contents.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try QuarantineAttribute.clear(at: bundle))
        XCTAssertTrue(hasQuarantine(outside))
    }

    private func hasQuarantine(_ url: URL) -> Bool {
        getxattr(url.path, QuarantineAttribute.name, nil, 0, 0, XATTR_NOFOLLOW) >= 0
    }
}

private func setExtendedAttribute(_ name: String, _ value: String, at url: URL) -> Int32 {
    Array(value.utf8).withUnsafeBytes { buffer in
        setxattr(url.path, name, buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
    }
}
