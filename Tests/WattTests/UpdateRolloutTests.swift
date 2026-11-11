import CryptoKit
import Foundation
import XCTest
@testable import Watt

final class UpdateRolloutTests: XCTestCase {
    private let digest = Data(SHA256.hash(data: Data("watt".utf8)))
    private let plainPayload = Data(#"{"identity":"dev.watt.example","build":1002003,"sha256":"E/sq9EiC6Ak8Rp4TvS6j65H2xWVg4AOe15YVVc3Ebas=","minimumSystemVersion":"13.0"}"#.utf8)
    private let signedPayload = Data(#"{"identity":"dev.watt.example","build":1002003,"sha256":"E/sq9EiC6Ak8Rp4TvS6j65H2xWVg4AOe15YVVc3Ebas=","minimumSystemVersion":"13.0","notes":"### Fixes\n\n* steadier numbers","rollout":{"basis":1700000000,"interval":86400,"steps":[1,2,5,10,20,50,100],"paused":false,"percent":1,"critical":false,"halted":false}}"#.utf8)

    func testEncodedPayloadMatchesTheSignerBytes() throws {
        let plain = UpdateManifest(identity: "dev.watt.example", build: 1_002_003, sha256: digest, minimumSystemVersion: "13.0")
        XCTAssertEqual(try JSONEncoder().encode(plain), plainPayload)
        let rollout = sampleRollout()
        let manifest = UpdateManifest(identity: "dev.watt.example", build: 1_002_003, sha256: digest,
                                      minimumSystemVersion: "13.0", notes: "### Fixes\n\n* steadier numbers", rollout: rollout)
        XCTAssertEqual(try JSONEncoder().encode(manifest), signedPayload)
        let decoded = try JSONDecoder().decode(UpdateManifest.self, from: signedPayload)
        XCTAssertEqual(decoded, manifest)
    }

    func testSignatureCoversTheRolloutAndRejectsAChange() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signature = try key.signature(for: signedPayload)
        let release = SignedUpdate(payload: signedPayload, signature: signature)
        let trust = UpdateTrust(identity: "dev.watt.example", currentBuild: 1_002_000,
                                hostSystemVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
                                publicKey: key.publicKey)
        let manifest = try trust.authenticate(release)
        XCTAssertEqual(manifest.rollout?.percent, 1)
        XCTAssertEqual(manifest.notes, "### Fixes\n\n* steadier numbers")
        var tampered = signedPayload
        tampered[tampered.index(tampered.endIndex, offsetBy: -8)] ^= 0x01
        XCTAssertFalse(key.publicKey.isValidSignature(signature, for: tampered))
        XCTAssertThrowsError(try trust.authenticate(SignedUpdate(payload: tampered, signature: signature))) { error in
            XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity)
        }
    }

    func testOlderClientDecodesTheNewPayloadWithoutFailingVerification() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signature = try key.signature(for: signedPayload)
        XCTAssertTrue(key.publicKey.isValidSignature(signature, for: signedPayload))
        let legacy = try JSONDecoder().decode(LegacyUpdateManifest.self, from: signedPayload)
        XCTAssertEqual(legacy.identity, "dev.watt.example")
        XCTAssertEqual(legacy.build, 1_002_003)
        XCTAssertEqual(legacy.sha256, digest)
        XCTAssertEqual(legacy.minimumSystemVersion, "13.0")
        XCTAssertEqual(legacy.notes, "### Fixes\n\n* steadier numbers")
        let malformed = signedPayload.replacing(#""steps":[1,2,5,10,20,50,100]"#, with: #""steps":[5,1,100]"#)
        let badSignature = try key.signature(for: malformed)
        let trust = UpdateTrust(identity: "dev.watt.example", currentBuild: 1, hostSystemVersion: .init(majorVersion: 14, minorVersion: 0, patchVersion: 0), publicKey: key.publicKey)
        XCTAssertTrue(key.publicKey.isValidSignature(badSignature, for: malformed))
        XCTAssertThrowsError(try trust.authenticate(SignedUpdate(payload: malformed, signature: badSignature)))
        var invalid = sampleRollout()
        invalid.steps = [5, 1, 100]
        XCTAssertThrowsError(try UpdateRollout.validate(invalid)) { error in
            XCTAssertEqual(error as? ServiceFailure, .invalidData)
        }
        XCTAssertNoThrow(try JSONDecoder().decode(LegacyUpdateManifest.self, from: malformed))
    }

