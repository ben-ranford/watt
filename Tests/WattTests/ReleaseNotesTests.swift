import CryptoKit
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
        let rendered = UpdateReleaseNotes.markdown("### Fixes\n\n* **steadier** numbers")
        XCTAssertTrue(String(rendered.characters).contains("Fixes"))
        XCTAssertTrue(String(rendered.characters).contains("steadier"))
        XCTAssertEqual(UpdateReleaseNotes.unavailable, "Release notes aren’t available for this version.")
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
