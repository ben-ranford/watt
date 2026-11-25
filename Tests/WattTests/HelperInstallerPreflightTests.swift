import Foundation
import XCTest
#if SWIFT_PACKAGE
import WattHelperShared
@testable import WattHelperInstaller
#else
@testable import Watt
#endif

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

    func testStagingKeepsExecutableBitsAndRefusesParentTraversal() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        let script = source.appendingPathComponent("tool")
        let note = source.appendingPathComponent("note")
        try Data("#!/bin/sh\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        try Data("note".utf8).write(to: note)
        let staged = root.appendingPathComponent("staged")
        _ = try stage(source, at: staged)
        let toolMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: staged.appendingPathComponent("tool").path)[.posixPermissions] as? NSNumber)
        let noteMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: staged.appendingPathComponent("note").path)[.posixPermissions] as? NSNumber)
        XCTAssertEqual(toolMode.intValue, 0o755)
        XCTAssertEqual(noteMode.intValue, 0o644)
        let escaped = try XCTUnwrap(URL(string: "file://\(source.path)/../source"))
        XCTAssertTrue(escaped.pathComponents.contains(".."))
        XCTAssertThrowsError(try stage(escaped, at: root.appendingPathComponent("escaped")))
    }

    func testInventoryRefusesABundleThatIsNotTheReviewedApp() throws {
        let root = try workspace(); defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Watt.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let fields = ["CFBundleIdentifier": "io.example.other", "CFBundleExecutable": "Watt", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        XCTAssertThrowsError(try inventory(app, tree: String(repeating: "a", count: 64)))
        let zero = ["CFBundleIdentifier": HelperIdentity.appIdentifier, "CFBundleExecutable": "Watt", "CFBundleVersion": "0"]
        try PropertyListSerialization.data(fromPropertyList: zero, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        XCTAssertThrowsError(try inventory(app, tree: String(repeating: "a", count: 64)))
    }
}
