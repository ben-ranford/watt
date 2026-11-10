import CryptoKit
import Darwin
import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import WattMaintenanceShared
import WattHelperShared
#endif
@testable import Watt

private func updaterTemporaryDirectory() throws -> URL {
    // Foundation canonicalizes the system temporary directory back through /var on this host.
    // Use the actual filesystem path so production's ancestor no-follow policy stays intact.
    let url = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent("watt-update-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    return url
}

private func testUSTAR(_ items: [(String, Data, UInt8)]) -> Data {
    var archive = Data()
    for (name, content, type) in items {
        var header = [UInt8](repeating: 0, count: 512)
        func field(_ string: String, _ start: Int, _ length: Int) {
            for (index, byte) in string.utf8.prefix(length).enumerated() { header[start + index] = byte }
        }
        field(name, 0, 100); field("0000700", 100, 8); field("0000000", 108, 8); field("0000000", 116, 8)
        field(String(format: "%011o", content.count), 124, 12); field("00000000000", 136, 12)
        field("        ", 148, 8); header[156] = type
        field("ustar", 257, 6); field("00", 263, 2)
        field(String(format: "%06o", header.reduce(0) { $0 + Int($1) }) + "\0 ", 148, 8)
        archive.append(contentsOf: header); archive.append(content)
        archive.append(Data(repeating: 0, count: (512 - content.count % 512) % 512))
    }
    archive.append(Data(repeating: 0, count: 1024))
    return archive
}

final class BoundedUSTARTests: XCTestCase {
    func testValidArchiveExtractsOnlyIntoFreshPrivateRoot() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let bytes = testUSTAR([("Watt.app/", Data(), 53), ("Watt.app/Contents/value", Data("hello".utf8), 48)])
        let archive = try BoundedUSTAR(validating: bytes)
        let destination = parent.appendingPathComponent("receipt")
        try archive.extract(intoFreshDirectory: destination)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("Watt.app/Contents/value")), Data("hello".utf8))
        XCTAssertThrowsError(try archive.extract(intoFreshDirectory: destination))
    }
    func testRejectsTraversalDuplicatesLinksSpecialHeadersTruncationAndTrailingBytes() throws {
        for path in ["../outside", "/absolute", "a/../../outside", "a//b", "./a", "a/./b"] {
            XCTAssertThrowsError(try BoundedUSTAR(validating: testUSTAR([(path, Data(), 48)])), path)
        }
        for type in [UInt8(49), 50, 51, 52, 54, 55, 120, 103, 76, 75, 83] {
            XCTAssertThrowsError(try BoundedUSTAR(validating: testUSTAR([("entry", Data(), type)])))
        }
        XCTAssertThrowsError(try BoundedUSTAR(validating: testUSTAR([("a", Data(), 48), ("a", Data(), 48)])))
        XCTAssertThrowsError(try BoundedUSTAR(validating: testUSTAR([("A", Data(), 48), ("a", Data(), 48)])))
        XCTAssertThrowsError(try BoundedUSTAR(validating: testUSTAR([("a", Data(), 48), ("a/b", Data(), 48)])))
        var bytes = testUSTAR([("a", Data("contents".utf8), 48)])
        bytes[512 + 8] = 1 // Nonzero padding.
        XCTAssertThrowsError(try BoundedUSTAR(validating: bytes))
        bytes = testUSTAR([("a", Data(), 48)]); bytes.removeLast(512)
        XCTAssertThrowsError(try BoundedUSTAR(validating: bytes))
        bytes = testUSTAR([("a", Data(), 48)]); bytes[0] ^= 1
        XCTAssertThrowsError(try BoundedUSTAR(validating: bytes))
        bytes = testUSTAR([("a", Data(), 48)]); bytes.append(Data(repeating: 1, count: 512))
        XCTAssertThrowsError(try BoundedUSTAR(validating: bytes))
    }
    func testSymlinkParentCannotRedirectExtraction() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let outside = parent.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let link = parent.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let archive = try BoundedUSTAR(validating: testUSTAR([("a", Data(), 48)]))
        XCTAssertThrowsError(try archive.extract(intoFreshDirectory: link.appendingPathComponent("receipt")))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outside.path), [])
    }
    func testSystemTarUSTARProducerIsCompatible() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let bundle = parent.appendingPathComponent("Watt.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: false)
        try Data("sample".utf8).write(to: bundle.appendingPathComponent("sample"))
        let output = parent.appendingPathComponent("release.tar")
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["--format", "ustar", "-cf", output.path, "-C", parent.path, "Watt.app"]
        process.environment = ProcessInfo.processInfo.environment.merging(["COPYFILE_DISABLE": "1"]) { _, value in value }
        try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(try BoundedUSTAR(validating: Data(contentsOf: output)).entries.count, 2)
    }
}

