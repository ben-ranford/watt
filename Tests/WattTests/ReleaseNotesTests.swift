import AppKit
import CryptoKit
import SwiftUI
import XCTest
@testable import Watt

final class ReleaseNotesTests: XCTestCase {
    private func trust(publicKey: Curve25519.Signing.PublicKey) -> UpdateTrust {
        UpdateTrust(identity: "test.watt", currentBuild: 1,
                    hostSystemVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 2, patchVersion: 0),
                    publicKey: publicKey)
    }

    private func signed(_ payload: Data, key: Curve25519.Signing.PrivateKey) throws -> SignedUpdate {
        SignedUpdate(payload: payload, signature: try key.signature(for: payload))
    }

    func testMissingNotesStillVerifyAndStayOutOfTheEncodedPayload() throws {
        let key = Curve25519.Signing.PrivateKey()
        let digest = Data(SHA256.hash(data: Data("watt".utf8)))
        let manifest = UpdateManifest(identity: "test.watt", build: 2, sha256: digest, minimumSystemVersion: "13.0")
        let encoded = try JSONEncoder().encode(manifest)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("notes"))
        let authenticated = try trust(publicKey: key.publicKey).authenticate(try signed(encoded, key: key))
        XCTAssertNil(authenticated.notes)
        XCTAssertEqual(authenticated.build, 2)

        let legacy = #"{"identity":"test.watt","build":2,"sha256":"\#(digest.base64EncodedString())","minimumSystemVersion":"13.0"}"#
        let legacyManifest = try trust(publicKey: key.publicKey).authenticate(try signed(Data(legacy.utf8), key: key))
        XCTAssertNil(legacyManifest.notes)
        let explicitNull = legacy.replacingOccurrences(of: "}", with: #","notes":null}"#)
        XCTAssertNil(try trust(publicKey: key.publicKey).authenticate(try signed(Data(explicitNull.utf8), key: key)).notes)
    }

    func testNotesAreCoveredByTheSignatureAndRejectedWhenMalformed() throws {
        let key = Curve25519.Signing.PrivateKey()
        let digest = Data(SHA256.hash(data: Data("watt".utf8)))
        let notes = "### Fixes\n\n* one"
        let payload = try JSONSerialization.data(withJSONObject: [
            "identity": "test.watt", "build": 2, "sha256": digest.base64EncodedString(),
            "minimumSystemVersion": "13.0", "notes": notes,
        ])
        let checker = trust(publicKey: key.publicKey)
        let release = try signed(payload, key: key)
        XCTAssertEqual(try checker.authenticate(release).notes, notes)

        var tampered = payload
        let needle = Data("one".utf8)
        let range = try XCTUnwrap(tampered.range(of: needle))
        tampered[range.lowerBound] = UInt8(ascii: "X")
        XCTAssertThrowsError(try checker.authenticate(SignedUpdate(payload: tampered, signature: release.signature))) { error in
            XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity)
        }

        let tooLong = String(repeating: "a", count: UpdateReleaseNotes.maximumUTF8Length + 1)
        let longManifest = UpdateManifest(identity: "test.watt", build: 2, sha256: digest, minimumSystemVersion: "13.0", notes: tooLong)
        let longPayload = try JSONEncoder().encode(longManifest)
        let longRelease = try signed(longPayload, key: key)
        XCTAssertTrue(key.publicKey.isValidSignature(longRelease.signature, for: longPayload))
        XCTAssertThrowsError(try checker.authenticate(longRelease)) { error in
            XCTAssertEqual(error as? ServiceFailure, .invalidData)
        }

        let control = UpdateManifest(identity: "test.watt", build: 2, sha256: digest, minimumSystemVersion: "13.0", notes: "ok\u{0001}")
        let controlPayload = try JSONEncoder().encode(control)
        let controlRelease = try signed(controlPayload, key: key)
        XCTAssertTrue(key.publicKey.isValidSignature(controlRelease.signature, for: controlPayload))
        XCTAssertThrowsError(try checker.authenticate(controlRelease)) { error in
            XCTAssertEqual(error as? ServiceFailure, .invalidData)
        }
    }

    func testPromptTextRendersMarkdownAndLimitsLength() {
        XCTAssertNil(UpdateReleaseNotes.promptText(nil))
        XCTAssertNil(UpdateReleaseNotes.promptText(" \n\t "))
        XCTAssertNil(UpdateReleaseNotes.promptText("bad\u{0007}"))
        XCTAssertEqual(UpdateReleaseNotes.promptText("### Fixes\n\n* one"), "### Fixes\n\n* one")
        let long = String(repeating: "line\n", count: 800)
        let shown = UpdateReleaseNotes.promptText(long)
        XCTAssertLessThanOrEqual(shown?.count ?? 0, UpdateReleaseNotes.displayLimit + "\n\n...".count)
        XCTAssertTrue(shown?.hasSuffix("\n\n...") == true)
        let rendered = UpdateReleaseNotes.blocks("### Fixes\n\n* **steadier** numbers")
        XCTAssertEqual(rendered.map(\.kind), [.heading(3), .bullet])
        XCTAssertEqual(rendered.map(\.plain), ["Fixes", "steadier numbers"])
        XCTAssertTrue(rendered[1].inline.runs.contains {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
        XCTAssertEqual(UpdateReleaseNotes.unavailable, "Release notes aren’t available for this version.")
        let clipped = UpdateReleaseNotes.blocks(shown ?? "")
        XCTAssertEqual(clipped.last?.kind, .paragraph)
        XCTAssertEqual(clipped.last?.plain, "...")
    }

    func testBlocksKeepHeadingsBulletsAndParagraphsApart() {
        let notes = """
        # Release

        This is a paragraph
        that stays together.

        Another paragraph with **bold** and [notes](https://example.com/notes).

        * first item
        - second **item**
        + third item
        1. fourth item
        2) fifth item
        """
        let blocks = UpdateReleaseNotes.blocks(notes.replacingOccurrences(of: "\n", with: "\r\n"))
        XCTAssertEqual(blocks.map(\.kind), [
            .heading(1), .paragraph, .paragraph, .bullet, .bullet, .bullet, .bullet, .bullet,
        ])
        XCTAssertEqual(blocks[0].plain, "Release")
        XCTAssertNil(blocks[0].marker)
        XCTAssertTrue(blocks[0].isHeader)
        XCTAssertEqual(blocks[0].spoken, "Release")
        XCTAssertEqual(blocks[1].plain, "This is a paragraph that stays together.")
        XCTAssertEqual(blocks[1].kind, .paragraph)
        XCTAssertEqual(blocks[2].plain, "Another paragraph with bold and notes.")
        XCTAssertTrue(blocks[2].inline.runs.contains {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
        XCTAssertTrue(blocks[2].inline.runs.contains { $0.link?.absoluteString == "https://example.com/notes" })
        XCTAssertEqual(blocks[3].marker, "•")
        XCTAssertEqual(blocks[3].spoken, "• first item")
        XCTAssertEqual(blocks[4].plain, "second item")
        XCTAssertEqual(blocks[4].marker, "•")
        XCTAssertEqual(blocks[5].marker, "•")
        XCTAssertEqual(blocks[5].plain, "third item")
        XCTAssertEqual(blocks[6].marker, "1.")
        XCTAssertEqual(blocks[6].plain, "fourth item")
        XCTAssertEqual(blocks[7].marker, "2)")
        XCTAssertEqual(blocks[7].spoken, "2) fifth item")
        XCTAssertEqual(UpdateReleaseNotes.blocks(" \n\n "), [])
        XCTAssertEqual(UpdateReleaseNotes.blocks(""), [])
    }

    func testWhatsNewSampleNotesDoNotRunTogether() throws {
        let notes = "### Changes\n\n* Updates roll out gradually\n* What’s New appears once after you update"
        let blocks = UpdateReleaseNotes.blocks(notes)
        XCTAssertEqual(blocks.map(\.kind), [.heading(3), .bullet, .bullet])
        XCTAssertEqual(blocks.map(\.plain), [
            "Changes",
            "Updates roll out gradually",
            "What’s New appears once after you update",
        ])
        XCTAssertEqual(blocks.map(\.spoken), [
            "Changes",
            "• Updates roll out gradually",
            "• What’s New appears once after you update",
        ])
        let glued = "ChangesUpdates roll out graduallyWhat’s New appears once after you update"
        let lines = blocks.map(\.plain).joined(separator: "\n")
        XCTAssertEqual(lines, "Changes\nUpdates roll out gradually\nWhat’s New appears once after you update")
        XCTAssertNotEqual(lines, glued)
        XCTAssertFalse(blocks.contains { $0.plain.contains("ChangesUpdates") || $0.spoken == glued })

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let view = try String(contentsOf: root.appendingPathComponent("App/RootSceneView.swift"), encoding: .utf8)
        let parser = try String(contentsOf: root.appendingPathComponent("Services/UpdateAdapter.swift"), encoding: .utf8)
        let shots = try String(contentsOf: root.appendingPathComponent("Tests/WattTests/SiteScreenshotTests.swift"), encoding: .utf8)
        let whatsNew = try String(contentsOf: root.appendingPathComponent("Features/Settings/Views/WhatsNewView.swift"), encoding: .utf8)
        XCTAssertTrue(view.contains("noteRows(UpdateReleaseNotes.blocks(text))"))
        XCTAssertTrue(view.contains(".wattAnimate(.reveal, value: revealed, enabled: !motionSuppressed)"))
        XCTAssertTrue(view.contains(".accessibilityAddTraits(.isHeader)"))
        XCTAssertTrue(view.contains("ReleaseNotesBlock(notes: router.promptNotes(version: version))"))
        XCTAssertFalse(view.contains("UpdateReleaseNotes.markdown"))
        XCTAssertFalse(view.contains("interpretedSyntax: .full"))
        XCTAssertTrue(parser.contains("interpretedSyntax: .inlineOnlyPreservingWhitespace"))
        XCTAssertFalse(parser.contains("interpretedSyntax: .full"))
        XCTAssertTrue(whatsNew.contains("ReleaseNotesBlock(notes: notes)"))
        XCTAssertTrue(shots.contains(#"### Changes\n\n* Updates roll out gradually\n* What’s New appears once after you update"#))
    }

    @MainActor
    func testRenderedNotesExposeHeadingAndBulletsAsSeparateLabels() throws {
        let notes = "### Changes\n\n* Updates roll out gradually\n* What’s New appears once after you update"
        let host = NSHostingView(rootView: ReleaseNotesBlock(notes: notes)
            .environment(\.wattMotionSuppressed, true)
            .frame(width: 520, alignment: .leading))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let labels = accessibilityLabels(in: host).filter { !$0.isEmpty }
        try XCTSkipIf(labels.isEmpty,
                      "Native SwiftUI host exposes no AX labels in this test process. Block parsing still covers the rows.")
        let listed = labels.joined(separator: " | ")
        XCTAssertTrue(labels.contains { $0.contains("Changes") && !$0.contains("Updates") }, listed)
        XCTAssertTrue(labels.contains { $0.contains("Updates roll out gradually") && !$0.contains("What’s New") }, listed)
        XCTAssertTrue(labels.contains { $0.contains("What’s New appears once after you update") && !$0.contains("Updates roll out gradually") }, listed)
        XCTAssertFalse(labels.allSatisfy { $0.contains("Changes") && $0.contains("Updates roll out gradually") }, listed)
    }

    @MainActor
    private func accessibilityLabels(in root: NSView) -> [String] {
        var seen = Set<ObjectIdentifier>()
        func collect(_ object: Any) -> [String] {
            guard let element = object as? any NSAccessibilityProtocol,
                  seen.insert(ObjectIdentifier(element as AnyObject)).inserted else { return [] }
            let own = element.accessibilityLabel().map { [$0] } ?? []
            return own + (element.accessibilityChildren() ?? []).flatMap(collect)
                + ((object as? NSView)?.subviews ?? []).flatMap(collect)
        }
        return collect(root)
    }

    @MainActor func testAdapterPublishesNotesOnlyFromTheVerifiedOffer() async throws {
        let key = Curve25519.Signing.PrivateKey()
        let source = ReleaseNotesSource()
        let checker = trust(publicKey: key.publicKey)
        let adapter = UpdateAdapter(source: source, driver: ReleaseNotesDriver(), storage: InMemoryStorage(), trust: checker)
        let digest = Data(SHA256.hash(data: Data("archive".utf8)))
        let withNotes = UpdateManifest(identity: "test.watt", build: 2, sha256: digest, minimumSystemVersion: "13.0", notes: "### Fixes\n\n* signed")
        source.release = try signed(JSONEncoder().encode(withNotes), key: key)
        guard case .success("2") = await adapter.check() else { return XCTFail("expected the signed build") }
        XCTAssertEqual(adapter.releaseNotes(for: "2"), "### Fixes\n\n* signed")
        XCTAssertNil(adapter.releaseNotes(for: "3"))

        let without = UpdateManifest(identity: "test.watt", build: 3, sha256: digest, minimumSystemVersion: "13.0")
        source.release = try signed(JSONEncoder().encode(without), key: key)
        guard case .success("3") = await adapter.check() else { return XCTFail("expected a manifest without notes") }
        XCTAssertNil(adapter.releaseNotes(for: "3"))
    }

    @MainActor func testOfferWindowReceivesNotesForWhateverVersionWasSigned() async {
        let service = FakeUpdateService()
        service.availableVersion = .success("1.1")
        service.offeredNotes = "### Fixes\n\n* from the manifest"
        let router = AppRouter(updateService: service, updates: UpdateStore())
        XCTAssertTrue(router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation()))
        for _ in 0..<40 {
            if case .available = router.updates.state { break }
            await Task.yield()
        }
        XCTAssertEqual(router.updates.state, .available(version: "1.1"))
        XCTAssertEqual(router.promptNotes(version: "1.1"), "### Fixes\n\n* from the manifest")
        XCTAssertNil(router.promptNotes(version: "9"))

        let quiet = FakeUpdateService()
        quiet.availableVersion = .success("2.0")
        let plain = AppRouter(updateService: quiet, updates: UpdateStore())
        XCTAssertTrue(plain.checkForUpdatesFromMenu(presentationID: plain.beginMenuSetupPresentation()))
        for _ in 0..<40 {
            if case .available = plain.updates.state { break }
            await Task.yield()
        }
        XCTAssertEqual(plain.updates.state, .available(version: "2.0"))
        XCTAssertNil(plain.promptNotes(version: "2.0"))
        XCTAssertEqual(UpdateReleaseNotes.promptText(plain.promptNotes(version: "2.0")), nil)
    }
}

@MainActor
private final class ReleaseNotesSource: UpdateSource {
    var release: SignedUpdate?
    func check() async throws -> SignedUpdate? { release }
    func download(_ release: SignedUpdate) async throws -> Data { Data() }
}

@MainActor
private final class ReleaseNotesDriver: UpdateInstallationDriver {
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement { .original }
    func rollback(receipt: OperationReceipt) throws {}
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool { false }
    func discard(receipt: OperationReceipt) throws {}
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool { true }
}