    func testBucketingIsDeterministicAndMatchesTheSchedule() {
        let basis = Date(timeIntervalSince1970: 1_700_000_000)
        let steps = [1, 2, 5, 10, 20, 50, 100]
        let cases: [(TimeInterval, Int)] = [
            (-1, 0),
            (0, 1),
            (86_399, 1),
            (86_400, 2),
            (86_400 * 2, 5),
            (86_400 * 3, 10),
            (86_400 * 4, 20),
            (86_400 * 5, 50),
            (86_400 * 6, 100),
            (86_400 * 30, 100),
        ]
        for (elapsed, expected) in cases {
            let now = basis.addingTimeInterval(elapsed)
            let rollout = sampleRollout(paused: false, percent: 1)
            XCTAssertEqual(rollout.share(at: now), expected, "elapsed \(elapsed)")
            let again = rollout.share(at: now)
            XCTAssertEqual(again, expected)
            let admitted = (0..<RolloutBucket.count).filter {
                UpdateRolloutGate.admits(rollout: rollout, initiator: .automatic, bucket: $0, now: now)
            }
            XCTAssertEqual(admitted.count, expected)
            if expected > 0 {
                XCTAssertTrue(admitted.contains(0))
                XCTAssertFalse(admitted.contains(expected))
            }
        }
        for percent in steps {
            let rollout = sampleRollout(paused: true, percent: percent)
            let now = basis.addingTimeInterval(86_400 * 30)
            XCTAssertEqual(rollout.share(at: now), percent)
            let admitted = (0..<100).filter {
                UpdateRolloutGate.admits(rollout: rollout, initiator: .automatic, bucket: $0, now: now)
            }
            XCTAssertEqual(admitted, Array(0..<percent))
        }
    }

    @MainActor
    func testStoredBucketStaysPut() throws {
        let storage = InMemoryStorage()
        let first = try RolloutBucket.stableValue(in: storage)
        let second = try RolloutBucket.stableValue(in: storage)
        XCTAssertEqual(first, second)
        XCTAssertTrue((0..<RolloutBucket.count).contains(first))
    }

    @MainActor
    func testManualCheckBypassesStagingAndCriticalSkipsIt() async throws {
        let staged = try makeAdapter(rollout: sampleRollout(), bucket: 50)
        let withheld = await staged.adapter.check(initiator: .automatic)
        guard case .success(nil) = withheld else { return XCTFail("automatic check offered a staged build") }
        XCTAssertEqual(staged.adapter.state, .idle)
        let manual = await staged.adapter.check(initiator: .manual)
        guard case .success(.some("1.2.3")) = manual else { return XCTFail("manual check did not bypass staging: \(manual)") }

        let early = try makeAdapter(rollout: sampleRollout(), bucket: 0, now: 1_700_000_000 - 1)
        guard case .success(nil) = await early.adapter.check() else { return XCTFail("a future basis was offered") }
        guard case .success(.some("1.2.3")) = await early.adapter.check(initiator: .manual) else {
            return XCTFail("manual check did not bypass a rollout that has not started")
        }

        var critical = sampleRollout(percent: 1)
        critical.critical = true
        let urgent = try makeAdapter(rollout: critical, bucket: 99)
        guard case .success(.some("1.2.3")) = await urgent.adapter.check(initiator: .automatic) else {
            return XCTFail("critical release stayed staged")
        }

        var halted = sampleRollout(paused: true, percent: 0)
        halted.halted = true
        halted.critical = false
        let stopped = try makeAdapter(rollout: halted, bucket: 0)
        guard case .success(nil) = await stopped.adapter.check(initiator: .manual) else {
            return XCTFail("a halted release was offered to a manual check")
        }
        guard case .success(nil) = await stopped.adapter.check(initiator: .automatic) else {
            return XCTFail("a halted release was offered automatically")
        }
    }

    @MainActor
    func testAManifestWithoutRolloutStillUpdatesEveryone() async throws {
        let open = try makeAdapter(rollout: nil, bucket: 99)
        guard case .success(.some("1.2.3")) = await open.adapter.check(initiator: .automatic) else {
            return XCTFail("an old manifest was withheld")
        }
    }

