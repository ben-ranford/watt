import XCTest
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
import WattMaintenanceShared
#endif
@testable import Watt

@MainActor
private final class FixtureRemovalWitness: RemovalOwnershipWitness {
    let expected: RemovalManifest
    var running = false
    init(_ expected: RemovalManifest) { self.expected = expected }
    func validateInstallation(_ manifest: RemovalManifest) throws {
        guard manifest == expected else { throw ServiceFailure.untrustedIdentity }
    }
    func processesAndRegistrations(_ manifest: RemovalManifest) async throws -> RemovalInventory {
        try validateInstallation(manifest)
        return RemovalInventory(presentPaths: [], helperRunning: false, appRunning: running)
    }
}

@MainActor
final class ProductionOwnedRemovalTests: XCTestCase {
    private func fixture() throws -> (URL, RemovalManifest, FixtureRemovalWitness, InMemoryStorage) {
        guard let canonical = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileNoSuchFile) }
        defer { free(canonical) }
        let root = URL(fileURLWithPath: String(cString: canonical)).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let app = root.appendingPathComponent("Fixture.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: false)
        try Data("fixture".utf8).write(to: app.appendingPathComponent("owned"))
        try Data("outside".utf8).write(to: root.appendingPathComponent("sentinel"))
        let manifest = RemovalManifest(installationID: UUID(), resources: [.init(path: app.path, kind: .application)])
        return (root, manifest, FixtureRemovalWitness(manifest), InMemoryStorage())
    }
    private func transaction(_ manifest: RemovalManifest) -> RemovalTransaction {
        RemovalTransaction(receipt: OperationReceipt(createdAt: Date()), manifest: manifest,
            scope: .uninstall, baseline: RemovalInventory(presentPaths: Set(manifest.resources.map(\.path)),
                helperRunning: false, appRunning: false), phase: .removing)
    }
    func testRealTreeRemovalRetryRestartAndRestorePreserveSentinel() async throws {
        let (root, manifest, witness, _) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try AtomicMaintenanceStorage(directory: root.appendingPathComponent("journal"))
        let driver = try ProductionOwnedRemovalDriver(manifest: manifest, storage: storage, witness: witness)
        var txn = transaction(manifest)
        try driver.save(txn)
        try await driver.remove(manifest.resources[0], transaction: txn)
        try await driver.remove(manifest.resources[0], transaction: txn)
        let restarted = try ProductionOwnedRemovalDriver(manifest: manifest, storage: storage, witness: witness)
        let absent = try await restarted.inventory(manifest: manifest)
        XCTAssertTrue(absent.presentPaths.isEmpty)
        txn.phase = .rollingBack
        try restarted.save(txn)
        try await restarted.restore(manifest.resources[0], transaction: txn)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Fixture.app/owned"), encoding: .utf8), "fixture")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("sentinel"), encoding: .utf8), "outside")
    }
    func testForeignAdditionAndRunningAppRefuseRemoval() async throws {
        let (root, manifest, witness, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = try ProductionOwnedRemovalDriver(manifest: manifest, storage: storage, witness: witness)
        let txn = transaction(manifest); try driver.save(txn)
        witness.running = true
        do { try await driver.remove(manifest.resources[0], transaction: txn); XCTFail("live app") }
        catch { XCTAssertEqual(error as? ServiceFailure, .interruptedRemoval) }
        witness.running = false
        try Data("foreign".utf8).write(to: root.appendingPathComponent("Fixture.app/foreign"))
        do { try await driver.remove(manifest.resources[0], transaction: txn); XCTFail("foreign addition") }
        catch { XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Fixture.app/foreign").path))
    }
    func testRestoreConflictAndWrongReceiptRefused() async throws {
        let (root, manifest, witness, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = try ProductionOwnedRemovalDriver(manifest: manifest, storage: storage, witness: witness)
        var txn = transaction(manifest); try driver.save(txn)
        do { try driver.save(transaction(manifest)); XCTFail("different receipt") }
        catch { XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity) }
        try await driver.remove(manifest.resources[0], transaction: txn)
        try FileManager.default.createDirectory(atPath: manifest.resources[0].path, withIntermediateDirectories: false)
        txn.phase = .rollingBack; try driver.save(txn)
        do { try await driver.restore(manifest.resources[0], transaction: txn); XCTFail("overwrite") }
        catch { XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity) }
    }
    func testSymlinkAndFailedJournalCauseNoEffects() async throws {
        let (root, manifest, witness, storage) = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let driver = try ProductionOwnedRemovalDriver(manifest: manifest, storage: storage, witness: witness)
        let txn = transaction(manifest); try driver.save(txn)
        storage.failWrites = true
        do { try await driver.remove(manifest.resources[0], transaction: txn); XCTFail("journal failure") }
        catch { XCTAssertEqual(error as? ServiceFailure, .persistence) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.resources[0].path))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("Fixture.app/link"), withDestinationURL: root.appendingPathComponent("sentinel"))
        do { _ = try ProductionOwnedRemovalDriver(manifest: manifest, storage: InMemoryStorage(), witness: witness); XCTFail("symlink") }
        catch { XCTAssertEqual(error as? ServiceFailure, .untrustedIdentity) }
    }
}

