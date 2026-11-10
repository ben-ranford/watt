import CryptoKit
import XCTest
#if SWIFT_PACKAGE
import WattMaintenanceShared
#endif
@testable import Watt

@MainActor
final class ReleaseConfigurationTests: XCTestCase {
    private var info: [String: Any] {
        ["CFBundleIdentifier": "test.watt", "CFBundleVersion": "2", "LSMinimumSystemVersion": "13.0",
         "WATTUpdateManifestURL": "https://example.invalid/release.json",
         "WATTUpdateArtifactURL": "https://example.invalid/release.tar",
         "WATTUpdatePublicKey": Data(repeating: 7, count: 32).base64EncodedString()]
    }
    func testExplicitConfigurationAndMalformedInputs() throws {
        let host = OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0)
        XCTAssertEqual(try UpdateConfiguration(info: info, hostSystemVersion: host).trust.currentBuild, 2)
        for key in info.keys {
            var missing = info; missing.removeValue(forKey: key)
            XCTAssertThrowsError(try UpdateConfiguration(info: missing, hostSystemVersion: host), key)
        }
        for (key, value) in [("CFBundleVersion", "0"), ("CFBundleVersion", "01"),
                             ("CFBundleVersion", "18446744073709551616"), ("CFBundleVersion", "1.1"),
                             ("CFBundleIdentifier", "$(PRODUCT_BUNDLE_IDENTIFIER)"),
                             ("LSMinimumSystemVersion", "13"), ("LSMinimumSystemVersion", "14.0"),
                             ("WATTUpdateManifestURL", ""),
                             ("WATTUpdateArtifactURL", ""),
                             ("WATTUpdatePublicKey", ""),
                             ("WATTUpdateManifestURL", "$(WATT_UPDATE_MANIFEST_URL)"),
                             ("WATTUpdateManifestURL", "http://example.invalid/release.json"),
                             ("WATTUpdateManifestURL", "https://user:secret@example.invalid/release.json"),
                             ("WATTUpdateArtifactURL", "https://example.invalid/release.tar#fragment"),
                             ("WATTUpdatePublicKey", "not a key")] {
            var malformed = info; malformed[key] = value
            XCTAssertThrowsError(try UpdateConfiguration(info: malformed, hostSystemVersion: host), key + ":" + value)
        }
    }
    func testReceiptAndChallengeMustMatchEntireRequest() throws {
        let receipt = OperationReceipt(createdAt: Date())
        let request = try UpdateLaunchRequest(receipt: receipt, identity: "test.watt", build: 2,
            minimumSystemVersion: "13.0", challenge: Data(repeating: 1, count: 32))
        XCTAssertEqual(try UpdateLaunchRequest.decode(JSONEncoder().encode(request)), request)
        let other = try UpdateLaunchRequest(receipt: OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1)),
            identity: "test.watt", build: 2, minimumSystemVersion: "13.0", challenge: request.challenge)
        XCTAssertNotEqual(UpdateLaunchAcknowledgement(request: other), UpdateLaunchAcknowledgement(request: request))
        XCTAssertThrowsError(try UpdateLaunchRequest(receipt: receipt, identity: "test.watt", build: 2,
            minimumSystemVersion: "13.0", challenge: Data(repeating: 1, count: 31)))
    }
    func testAdminAndAcceptedStatesRetainReceiptWithoutCompletion() throws {
        let storage = InMemoryStorage(), store = UpdateStore(storage: storage)
        let receipt = OperationReceipt(createdAt: Date())
        let token = store.generation
        XCTAssertTrue(store.accept(.checking, generation: token))
        XCTAssertTrue(store.accept(.available(version: "2"), generation: token))
        XCTAssertTrue(store.beginDownload(version: "2", receipt: receipt, generation: token))
        XCTAssertTrue(store.accept(.staged(receipt), generation: token))
        XCTAssertTrue(store.accept(.adminRequired(receipt), generation: token))
        XCTAssertEqual(UpdateStore(storage: storage).state, .adminRequired(receipt))
        XCTAssertFalse(store.accept(.completed(receipt), generation: token))
        XCTAssertFalse(store.accept(.staged(OperationReceipt(createdAt: Date())), generation: token))
        XCTAssertTrue(store.accept(.staged(receipt), generation: token))
        XCTAssertTrue(store.accept(.handoffAccepted(receipt), generation: token))
        XCTAssertEqual(store.state, .handoffAccepted(receipt))
    }
    func testUninstallAcceptedHandoffRequestsExitWithoutReportingAbsent() async throws {
        let router = AppRouter()
        var didExit = false, didReportAbsent = false
        router.onMaintenanceHandoff = { didExit = true }
        router.onUninstalled = { didReportAbsent = true }
        router.removeFromSettings = { _ in .handoffAccepted(OperationReceipt(createdAt: Date())) }
        let presentation = router.beginUninstallPresentation()
        XCTAssertTrue(router.requestUninstall(presentation: presentation, removing: false))
        let intent = try XCTUnwrap(router.uninstallIntent)
        guard case .handoffAccepted = await router.confirmUninstall(intent) else { return XCTFail("expected accepted") }
        XCTAssertTrue(didExit); XCTAssertFalse(didReportAbsent); XCTAssertFalse(router.uninstallCompleted)
    }

    func testRestartRestoresVerifiedReceiptWithoutRestoringHandoffOrConsent() throws {
        let storage = InMemoryStorage()
        let receipt = OperationReceipt(createdAt: Date())
        try storage.write(JSONEncoder().encode(UpdateState.handoffAccepted(receipt)), key: "update.v1")
        let restarted = UpdateStore(storage: storage)
        XCTAssertEqual(restarted.state, .failed(.interruptedUpdate, receipt))
        XCTAssertFalse(restarted.restoreVerifiedTransaction(.handoffAccepted(receipt)))
        XCTAssertFalse(restarted.restoreVerifiedTransaction(.staged(OperationReceipt(createdAt: Date()))))
        XCTAssertTrue(restarted.restoreVerifiedTransaction(.staged(receipt)))
        XCTAssertEqual(restarted.state, .staged(receipt))
        XCTAssertEqual(UpdateStore(storage: storage).state, .failed(.interruptedUpdate, receipt))
        XCTAssertTrue(restarted.restoreVerifiedTransaction(.completed(receipt)))
        XCTAssertEqual(UpdateStore(storage: storage).state, .completed(receipt))
    }
}
