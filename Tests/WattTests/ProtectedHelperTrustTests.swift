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
}