final class ProtectedUpdatePackageTests: XCTestCase {
    func testPackageBindsFullReceiptSignedPayloadAndImmutableArchive() throws {
        let directory = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let archive = testUSTAR([("Watt.app/", Data(), 53), ("Watt.app/value", Data("value".utf8), 48)])
        let manifest = UpdateManifest(identity: HelperIdentity.appIdentifier, build: 2, sha256: Data(SHA256.hash(data: archive)), minimumSystemVersion: "13.0")
        let payload = try JSONEncoder().encode(manifest), signingKey = Curve25519.Signing.PrivateKey()
        let release = SignedUpdate(payload: payload, signature: try signingKey.signature(for: payload))
        let receipt = MaintenanceReceipt(createdAt: Date()), installation = UUID(), hash = Data(repeating: 7, count: 20)
        let binding = try ProtectedMaintenanceBinding(receipt: ProtectedMaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt), installationID: installation,
            previousGeneration: 1, nextGeneration: 2, operation: .update, signedPayloadSHA256: Data(SHA256.hash(data: payload)), archiveSHA256: manifest.sha256,
            build: 2, replacementAppHashes: [hash], replacementHelperHashes: [hash], replacementMaintenanceHashes: [hash])
        let parent = MaintenanceProcessIdentity(pid: 42, uid: getuid(), startedAtMicroseconds: 1, codeDirectoryHash: hash)
        let request = try MaintenanceRequest(receipt: receipt, installationID: installation, generation: 1, operation: .update, parent: parent, candidateSHA256: manifest.sha256)
        let envelope = try ProtectedUpdateEnvelope(request: request, binding: binding, minimumSystemVersion: "13.0")
        try ProtectedUpdatePackage.writeFile(JSONEncoder().encode(release), named: "manifest.json", directory: directory)
        try ProtectedUpdatePackage.writeFile(archive, named: "release.tar", directory: directory)
        try ProtectedUpdatePackage.writeFile(JSONEncoder().encode(binding), named: "request.json", directory: directory)
        try ProtectedUpdatePackage.validate(envelope, at: directory)
        let replay = try MaintenanceRequest(receipt: MaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1)), installationID: installation, generation: 1,
            operation: .update, parent: parent, candidateSHA256: manifest.sha256)
        XCTAssertThrowsError(try ProtectedUpdateEnvelope(request: replay, binding: binding, minimumSystemVersion: "13.0"))
        XCTAssertThrowsError(try ProtectedUpdatePackage.writeFile(Data(), named: "request.json", directory: directory), "Export never overwrites an existing request")
        try Data("tampered".utf8).write(to: directory.appendingPathComponent("release.tar"))
        XCTAssertThrowsError(try ProtectedUpdatePackage.validate(envelope, at: directory))
    }
}

@MainActor
final class AtomicMaintenanceStorageTests: XCTestCase {
    func testDurableReopenAndExclusiveWriter() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let url = parent.appendingPathComponent("journal")
        var first: AtomicMaintenanceStorage? = try AtomicMaintenanceStorage(directory: url)
        try first!.write(Data("old".utf8), key: "updater.transactions.v1")
        XCTAssertThrowsError(try AtomicMaintenanceStorage(directory: url))
        XCTAssertThrowsError(try first!.write(Data(repeating: 0, count: 1024 * 1024 + 1), key: "updater.transactions.v1"))
        XCTAssertEqual(try first!.read(key: "updater.transactions.v1"), Data("old".utf8))
        first!.close(); first!.close()
        XCTAssertThrowsError(try first!.read(key: "updater.transactions.v1"))
        XCTAssertThrowsError(try first!.write(Data(), key: "updater.transactions.v1"))
        first = nil
        let reopened = try AtomicMaintenanceStorage(directory: url)
        XCTAssertEqual(try reopened.read(key: "updater.transactions.v1"), Data("old".utf8))
        try reopened.write(Data("new".utf8), key: "updater.transactions.v1")
        XCTAssertEqual(try reopened.read(key: "updater.transactions.v1"), Data("new".utf8))
    }
    func testRejectsSymlinksHardLinksInsecureDirectoriesAndReplacement() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let root = parent.appendingPathComponent("journal")
        let store = try AtomicMaintenanceStorage(directory: root)
        let outside = parent.appendingPathComponent("sentinel")
        try Data("safe".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("value"), withDestinationURL: outside)
        XCTAssertThrowsError(try store.write(Data("bad".utf8), key: "value"))
        XCTAssertThrowsError(try store.read(key: "value"))
        XCTAssertThrowsError(try store.write(Data(), key: "../sentinel"))
        XCTAssertEqual(try Data(contentsOf: outside), Data("safe".utf8))
        try FileManager.default.linkItem(at: outside, to: root.appendingPathComponent("hardlink"))
        XCTAssertThrowsError(try store.read(key: "hardlink"))
        try FileManager.default.moveItem(at: root, to: parent.appendingPathComponent("moved"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        XCTAssertThrowsError(try store.write(Data(), key: "value"))
        let insecure = parent.appendingPathComponent("insecure")
        try FileManager.default.createDirectory(at: insecure, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])
        XCTAssertThrowsError(try AtomicMaintenanceStorage(directory: insecure))
    }
}

