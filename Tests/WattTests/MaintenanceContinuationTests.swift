import Foundation
import XCTest
import Darwin
@testable import Watt
#if SWIFT_PACKAGE
import WattMaintenanceShared
#endif

@MainActor
final class MaintenanceContinuationTests: XCTestCase {
    @MainActor private final class HelperPresence { var absent = true; var checks = 0 }
    private func addForeignFile(at url: URL) throws {
        do { try Data("foreign".utf8).write(to: url) }
        catch {
            let failure = error as NSError
            let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError
            if Bundle.main.bundleURL.pathExtension == "app", failure.domain == NSCocoaErrorDomain,
               failure.code == CocoaError.fileWriteNoPermission.rawValue,
               underlying?.domain == NSPOSIXErrorDomain, underlying?.code == Int(EPERM) {
                throw XCTSkip("Native host policy refuses fixture app mutation (EPERM). The real mutation/refusal case passes in SwiftPM; OS protection remains enabled.")
            }
            throw error
        }
    }
    private func observeReady(_ pid: Int32) throws -> MaintenanceProcessWitness.LiveObservation {
        let deadline = Date().addingTimeInterval(1)
        while true {
            do { return try MaintenanceProcessWitness.observeLive(pid: pid) }
            catch { if Date() >= deadline { throw error }; usleep(10_000) }
        }
    }
    private func fixture(withPreferences: Bool = false) throws -> (URL, Process, MaintenanceRequest, MaintenanceRemovalPlan) {
        guard let canonical = realpath(FileManager.default.temporaryDirectory.path, nil) else { throw CocoaError(.fileNoSuchFile) }
        defer { free(canonical) }
        let root = URL(fileURLWithPath: String(cString: canonical)).appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Fixture.app")
        let executable = app.appendingPathComponent("Contents/MacOS/Fixture")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sleep"), to: executable)
        // A unique ad-hoc identity keeps each independently moved fixture distinct from
        // Apple's platform binary and from Security's cached identity for prior fixtures.
        let signer = Process(); signer.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signer.arguments = ["--force", "--sign", "-", "--identifier", "test.watt.recovery." + UUID().uuidString, executable.path]
        try signer.run(); signer.waitUntilExit()
        guard signer.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
        if withPreferences {
            let identifier = "test.watt.recovery." + UUID().uuidString
            let info = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": identifier], format: .xml, options: 0)
            try info.write(to: app.appendingPathComponent("Contents/Info.plist"))
            let home = String(cString: getpwuid(getuid())!.pointee.pw_dir)
            try Data("owned preferences".utf8).write(to: URL(fileURLWithPath: home)
                .appendingPathComponent("Library/Preferences/" + identifier + ".plist"))
        }
        try Data("sentinel".utf8).write(to: root.appendingPathComponent("outside"))
        let process = Process(); process.executableURL = executable; process.arguments = ["30"]
        try process.run()
        let parent = try observeReady(process.processIdentifier).identity
        let installation = UUID()
        let plan = try MaintenanceRemovalPlan.enroll(installationID: installation, generation: 1, parent: parent)
        let request = try MaintenanceRequest(receipt: MaintenanceReceipt(createdAt: Date()), installationID: installation,
            generation: 1, operation: .uninstall, parent: parent, removalPlanSHA256: plan.digest)
        return (root, process, request, plan)
    }
    func testExternalObserverRequiresExitThenRemovesExactFixtureBundle() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .accepted)
        XCTAssertFalse(try plan.isAbsent())
        XCTAssertThrowsError(try MaintenanceRemovalSession(directory: directory, request: request, plan: plan))
        process.terminate(); process.waitUntilExit()
        try await session.finish(timeout: 1)
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .completed)
        XCTAssertTrue(try plan.isAbsent())
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("outside"), encoding: .utf8), "sentinel")
    }
    func testLiveParentTimeoutAndReplayRemainInterrupted() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        var session: MaintenanceRemovalSession? = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        do { try await session!.finish(timeout: 0.01); XCTFail("live parent") } catch {}
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .interrupted)
        XCTAssertFalse(try plan.isAbsent())
        session = nil
        XCTAssertThrowsError(try MaintenanceRemovalSession(directory: directory, request: request, plan: plan))
    }
    func testForeignAdditionAfterHandoffIsRetained() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        let foreign = root.appendingPathComponent("Fixture.app/foreign")
        try addForeignFile(at: foreign)
        process.terminate(); process.waitUntilExit()
        do { try await session.finish(timeout: 1); XCTFail("foreign addition") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .interrupted)
    }
    func testDurableWriterTransferAndDigestBinding() throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        let previous = try AtomicMaintenanceStorage(directory: directory)
        try previous.write(Data("intent".utf8), key: "fixture-intent")
        XCTAssertThrowsError(try MaintenanceRemovalSession(directory: directory, request: request, plan: plan))
        previous.close()
        XCTAssertThrowsError(try previous.write(Data(), key: "fixture-intent"))
        let forged = try MaintenanceRequest(receipt: request.receipt, installationID: request.installationID,
            generation: request.generation, operation: .uninstall, parent: request.parent,
            removalPlanSHA256: Data(repeating: 0, count: 32))
        XCTAssertThrowsError(try MaintenanceRemovalSession(directory: directory, request: forged, plan: plan))
        let accepted = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        XCTAssertEqual(accepted.record.phase, .accepted)
        XCTAssertThrowsError(try AtomicMaintenanceStorage(directory: directory))
    }

    func testRecreatedRecoveryAuthenticatesActualBundleAndRestoresExactBackup() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        var session: MaintenanceRemovalSession? = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        process.terminate(); process.waitUntilExit()
        try await session!.finish(timeout: 1)
        session = nil
        let backup = root.appendingPathComponent(".Fixture.app.watt-removal-" + request.receipt.id.uuidString)
        let recovery = Process(); recovery.executableURL = backup.appendingPathComponent("Contents/MacOS/Fixture")
        recovery.arguments = ["30"]; try recovery.run()
        defer { if recovery.isRunning { recovery.terminate(); recovery.waitUntilExit() } }
        let observer = try observeReady(recovery.processIdentifier)
        let restored = try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: observer)
        XCTAssertEqual(restored.phase, .restored)
        XCTAssertTrue(FileManager.default.fileExists(atPath: plan.applicationPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertThrowsError(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: observer))
        recovery.terminate(); recovery.waitUntilExit()
        let freshParent = Process(); freshParent.executableURL = root.appendingPathComponent("Fixture.app/Contents/MacOS/Fixture")
        freshParent.arguments = ["30"]; try freshParent.run()
        defer { if freshParent.isRunning { freshParent.terminate(); freshParent.waitUntilExit() } }
        let identity = try observeReady(freshParent.processIdentifier).identity
        let freshPlan = try MaintenanceRemovalPlan.enroll(installationID: request.installationID, generation: 1, parent: identity)
        let freshRequest = try MaintenanceRequest(receipt: MaintenanceReceipt(createdAt: Date()), installationID: request.installationID,
            generation: 1, operation: .uninstall, parent: identity, removalPlanSHA256: freshPlan.digest)
        let fresh = try MaintenanceRemovalSession(directory: directory, request: freshRequest, plan: freshPlan)
        XCTAssertEqual(fresh.record.phase, .accepted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("restored-" + request.receipt.id.uuidString + ".json").path))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("outside"), encoding: .utf8), "sentinel")
    }

    func testRecoveryRejectsUnrelatedActualProcessAndChangedBackup() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        var session: MaintenanceRemovalSession? = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        do { try await session!.finish(timeout: 0.01); XCTFail("live parent") } catch {}
        session = nil
        let outsider = Process(); outsider.executableURL = URL(fileURLWithPath: "/bin/sleep"); outsider.arguments = ["30"]
        try outsider.run()
        defer { if outsider.isRunning { outsider.terminate(); outsider.waitUntilExit() } }
        let unrelated = try observeReady(outsider.processIdentifier)
        XCTAssertThrowsError(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: unrelated))
        try addForeignFile(at: root.appendingPathComponent("Fixture.app/foreign"))
        let actual = try MaintenanceProcessWitness.observeLive(pid: process.processIdentifier)
        XCTAssertThrowsError(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: actual))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Fixture.app/foreign").path))
    }

    func testInterruptedAppMoveRestoresPreferencesWithoutOverwritingForeignBackup() async throws {
        let (root, process, request, plan) = try fixture(withPreferences: true)
        let preferences = URL(fileURLWithPath: try XCTUnwrap(plan.configurationPath))
        let preferencesBackup = preferences.deletingLastPathComponent().appendingPathComponent(".\(preferences.lastPathComponent).watt-removal-\(request.receipt.id.uuidString)")
        defer {
            if process.isRunning { process.terminate(); process.waitUntilExit() }
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: preferences)
            try? FileManager.default.removeItem(at: preferencesBackup)
        }
        let directory = root.appendingPathComponent("journal")
        var session: MaintenanceRemovalSession? = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        let foreignBackup = root.appendingPathComponent(".Fixture.app.watt-removal-" + request.receipt.id.uuidString)
        try Data("foreign backup".utf8).write(to: foreignBackup)
        process.terminate(); process.waitUntilExit()
        do { try await session!.finish(timeout: 1); XCTFail("existing backup must refuse app move") } catch {}
        session = nil
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .interrupted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: preferences.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: preferencesBackup.path))
        let recovery = Process(); recovery.executableURL = root.appendingPathComponent("Fixture.app/Contents/MacOS/Fixture")
        recovery.arguments = ["30"]; try recovery.run()
        defer { if recovery.isRunning { recovery.terminate(); recovery.waitUntilExit() } }
        let actual = try observeReady(recovery.processIdentifier)
        XCTAssertEqual(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: actual).phase, .restored)
        XCTAssertEqual(try String(contentsOf: preferences, encoding: .utf8), "owned preferences")
        XCTAssertEqual(try String(contentsOf: foreignBackup, encoding: .utf8), "foreign backup")
    }

    func testRecoveryRejectsForeignPreferencesAndForgedConfigurationPath() async throws {
        let (root, process, request, plan) = try fixture(withPreferences: true)
        let preferences = URL(fileURLWithPath: try XCTUnwrap(plan.configurationPath))
        let preferencesBackup = preferences.deletingLastPathComponent().appendingPathComponent(".\(preferences.lastPathComponent).watt-removal-\(request.receipt.id.uuidString)")
        defer {
            if process.isRunning { process.terminate(); process.waitUntilExit() }
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: preferences)
            try? FileManager.default.removeItem(at: preferencesBackup)
        }
        let original = try MaintenanceProcessWitness.observeLive(pid: process.processIdentifier)
        var altered = try XCTUnwrap(JSONSerialization.jsonObject(with: plan.encoded()) as? [String: Any])
        altered["configurationPath"] = root.appendingPathComponent("outside").path
        let forged = try JSONDecoder().decode(MaintenanceRemovalPlan.self, from: JSONSerialization.data(withJSONObject: altered))
        XCTAssertThrowsError(try forged.restore(receipt: request.receipt, observer: original))
        let directory = root.appendingPathComponent("journal")
        var session: MaintenanceRemovalSession? = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        try Data("foreign backup".utf8).write(to: root.appendingPathComponent(".Fixture.app.watt-removal-" + request.receipt.id.uuidString))
        process.terminate(); process.waitUntilExit()
        do { try await session!.finish(timeout: 1); XCTFail("existing backup") } catch {}
        session = nil
        try Data("intervening preferences".utf8).write(to: preferences)
        let recovery = Process(); recovery.executableURL = root.appendingPathComponent("Fixture.app/Contents/MacOS/Fixture")
        recovery.arguments = ["30"]; try recovery.run()
        defer { if recovery.isRunning { recovery.terminate(); recovery.waitUntilExit() } }
        let actual = try observeReady(recovery.processIdentifier)
        XCTAssertThrowsError(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: actual))
        XCTAssertEqual(try String(contentsOf: preferences, encoding: .utf8), "intervening preferences")
        XCTAssertEqual(try String(contentsOf: preferencesBackup, encoding: .utf8), "owned preferences")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("outside"), encoding: .utf8), "sentinel")
    }

    func testMissingEntireApplicationAncestryIsAbsence() throws {
        let (root, process, _, plan) = try fixture()
        process.terminate(); process.waitUntilExit()
        try FileManager.default.removeItem(at: root)
        XCTAssertTrue(try plan.isAbsent())
    }

    func testJournalDirectorySwapRefusesEffectsAndRecoveryWriterContention() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("journal")
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        let actual = try MaintenanceProcessWitness.observeLive(pid: process.processIdentifier)
        XCTAssertThrowsError(try MaintenanceRemovalSession.recover(directory: directory, receipt: request.receipt, observer: actual))
        try FileManager.default.moveItem(at: directory, to: root.appendingPathComponent("original-journal"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        process.terminate(); process.waitUntilExit()
        do { try await session.finish(timeout: 1); XCTFail("swapped directory") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: plan.applicationPath))
    }

    func testHelperAppearingAfterHandoffPreventsEffects() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let presence = HelperPresence()
        let directory = root.appendingPathComponent("journal")
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan,
            helperAbsence: { presence.absent })
        presence.absent = false
        process.terminate(); process.waitUntilExit()
        do { try await session.finish(timeout: 1); XCTFail("new helper must prevent removal") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: plan.applicationPath))
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .interrupted)
    }

    func testHelperAppearingBeforeTerminalCommitNeverReportsCompleted() async throws {
        let (root, process, request, plan) = try fixture()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() }; try? FileManager.default.removeItem(at: root) }
        let presence = HelperPresence()
        let directory = root.appendingPathComponent("journal")
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan,
            helperAbsence: { presence.checks += 1; return presence.checks == 1 })
        process.terminate(); process.waitUntilExit()
        do { try await session.finish(timeout: 1); XCTFail("new helper must prevent terminal success") } catch {}
        XCTAssertTrue(try plan.isAbsent())
        XCTAssertEqual(presence.checks, 2)
        XCTAssertEqual(try MaintenanceRemovalSession.read(directory: directory).phase, .interrupted)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".Fixture.app.watt-removal-" + request.receipt.id.uuidString).path))
    }

}