    @MainActor
    func testInstalledNotesComeFromTheSignedJournal() async throws {
        let rig = try makeAdapter(rollout: sampleRollout(), bucket: 0)
        guard case .success(.some("1.2.3")) = await rig.adapter.check(initiator: .manual) else {
            return XCTFail("expected the signed offer")
        }
        let manifest = try rig.trust.authenticate(rig.source.release!)
        let receipt = OperationReceipt(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let entry = UpdateTransaction(receipt: receipt, release: rig.source.release!, phase: .completed)
        try rig.storage.write(JSONEncoder().encode([entry]), key: UpdateAdapter.transactionStorageKey)
        let restarted = UpdateAdapter(source: rig.source, driver: IdleInstallation(), storage: rig.storage, trust: rig.trust)
        XCTAssertEqual(restarted.releaseNotesForInstalledBuild(manifest.build), "### Fixes\n\n* steadier numbers")
        var tampered = rig.source.release!
        var payload = tampered.payload
        payload[payload.index(payload.endIndex, offsetBy: -20)] ^= 0x01
        tampered = SignedUpdate(payload: payload, signature: tampered.signature)
        let bad = UpdateTransaction(receipt: receipt, release: tampered, phase: .completed)
        try rig.storage.write(JSONEncoder().encode([bad]), key: UpdateAdapter.transactionStorageKey)
        let rejected = UpdateAdapter(source: rig.source, driver: IdleInstallation(), storage: rig.storage, trust: rig.trust)
        XCTAssertNil(rejected.releaseNotesForInstalledBuild(manifest.build))
    }

    private func sampleRollout(paused: Bool = false, percent: Int = 1) -> UpdateRollout {
        UpdateRollout(basis: 1_700_000_000, interval: 86_400, steps: [1, 2, 5, 10, 20, 50, 100],
                      paused: paused, percent: percent, critical: false, halted: false)
    }

    @MainActor
    private func makeAdapter(rollout: UpdateRollout?, bucket: Int, now: TimeInterval = 1_700_000_000) throws -> RolloutRig {
        let key = Curve25519.Signing.PrivateKey()
        let artifact = Data("watt-bytes".utf8)
        let manifest = UpdateManifest(identity: "dev.watt.example", build: 1_002_003,
                                      sha256: Data(SHA256.hash(data: artifact)), minimumSystemVersion: "13.0",
                                      notes: "### Fixes\n\n* steadier numbers", rollout: rollout)
        let payload = try JSONEncoder().encode(manifest)
        let source = RolloutSource()
        source.release = SignedUpdate(payload: payload, signature: try key.signature(for: payload))
        source.bytes = artifact
        let storage = InMemoryStorage()
        let trust = UpdateTrust(identity: "dev.watt.example", currentBuild: 1_002_000,
                                hostSystemVersion: .init(majorVersion: 14, minorVersion: 2, patchVersion: 0),
                                publicKey: key.publicKey)
        let adapter = UpdateAdapter(source: source, driver: IdleInstallation(), storage: storage, trust: trust)
        adapter.rolloutBucket = bucket
        adapter.rolloutNow = { Date(timeIntervalSince1970: now) }
        return RolloutRig(adapter: adapter, source: source, storage: storage, trust: trust)
    }
}

private struct LegacyUpdateManifest: Decodable {
    let identity: String
    let build: UInt64
    let sha256: Data
    let minimumSystemVersion: String
    let notes: String?
}

@MainActor
private final class RolloutSource: UpdateSource {
    var release: SignedUpdate?
    var bytes = Data()
    func check() async throws -> SignedUpdate? { release }
    func download(_ release: SignedUpdate) async throws -> Data { bytes }
}

@MainActor
private final class IdleInstallation: UpdateInstallationDriver {
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

@MainActor
private struct RolloutRig {
    let adapter: UpdateAdapter
    let source: RolloutSource
    let storage: InMemoryStorage
    let trust: UpdateTrust
}

private extension Data {
    func replacing(_ needle: String, with replacement: String) -> Data {
        guard let source = String(data: self, encoding: .utf8),
              let updated = source.replacingOccurrences(of: needle, with: replacement).data(using: .utf8) else {
            return self
        }
        return updated
    }
}