private final class UpdateURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable { var status = 200; var chunks: [Data] = []; var declaredLength: Int?; var delay = false; var redirect: URL? }
    private static let lock = NSLock()
    nonisolated(unsafe) private static var response = Response()
    static func configure(_ value: Response) { lock.lock(); response = value; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let response = Self.response; Self.lock.unlock()
        if response.delay { return }
        var headers = [String: String]()
        if let length = response.declaredLength { headers["Content-Length"] = String(length) }
        let http = HTTPURLResponse(url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: headers)!
        if let redirect = response.redirect {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: redirect), redirectResponse: http)
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        for chunk in response.chunks { client?.urlProtocol(self, didLoad: chunk) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class ProductionUpdateSourceTests: XCTestCase {
    private func fixture(deadline: TimeInterval = 2) throws -> (ProductionUpdateSource, SignedUpdate, Data) {
        let key = Curve25519.Signing.PrivateKey()
        let bytes = Data("archive".utf8)
        let manifest = UpdateManifest(identity: "test.watt", build: 2, sha256: Data(SHA256.hash(data: bytes)), minimumSystemVersion: "13.0")
        let payload = try JSONEncoder().encode(manifest)
        let release = SignedUpdate(payload: payload, signature: try key.signature(for: payload))
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [UpdateURLProtocol.self]
        let trust = UpdateTrust(identity: "test.watt", currentBuild: 1, hostSystemVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0), publicKey: key.publicKey)
        return (try ProductionUpdateSource(manifestURL: URL(string: "https://releases.example.test/manifest")!, artifactURL: URL(string: "https://releases.example.test/archive")!, trust: trust, configuration: config, deadline: deadline), release, bytes)
    }
    func testAuthenticatedManifestAndStreamedArchive() async throws {
        let (source, release, bytes) = try fixture()
        let encoded = try JSONEncoder().encode(release)
        UpdateURLProtocol.configure(.init(chunks: [encoded], declaredLength: encoded.count))
        let checked = try await source.check(); XCTAssertEqual(checked, release)
        UpdateURLProtocol.configure(.init(chunks: [bytes.prefix(3), bytes.dropFirst(3)], declaredLength: bytes.count))
        var progress: [UpdateDownloadProgress] = []
        let downloaded = try await source.download(release, progress: { progress.append($0) }); XCTAssertEqual(downloaded, bytes)
        XCTAssertTrue(progress.allSatisfy(\.isValid)); XCTAssertEqual(progress.last?.fraction, 1)
    }
    func testStatusAndSizeFailuresAndNoContent() async throws {
        let (source, _, _) = try fixture()
        for response in [UpdateURLProtocol.Response(status: 500), .init(status: 200, declaredLength: 1024 * 1024 + 1),
                         .init(chunks: [Data(repeating: 0, count: 1024 * 1024), Data([0])])] {
            UpdateURLProtocol.configure(response)
            do { _ = try await source.check(); XCTFail("Must reject response") } catch {}
        }
        UpdateURLProtocol.configure(.init(status: 204))
        let result = try await source.check(); XCTAssertNil(result)
    }
    func testDeadlineAndCancellationFinishHungRequest() async throws {
        let (source, _, _) = try fixture(deadline: 0.03)
        UpdateURLProtocol.configure(.init(delay: true))
        do { _ = try await source.check(); XCTFail("Must time out") }
        catch { XCTAssertEqual(error as? ServiceFailure, .timedOut) }
        let task = Task { try await source.check() }
        task.cancel()
        do { _ = try await task.value; XCTFail("Must cancel") } catch { XCTAssertTrue(error is CancellationError || error as? ServiceFailure == .cancelled) }
    }
    func testDigestMismatchRefusesDownloadedBytes() async throws {
        let (source, release, _) = try fixture()
        UpdateURLProtocol.configure(.init(chunks: [Data("wrong".utf8)]))
        do { _ = try await source.download(release); XCTFail("Must authenticate bytes") }
        catch { XCTAssertEqual(error as? ServiceFailure, .invalidData) }
    }
    func testRejectsCrossOriginAndInsecureRedirects() async throws {
        let (source, _, _) = try fixture()
        for target in ["https://other.example.test/release", "http://releases.example.test/release",
                       "https://releases.example.test/release?download=1", "https://releases.example.test/release#sig"] {
            UpdateURLProtocol.configure(.init(status: 302, redirect: URL(string: target)!))
            do { _ = try await source.check(); XCTFail("Must reject redirect") }
            catch { XCTAssertEqual(error as? ServiceFailure, .network) }
        }
    }
    func testDownloaderRejectsQueryPortAndUserinfo() throws {
        let key = Curve25519.Signing.PrivateKey()
        let trust = UpdateTrust(identity: "test.watt", currentBuild: 1,
            hostSystemVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0),
            publicKey: key.publicKey)
        let artifact = URL(string: "https://releases.example.test/archive")!
        for raw in ["https://releases.example.test/manifest?x=1",
                    "https://user:secret@releases.example.test/manifest",
                    "https://releases.example.test:8443/manifest",
                    "http://releases.example.test/manifest",
                    "https://releases.example.test/manifest#frag"] {
            XCTAssertThrowsError(try ProductionUpdateSource(manifestURL: URL(string: raw)!, artifactURL: artifact, trust: trust), raw)
        }
    }
}

