import Foundation
import XCTest
@testable import WattHelperInstaller

@MainActor
final class HelperInstallerPreflightTests: XCTestCase {
    private func workspace() throws -> URL {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".watt-preflight-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func testPrivateStagingCopiesBytesAndBindsCompleteTree() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let input = source.appendingPathComponent("payload")
        try Data("reviewed payload".utf8).write(to: input)
        let first = root.appendingPathComponent("first")
        let digest = try stage(source, at: first)
        XCTAssertEqual(try Data(contentsOf: first.appendingPathComponent("payload")), Data("reviewed payload".utf8))
        XCTAssertEqual(try stage(source, at: root.appendingPathComponent("second")), digest)
        try Data("replacement payload".utf8).write(to: input)
        XCTAssertNotEqual(try stage(source, at: root.appendingPathComponent("third")), digest)
        XCTAssertEqual(try Data(contentsOf: first.appendingPathComponent("payload")), Data("reviewed payload".utf8))
        XCTAssertThrowsError(try inventory(first, tree: digest)) // Missing signed bundle never gets approved.
    }

    func testStagingRejectsFileLinksAndLinkedSourceAncestors() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let external = root.appendingPathComponent("outside")
        try Data("unowned".utf8).write(to: external)
        try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("link"), withDestinationURL: external)
        XCTAssertThrowsError(try stage(source, at: root.appendingPathComponent("rejected")))
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)
        XCTAssertThrowsError(try stage(alias, at: root.appendingPathComponent("also-rejected")))
        XCTAssertEqual(try Data(contentsOf: external), Data("unowned".utf8))
    }

    func testStagingRefusesToOverwriteExistingObject() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source"), destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        try Data("new".utf8).write(to: source.appendingPathComponent("payload"))
        try Data("existing".utf8).write(to: destination.appendingPathComponent("payload"))
        XCTAssertThrowsError(try stage(source, at: destination))
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("payload")), Data("existing".utf8))
    }
}
