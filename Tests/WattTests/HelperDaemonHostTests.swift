import Foundation
import XCTest

/// Launches the embedded helper. That process is what the coverage run records
/// for the WattHelper target.
final class HelperDaemonHostTests: XCTestCase {
    func testHelperWithoutValidatedTrustExitsInsteadOfListening() throws {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/WattHelper")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: url.path), "Helper is embedded only in the app host")
        let process = Process()
        process.executableURL = url
        var environment = ProcessInfo.processInfo.environment
        if let profile = environment["LLVM_PROFILE_FILE"], !profile.isEmpty {
            let expanded = profile
                .replacingOccurrences(of: "%p", with: "helper")
                .replacingOccurrences(of: "%h", with: "host")
                .replacingOccurrences(of: "%m", with: "mod")
            let directory = URL(fileURLWithPath: expanded).deletingLastPathComponent()
            environment["LLVM_PROFILE_FILE"] = directory
                .appendingPathComponent("watt-helper-\(UUID().uuidString).profraw").path
        }
        process.environment = environment
        let error = Pipe()
        process.standardError = error
        process.standardOutput = Pipe()
        try process.run()
        let deadline = Date().addingTimeInterval(5)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            XCTFail("helper kept listening without a validated trust record")
            return
        }
        let stderr = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 78)
        XCTAssertTrue(stderr.contains("validated trust configuration required"))
    }
}