@MainActor
private struct QuarantineMarkingValidator: ProductionUpdateCodeValidator {
    func verify(bundle: URL) throws -> VerifiedUpdateBundle {
        let identity = try FixtureUpdateValidator().verify(bundle: bundle)
        let marker = Array("0083;00000000;WattTest;".utf8)
        let wrote = marker.withUnsafeBytes { buffer in
            setxattr(bundle.path, QuarantineAttribute.name, buffer.baseAddress, buffer.count, 0, XATTR_NOFOLLOW)
        }
        guard wrote == 0 else { throw ServiceFailure.persistence }
        return identity
    }
}
@MainActor
private struct FixtureUpdateValidator: ProductionUpdateCodeValidator {
    func verify(bundle: URL) throws -> VerifiedUpdateBundle {
        let data = try Data(contentsOf: bundle.appendingPathComponent("identity.json"))
        return try JSONDecoder().decode(VerifiedUpdateBundle.self, from: data)
    }
}
@MainActor
private final class FixtureUpdateWitness: ProductionUpdateProcessWitness {
    var acknowledged: OperationReceipt?
    func launch(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func authenticatedRunning(bundle: URL, manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool { acknowledged == receipt }
}
@MainActor
final class ProductionUpdateInstallationDriverTests: XCTestCase {
    func testProtectedSessionTransfersBothLocksAndCompletesOnlyAfterExitAndLiveAcknowledgement() async throws {
        let root = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Watt.app"), contents = app.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("protected-fixture.c")
        let program = """
        #include <unistd.h>
        #include <stdint.h>
        #include <arpa/inet.h>
        #include <string.h>
        static int exact(int fd, void *p, size_t n) { size_t k=0; while(k<n){ssize_t v=read(fd,(char*)p+k,n-k);if(v<=0)return 0;k+=v;}return 1;}
        int main(void){uint32_t n;char in[8192],out[8220];if(!exact(0,&n,4))return 1;n=ntohl(n);if(n>8192||!exact(0,in,n))return 2;
          memcpy(out,"{\\\"request\\\":",11);memcpy(out+11,in,n);out[n+11]='}';uint32_t size=htonl(n+12);write(1,&size,4);write(1,out,n+12);
          if(!exact(0,&n,4))return 3;n=ntohl(n);if(n!=15||!exact(0,in,n)||memcmp(in,"launch-accepted",15))return 4;usleep(200000);uint32_t final=htonl(17);write(1,&final,4);write(1,"startup-confirmed",17);sleep(30);return 0;}
        """
        try Data(program.utf8).write(to: source)
        let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = ["clang", source.path, "-o", macOS.appendingPathComponent("Watt").path]
        try compiler.run(); compiler.waitUntilExit(); XCTAssertEqual(compiler.terminationStatus, 0)
        let plist: [String: Any] = ["CFBundleIdentifier": HelperIdentity.appIdentifier, "CFBundleVersion": "2", "CFBundleExecutable": "Watt", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "13.0"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let signer = Process(); signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); signer.arguments = ["--force", "--sign", "-", app.path]
        try signer.run(); signer.waitUntilExit(); XCTAssertEqual(signer.terminationStatus, 0)
        let code = try SecurityUpdateCodeValidator().verify(bundle: app)
        let parent = Process(); parent.executableURL = URL(fileURLWithPath: "/bin/sleep"); parent.arguments = ["30"]
        try parent.run(); defer { if parent.isRunning { parent.terminate() } }
        let observation = try MaintenanceProcessWitness.observe(pid: parent.processIdentifier)
        let receipt = OperationReceipt(createdAt: Date()), installation = UUID()
        let payload = Data("fixture signed payload".utf8)
        let binding = try ProtectedMaintenanceBinding(receipt: ProtectedMaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt), installationID: installation,
            previousGeneration: 1, nextGeneration: 2, operation: .update, signedPayloadSHA256: Data(SHA256.hash(data: payload)), archiveSHA256: Data(repeating: 2, count: 32),
            build: 2, replacementAppHashes: [code.codeHash], replacementHelperHashes: [code.codeHash], replacementMaintenanceHashes: [code.codeHash])
        let request = try MaintenanceRequest(receipt: receipt, installationID: installation, generation: 1, operation: .update, parent: observation, candidateSHA256: binding.archiveSHA256)
        let envelope = try ProtectedUpdateEnvelope(request: request, binding: binding, minimumSystemVersion: "13.0")
        let installed = try ProtectedHelperRecord(installationID: installation, generation: 2, build: 2, appHashes: [code.codeHash], helperHashes: [code.codeHash], maintenanceHashes: [code.codeHash], maintenanceBinding: binding)
        let journal = try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-journal"))
        let staging = try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-staging"))
        struct JournalEntry: Codable { let receipt: OperationReceipt; let release: SignedUpdate; let phase: String }
        try journal.write(JSONEncoder().encode([JournalEntry(receipt: receipt, release: SignedUpdate(payload: payload, signature: Data(repeating: 0, count: 64)), phase: "protectedHandoff")]), key: "updater.transactions.v1")
        let environment = ProtectedUpdateSession.Environment(directory: root, validate: { value in
            try value.validate()
            guard try MaintenanceProcessWitness.matches(value.request.parent) else { throw ServiceFailure.untrustedIdentity }
        }, installed: { installed }, coherent: { record, value in
            guard record.maintenanceBinding == value.binding else { throw ServiceFailure.untrustedIdentity }
            XCTAssertEqual(try SecurityUpdateCodeValidator().verify(bundle: app).codeHash, record.appHashes.first)
        }, application: { _ in app })
        XCTAssertThrowsError(try ProtectedUpdateSession(envelope: envelope, environment: environment))
        journal.close(); staging.close()
        let session = try ProtectedUpdateSession(envelope: envelope, environment: environment)
        XCTAssertThrowsError(try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-journal")))
        XCTAssertThrowsError(try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-staging")))
        XCTAssertEqual(session.record.phase, .accepted)
        parent.terminate(); parent.waitUntilExit()
        try await session.finish(timeout: 5)
        XCTAssertEqual(session.record.phase, .completed)
        let replacement = try XCTUnwrap(session.record.replacement)
        defer { if (try? MaintenanceProcessWitness.matches(replacement)) == true { kill(replacement.pid, SIGTERM) } }
        XCTAssertEqual(replacement.codeDirectoryHash, code.codeHash)
        let reopenedJournal = try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-journal"))
        let reopenedStaging = try AtomicMaintenanceStorage(directory: root.appendingPathComponent("update-staging"))
        reopenedJournal.close(); reopenedStaging.close()
        XCTAssertThrowsError(try ProtectedUpdateSession(envelope: envelope, environment: environment), "Completed JSON cannot restore a dead parent's live observation")
    }
    func testAuthenticatedProcessWitnessRequiresExactReceiptAndLiveSignedProcess() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let app = parent.appendingPathComponent("HandshakeFixture.app"), contents = app.appendingPathComponent("Contents")
        let executables = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        let source = parent.appendingPathComponent("fixture.c")
        let code = """
        #include <unistd.h>
        #include <stdint.h>
        #include <arpa/inet.h>
        #include <string.h>
        static int exact(int fd, void *p, size_t n) { size_t k=0; while(k<n) { ssize_t v=read(fd,(char*)p+k,n-k); if(v<=0)return 0;k+=v;}return 1; }
        int main(void) { uint32_t count; char input[8192], output[8220];
          if(!exact(0,&count,4))return 1; count=ntohl(count); if(count>8192||!exact(0,input,count))return 2;
          memcpy(output,"{\\\"request\\\":",11); memcpy(output+11,input,count); output[count+11]='}';
          uint32_t length=htonl(count+12); if(write(1,&length,4)!=4||write(1,output,count+12)!=count+12)return 3;
          if(!exact(0,&count,4))return 4;count=ntohl(count);if(count!=15||!exact(0,input,count)||memcmp(input,"launch-accepted",15))return 5;
          usleep(200000);length=htonl(17);write(1,&length,4);write(1,"startup-confirmed",17);sleep(30); return 0;
        }
        """
        try Data(code.utf8).write(to: source)
        let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = ["clang", source.path, "-o", executables.appendingPathComponent("Fixture").path]
        try compiler.run(); compiler.waitUntilExit(); XCTAssertEqual(compiler.terminationStatus, 0)
        let plist: [String: Any] = ["CFBundleIdentifier": "test.watt.handshake-fixture", "CFBundleVersion": "2", "CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "13.0"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let signer = Process(); signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signer.arguments = ["--force", "--sign", "-", app.path]
        try signer.run(); signer.waitUntilExit(); XCTAssertEqual(signer.terminationStatus, 0)
        let manifest = UpdateManifest(identity: "test.watt.handshake-fixture", build: 2, sha256: Data(repeating: 1, count: 32), minimumSystemVersion: "13.0")
        let receipt = OperationReceipt(createdAt: Date())
        let witness = AuthenticatedUpdateProcessWitness()
        defer {
            if let identity = witness.observedProcessIdentity, (try? MaintenanceProcessWitness.matches(identity)) == true {
                kill(identity.pid, SIGTERM)
            }
        }
        XCTAssertFalse(try witness.authenticatedRunning(bundle: app, manifest: manifest, receipt: receipt))
        try witness.launch(bundle: app, manifest: manifest, receipt: receipt)
        XCTAssertTrue(try witness.authenticatedRunning(bundle: app, manifest: manifest, receipt: receipt))
        let replay = OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1))
        XCTAssertFalse(try witness.authenticatedRunning(bundle: app, manifest: manifest, receipt: replay))
        let freshObserver = AuthenticatedUpdateProcessWitness()
        XCTAssertFalse(try freshObserver.authenticatedRunning(bundle: app, manifest: manifest, receipt: receipt))
    }
    func testSecurityValidatorAcceptsActualAdHocBundleAndRejectsTampering() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let app = parent.appendingPathComponent("SignedFixture.app")
        let contents = app.appendingPathComponent("Contents")
        let executables = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: executables.appendingPathComponent("Fixture"))
        let plist: [String: Any] = ["CFBundleIdentifier": "test.watt.update-fixture", "CFBundleVersion": "2", "CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "13.0"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let resources = contents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: false)
        let resource = resources.appendingPathComponent("sealed.txt")
        try Data("original".utf8).write(to: resource)
        let signer = Process(); signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signer.arguments = ["--force", "--sign", "-", app.path]
        try signer.run(); signer.waitUntilExit(); XCTAssertEqual(signer.terminationStatus, 0)
        let identity = try SecurityUpdateCodeValidator().verify(bundle: app)
        XCTAssertEqual(identity.identifier, "test.watt.update-fixture"); XCTAssertEqual(identity.build, 2)
        XCTAssertEqual(identity.codeHash.count, 20)
        try Data("tampered".utf8).write(to: resource)
        XCTAssertThrowsError(try SecurityUpdateCodeValidator().verify(bundle: app))
    }
    private func fixture(_ parent: URL, admin: Bool = false) throws -> (ProductionUpdateInstallationDriver, OperationReceipt, UpdateManifest, Data, URL, FixtureUpdateWitness) {
        let app = parent.appendingPathComponent("Watt.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let original = VerifiedUpdateBundle(identifier: "test.watt", build: 1, minimumSystemVersion: "13.0", codeHash: Data(repeating: 1, count: 20))
        try JSONEncoder().encode(original).write(to: app.appendingPathComponent("identity.json"))
        let replacement = VerifiedUpdateBundle(identifier: "test.watt", build: 2, minimumSystemVersion: "13.0", codeHash: Data(repeating: 2, count: 20))
        let bytes = testUSTAR([("Watt.app/", Data(), 53), ("Watt.app/identity.json", try JSONEncoder().encode(replacement), 48)])
        let manifest = UpdateManifest(identity: "test.watt", build: 2, sha256: Data(SHA256.hash(data: bytes)), minimumSystemVersion: "13.0")
        let witness = FixtureUpdateWitness()
        let driver = try ProductionUpdateInstallationDriver(application: app, stagingDirectory: parent.appendingPathComponent("staging"), validator: FixtureUpdateValidator(), witness: witness, requiresAdministrator: { _, _ in admin })
        return (driver, OperationReceipt(createdAt: Date()), manifest, bytes, app, witness)
    }
    func testVerifiedReplacementClearsQuarantineAfterTheDigestCheck() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let app = parent.appendingPathComponent("Watt.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let original = VerifiedUpdateBundle(identifier: "test.watt", build: 1, minimumSystemVersion: "13.0", codeHash: Data(repeating: 1, count: 20))
        try JSONEncoder().encode(original).write(to: app.appendingPathComponent("identity.json"))
        let replacement = VerifiedUpdateBundle(identifier: "test.watt", build: 2, minimumSystemVersion: "13.0", codeHash: Data(repeating: 2, count: 20))
        let bytes = testUSTAR([("Watt.app/", Data(), 53), ("Watt.app/identity.json", try JSONEncoder().encode(replacement), 48)])
        let manifest = UpdateManifest(identity: "test.watt", build: 2, sha256: Data(SHA256.hash(data: bytes)), minimumSystemVersion: "13.0")
        let marker = Array("0083;00000000;WattTest;".utf8)
        XCTAssertEqual(marker.withUnsafeBytes { setxattr(app.path, QuarantineAttribute.name, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW) }, 0)
        let witness = FixtureUpdateWitness()
        let driver = try ProductionUpdateInstallationDriver(application: app, stagingDirectory: parent.appendingPathComponent("staging"),
            validator: QuarantineMarkingValidator(), witness: witness, requiresAdministrator: { _, _ in false })
        let receipt = OperationReceipt(createdAt: Date())
        XCTAssertThrowsError(try driver.stage(Data("bad".utf8), manifest: manifest, receipt: receipt))
        XCTAssertGreaterThanOrEqual(getxattr(app.path, QuarantineAttribute.name, nil, 0, 0, XATTR_NOFOLLOW), 0)
        try driver.stage(bytes, manifest: manifest, receipt: receipt)
        try driver.replace(manifest: manifest, receipt: receipt)
        XCTAssertTrue(try driver.placement(manifest: manifest, receipt: receipt) == .replacement)
        XCTAssertLessThan(getxattr(app.path, QuarantineAttribute.name, nil, 0, 0, XATTR_NOFOLLOW), 0)
        try driver.launch(manifest: manifest, receipt: receipt)
        XCTAssertLessThan(getxattr(app.path, QuarantineAttribute.name, nil, 0, 0, XATTR_NOFOLLOW), 0)
    }
    func testStageReplaceActualWitnessAndRollback() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let (driver, receipt, manifest, bytes, _, witness) = try fixture(parent)
        try driver.stage(bytes, manifest: manifest, receipt: receipt)
        try driver.verifyStaged(manifest: manifest, receipt: receipt)
        try driver.replace(manifest: manifest, receipt: receipt)
        XCTAssertTrue(try driver.placement(manifest: manifest, receipt: receipt) == .replacement)
        try driver.launch(manifest: manifest, receipt: receipt)
        XCTAssertFalse(try driver.launched(manifest: manifest, receipt: receipt))
        witness.acknowledged = OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1))
        XCTAssertFalse(try driver.launched(manifest: manifest, receipt: receipt))
        witness.acknowledged = receipt
        XCTAssertTrue(try driver.launched(manifest: manifest, receipt: receipt))
        try driver.rollback(receipt: receipt)
        XCTAssertTrue(try driver.placement(manifest: manifest, receipt: receipt) == .original)
    }
    func testProtectedGenerationRequiresAdminBeforeReplacementAndCanDiscard() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let (driver, receipt, manifest, bytes, app, _) = try fixture(parent, admin: true)
        let original = try Data(contentsOf: app.appendingPathComponent("identity.json"))
        try driver.stage(bytes, manifest: manifest, receipt: receipt)
        XCTAssertThrowsError(try driver.preflightReplacement(manifest: manifest, receipt: receipt)) { XCTAssertEqual($0 as? ServiceFailure, .adminRequired) }
        XCTAssertThrowsError(try driver.replace(manifest: manifest, receipt: receipt)) { XCTAssertEqual($0 as? ServiceFailure, .adminRequired) }
        XCTAssertEqual(try Data(contentsOf: app.appendingPathComponent("identity.json")), original)
        try driver.discard(receipt: receipt); XCTAssertTrue(try driver.stagingAbsent(receipt: receipt))
    }
    func testRejectsWrongDigestAndReceiptReplayAndUnrelatedReplacement() throws {
        let parent = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: parent) }
        let (driver, receipt, manifest, bytes, app, _) = try fixture(parent)
        try driver.discard(receipt: receipt)
        XCTAssertTrue(try driver.stagingAbsent(receipt: receipt))
        XCTAssertThrowsError(try driver.stage(Data("bad".utf8), manifest: manifest, receipt: receipt))
        try driver.stage(bytes, manifest: manifest, receipt: receipt)
        let replay = OperationReceipt(id: receipt.id, createdAt: receipt.createdAt.addingTimeInterval(1))
        XCTAssertThrowsError(try driver.verifyStaged(manifest: manifest, receipt: replay))
        try Data("foreign".utf8).write(to: app.appendingPathComponent("identity.json"))
        XCTAssertThrowsError(try driver.replace(manifest: manifest, receipt: receipt))
        XCTAssertThrowsError(try driver.rollback(receipt: receipt))
        XCTAssertEqual(try Data(contentsOf: app.appendingPathComponent("identity.json")), Data("foreign".utf8))
    }
}

