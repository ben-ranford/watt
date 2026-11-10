import Foundation
import XCTest
import Security
@testable import Watt
#if SWIFT_PACKAGE
import WattMaintenanceShared
#endif

@MainActor
final class MaintenanceProcessTests: XCTestCase {
    func testRealChildIdentityAndExitWitnessRejectPIDReuseClaims() async throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["20"]
        try child.run()
        defer { if child.isRunning { child.terminate(); child.waitUntilExit() } }
        let witness = try MaintenanceProcessWitness.observeLive(pid: child.processIdentifier)
        let observed = witness.identity
        XCTAssertTrue(try MaintenanceProcessWitness.matches(observed))
        XCTAssertFalse(try witness.hasExited())
        let timedOut = try await witness.waitForExit(timeout: 0.01)
        XCTAssertFalse(timedOut)
        let forged = MaintenanceProcessIdentity(pid: observed.pid, uid: observed.uid,
            startedAtMicroseconds: observed.startedAtMicroseconds + 1, codeDirectoryHash: observed.codeDirectoryHash)
        XCTAssertFalse(try MaintenanceProcessWitness.matches(forged))
        child.terminate(); child.waitUntilExit()
        XCTAssertTrue(try witness.hasExited())
    }

    func testClosedReaderThrowsWithoutSIGPIPE() throws {
        let pipe = Pipe()
        try pipe.fileHandleForReading.close()
        XCTAssertThrowsError(try MaintenanceChannel.write(Data("request".utf8), to: pipe.fileHandleForWriting.fileDescriptor))
    }

    func testFramingRoundTripAndTruncationRefusal() throws {
        let pipe = Pipe()
        let payload = Data("exact receipt".utf8)
        try MaintenanceChannel.write(payload, to: pipe.fileHandleForWriting.fileDescriptor)
        XCTAssertEqual(try MaintenanceChannel.read(from: pipe.fileHandleForReading.fileDescriptor), payload)
        try pipe.fileHandleForWriting.close()
        XCTAssertThrowsError(try MaintenanceChannel.read(from: pipe.fileHandleForReading.fileDescriptor, timeout: 0.1))
    }

    func testMalformedRequestAndOversizeRejectBeforeDispatch() throws {
        XCTAssertThrowsError(try MaintenanceRequest.decode(Data(repeating: 0, count: 8193)))
        XCTAssertThrowsError(try MaintenanceRequest.decode(Data("{}".utf8)))
        let pipe = Pipe()
        XCTAssertThrowsError(try MaintenanceChannel.write(Data(repeating: 0, count: 1_048_577),
            to: pipe.fileHandleForWriting.fileDescriptor))
        XCTAssertThrowsError(try MaintenanceChannel.read(from: pipe.fileHandleForReading.fileDescriptor, timeout: 0.01))
    }
    #if SWIFT_PACKAGE
    func testActualBundledCompanionAuthenticatesPrivatePipeWithoutEffects() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let executable = root.appendingPathComponent(".build/out/Products/Debug/WattMaintenance").resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw XCTSkip("SPM companion binary is not available at this toolchain's output location")
        }
        var code: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(executable as CFURL, [], &code), errSecSuccess)
        var info: CFDictionary?
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(code), SecCSFlags(rawValue: kSecCSSigningInformation), &info), errSecSuccess)
        let hash = try XCTUnwrap((info as? [String: Any])?[kSecCodeInfoUnique as String] as? Data)
        let id = UUID()
        let handoff = try MaintenanceHandoff(executable: executable, expectedCodeHash: hash, installationID: id, generation: 1)
        let parent = try MaintenanceProcessWitness.observe(pid: ProcessInfo.processInfo.processIdentifier)
        let request = try MaintenanceRequest(receipt: MaintenanceReceipt(createdAt: Date()), installationID: id,
            generation: 1, operation: .removeHelper, parent: parent)
        try handoff.authenticateCompanion(for: request)
    }
    #endif

}