@MainActor
final class ProductionRemovalCompositionTests: XCTestCase {
    private final class Presence { var absent = false }
    private func fixture(certificate: Bool = false) throws -> (URL, Bundle, ProductionRemovalComposition.Environment) {
        guard let canonical = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileNoSuchFile) }
        defer { free(canonical) }
        let root = URL(fileURLWithPath: String(cString: canonical)).appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Watt.app"), contents = app.appendingPathComponent("Contents")
        let binaries = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: binaries, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("fixture.c")
        try Data("int main(void) { return 0; }".utf8).write(to: source)
        let compiler = Process(); compiler.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compiler.arguments = ["clang", source.path, "-o", binaries.appendingPathComponent("Watt").path]
        try compiler.run(); compiler.waitUntilExit(); guard compiler.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.copyItem(at: binaries.appendingPathComponent("Watt"), to: binaries.appendingPathComponent("WattMaintenance"))
        var info: [String: Any] = ["CFBundleIdentifier": HelperIdentity.appIdentifier, "CFBundleVersion": HelperIdentity.build,
            "CFBundleExecutable": "Watt", "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "13.0"]
        if certificate { info["WATTHelperTrustMode"] = "certificate"; info["WATTSigningTeam"] = "ABCDEFGHIJ" }
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        for (path, identifier) in [(binaries.appendingPathComponent("WattMaintenance"), HelperIdentity.appIdentifier + ".maintenance"),
                                   (app, HelperIdentity.appIdentifier)] {
            let signer = Process(); signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            signer.arguments = ["--force", "--sign", "-", "--identifier", identifier, path.path]
            try signer.run(); signer.waitUntilExit(); guard signer.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
        }
        return (root, try XCTUnwrap(Bundle(url: app)), .init(identityDirectory: root.appendingPathComponent("identity"),
            protectedRecord: { _ in nil }, helperAbsent: { true }))
    }
    func testOrdinaryFactoryDoesNotRequireHelperOrReleaseConfigurationAndRetainsIdentity() throws {
        let (root, bundle, environment) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(try ProductionRemovalComposition.configured(bundle: bundle, helper: nil, environment: environment).route, .ordinary)
        let first = try Data(contentsOf: environment.identityDirectory.appendingPathComponent("installation.v1"))
        XCTAssertEqual(try ProductionRemovalComposition.configured(bundle: bundle, helper: nil, environment: environment).route, .ordinary)
        XCTAssertEqual(try Data(contentsOf: environment.identityDirectory.appendingPathComponent("installation.v1")), first)
    }
    func testUnknownOrChangedHelperInventoryRefusesOrdinaryRemoval() async throws {
        let (root, bundle, environment) = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let presence = Presence()
        let witness = ProductionRemovalComposition.Environment(identityDirectory: environment.identityDirectory,
            protectedRecord: environment.protectedRecord, helperAbsent: { presence.absent })
        XCTAssertThrowsError(try ProductionRemovalComposition.configured(bundle: bundle, helper: nil, environment: witness))
        XCTAssertFalse(FileManager.default.fileExists(atPath: witness.identityDirectory.path))
        presence.absent = true
        let removal = try ProductionRemovalComposition.configured(bundle: bundle, helper: nil, environment: witness)
        presence.absent = false
        let result = await removal.removeOwnedResources(receipt: OperationReceipt(createdAt: Date()))
        XCTAssertEqual(result, .failed(.unknownStatus))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundle.bundleURL.path))
    }
    func testCertificateFactoryRefusesAbsentServiceAndAdHocIdentity() throws {
        let (root, bundle, environment) = try fixture(certificate: true); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try ProductionRemovalComposition.configured(bundle: bundle, helper: nil, environment: environment))
        XCTAssertThrowsError(try ProductionRemovalComposition.configured(bundle: bundle, helper: FakeHelperService(), environment: environment))
        XCTAssertFalse(FileManager.default.fileExists(atPath: environment.identityDirectory.path))
    }
    func testProtectedPlacementParsingRequiresExactInstallationGenerationPath() throws {
        let id = UUID(), app = ProtectedHelperRecord.directory.appendingPathComponent("generations/" + id.uuidString + "-2/Watt.app")
        let coordinates = try XCTUnwrap(MaintenanceRemovalPlan.protectedCoordinates(application: app))
        XCTAssertEqual(coordinates.0, id); XCTAssertEqual(coordinates.1, 2)
        for suffix in [id.uuidString + "-0/Watt.app", id.uuidString + "-02/Watt.app", id.uuidString + "-2/Other.app", id.uuidString + "-2/Watt.app/Other"] {
            XCTAssertThrowsError(try MaintenanceRemovalPlan.protectedCoordinates(application: ProtectedHelperRecord.directory.appendingPathComponent("generations/" + suffix)))
        }
        XCTAssertNil(try MaintenanceRemovalPlan.protectedCoordinates(application: URL(fileURLWithPath: "/Applications/Watt.app")))
    }
}