@MainActor
private final class RecoveryDiagnosticStorage: PreferenceStorage {
    var bytes: Data
    var reads = 0
    var failingRead: Int?
    init(bytes: Data) { self.bytes = bytes }
    func read(key: String) throws -> Data? {
        reads += 1
        if reads == failingRead { throw ServiceFailure.persistence }
        return bytes
    }
    func write(_ data: Data, key: String) throws { bytes = data }
}

@MainActor
private struct RecoveryDiagnosticSource: UpdateSource {
    func check() async throws -> SignedUpdate? { nil }
    func download(_ release: SignedUpdate) async throws -> Data { throw ServiceFailure.network }
}

@MainActor
private struct RecoveryDiagnosticDriver: UpdateInstallationDriver {
    func stage(_ bytes: Data, manifest: UpdateManifest, receipt: OperationReceipt) throws { throw ServiceFailure.denied }
    func verifyStaged(manifest: UpdateManifest, receipt: OperationReceipt) throws {}
    func replace(manifest: UpdateManifest, receipt: OperationReceipt) throws { throw ServiceFailure.denied }
    func placement(manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdatePlacement { .uncertain }
    func rollback(receipt: OperationReceipt) throws { throw ServiceFailure.denied }
    func launch(manifest: UpdateManifest, receipt: OperationReceipt) throws { throw ServiceFailure.denied }
    func launched(manifest: UpdateManifest, receipt: OperationReceipt) throws -> Bool { false }
    func discard(receipt: OperationReceipt) throws { throw ServiceFailure.denied }
    func stagingAbsent(receipt: OperationReceipt) throws -> Bool { false }
}

@MainActor
private final class RecoveryDiagnosticCoordinator: ProtectedUpdateCoordinating {
    let administratorCommand: String? = nil
    let packageDirectory: URL? = nil
    var installCount = 0
    func install(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt,
                 prepareOwnershipTransfer: () throws -> Void) async throws -> UpdateState {
        installCount += 1
        return .handoffAccepted(receipt)
    }
    func recover(release: SignedUpdate, manifest: UpdateManifest, receipt: OperationReceipt) throws -> UpdateState {
        .failed(.interruptedUpdate, receipt)
    }
}

@MainActor
final class ProtectedUpdateRecoveryDiagnosticTests: XCTestCase {
    private func fixture(phase: UpdateTransaction.Phase = .protectedHandoff, invalidSignature: Bool = false) throws
        -> (UpdateAdapter, RecoveryDiagnosticStorage, RecoveryDiagnosticCoordinator, OperationReceipt) {
        let key = Curve25519.Signing.PrivateKey()
        let trust = UpdateTrust(identity: "test.recovery", currentBuild: 1,
            hostSystemVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0), publicKey: key.publicKey)
        let manifest = UpdateManifest(identity: trust.identity, build: 2, sha256: Data(SHA256.hash(data: Data())), minimumSystemVersion: "13.0")
        let payload = try JSONEncoder().encode(manifest)
        let release = SignedUpdate(payload: payload, signature: invalidSignature ? Data(repeating: 0, count: 64) : try key.signature(for: payload))
        let receipt = OperationReceipt(createdAt: Date())
        let storage = RecoveryDiagnosticStorage(bytes: try JSONEncoder().encode([UpdateTransaction(receipt: receipt, release: release, phase: phase)]))
        let coordinator = RecoveryDiagnosticCoordinator()
        let adapter = UpdateAdapter(source: RecoveryDiagnosticSource(), driver: RecoveryDiagnosticDriver(), storage: storage,
            trust: trust, protectedUpdates: coordinator)
        return (adapter, storage, coordinator, receipt)
    }

    func testInitialUntrustedJournalPreservesIdentityFailure() async throws {
        let (adapter, _, coordinator, _) = try fixture(invalidSignature: true)
        let pending = await adapter.recoverProtectedStartup()
        XCTAssertTrue(pending.isEmpty)
        XCTAssertEqual(adapter.state, .failed(.untrustedIdentity, nil))
        XCTAssertEqual(coordinator.installCount, 0)
    }

    func testFailedRescanKeepsAuthenticatedReceiptAndReportsPersistenceFailure() async throws {
        let (adapter, storage, coordinator, receipt) = try fixture()
        storage.failingRead = 3 // Initial inventory and per-receipt recovery succeed; refreshed inventory fails.
        let pending = await adapter.recoverProtectedStartup()
        XCTAssertEqual(pending.map(\.receipt), [receipt])
        XCTAssertEqual(adapter.state, .failed(.persistence, nil))
        let result = await adapter.install(receipt: receipt)
        guard case .failure(.denied) = result else { return XCTFail("Recovery must not grant install consent") }
        XCTAssertEqual(coordinator.installCount, 0)
    }

    func testRestoringStagedOfferDoesNotRestoreInstallConsent() async throws {
        let (adapter, _, coordinator, receipt) = try fixture(phase: .staged)
        let pending = await adapter.recoverProtectedStartup()
        XCTAssertEqual(pending.map(\.receipt), [receipt])
        XCTAssertEqual(adapter.state, .staged(receipt))
        let result = await adapter.install(receipt: receipt)
        guard case .failure(.denied) = result else { return XCTFail("A staged offer still needs explicit confirmation") }
        XCTAssertEqual(coordinator.installCount, 0)
    }
}

@MainActor
final class ProtectedUpdateAdministratorCommandTests: XCTestCase {
    func testRotatedGenerationRetryPreservesOriginalCommandAndRefusesTampering() throws {
        let fixture = try updaterTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: fixture) }
        let package = fixture.appendingPathComponent("package", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let installationID = UUID(), receipt = MaintenanceReceipt(createdAt: Date())
        let oldHash = Data(repeating: 1, count: 20), newHash = Data(repeating: 2, count: 20)
        let previous = try ProtectedHelperRecord(installationID: installationID, generation: 1, build: 1,
            appHashes: [oldHash], helperHashes: [oldHash], maintenanceHashes: [oldHash])
        let binding = try ProtectedMaintenanceBinding(receipt: ProtectedMaintenanceReceipt(id: receipt.id, createdAt: receipt.createdAt),
            installationID: installationID, previousGeneration: 1, nextGeneration: 2, operation: .update,
            signedPayloadSHA256: Data(repeating: 3, count: 32), archiveSHA256: Data(repeating: 4, count: 32), build: 2,
            replacementAppHashes: [newHash], replacementHelperHashes: [newHash], replacementMaintenanceHashes: [newHash])
        let current = try ProtectedHelperRecord(installationID: installationID, generation: 2, build: 2,
            appHashes: [newHash], helperHashes: [newHash], maintenanceHashes: [newHash], maintenanceBinding: binding)
        let parent = MaintenanceProcessIdentity(pid: 42, uid: getuid(), startedAtMicroseconds: 1, codeDirectoryHash: oldHash)
        let request = try MaintenanceRequest(receipt: receipt, installationID: installationID, generation: 1,
            operation: .update, parent: parent, candidateSHA256: binding.archiveSHA256)
        let envelope = try ProtectedUpdateEnvelope(request: request, binding: binding, minimumSystemVersion: "13.0")
        try ProtectedUpdatePackage.writeFile(JSONEncoder().encode(previous), named: "previous-record.json", directory: fixture)
        let expectedRecordURL = ProtectedHelperRecord.directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent("\(installationID.uuidString)-1", isDirectory: true).appendingPathComponent("record.json")
        // Only the root-record read authority is substituted; package writes/reads use the actual
        // private filesystem and command paths remain derived from the fixed generation layout.
        let readPrevious: (URL) throws -> ProtectedHelperRecord = { requested in
            XCTAssertEqual(requested, expectedRecordURL)
            return try JSONDecoder().decode(ProtectedHelperRecord.self,
                from: ProtectedUpdatePackage.readFile("previous-record.json", directory: fixture, limit: 16384))
        }
        let originalCommand = try ProtectedUpdateCoordinator.prepareAdministratorCommand(package: package,
            envelope: envelope, installation: previous, readPreviousRecord: readPrevious)
        let commandBytes = try ProtectedUpdatePackage.readFile("administrator-command.txt", directory: package, limit: 16384)
        let retryCommand = try ProtectedUpdateCoordinator.prepareAdministratorCommand(package: package,
            envelope: envelope, installation: current, readPreviousRecord: readPrevious)
        XCTAssertEqual(retryCommand, originalCommand)
        XCTAssertTrue(retryCommand.contains(previous.applicationURL.appendingPathComponent("Contents/MacOS/WattHelperInstaller").path))
        XCTAssertFalse(retryCommand.contains(current.applicationURL.appendingPathComponent("Contents/MacOS/WattHelperInstaller").path))
        XCTAssertEqual(try ProtectedUpdatePackage.readFile("administrator-command.txt", directory: package, limit: 16384), commandBytes)
        let tampered = Data("sudo /untrusted/installer\n".utf8)
        try tampered.write(to: package.appendingPathComponent("administrator-command.txt"))
        XCTAssertThrowsError(try ProtectedUpdateCoordinator.prepareAdministratorCommand(package: package,
            envelope: envelope, installation: current, readPreviousRecord: readPrevious)) {
            XCTAssertEqual($0 as? ServiceFailure, .untrustedIdentity)
        }
        XCTAssertEqual(try ProtectedUpdatePackage.readFile("administrator-command.txt", directory: package, limit: 16384), tampered,
            "A mismatching command must never be overwritten or adopted")
    }
}
