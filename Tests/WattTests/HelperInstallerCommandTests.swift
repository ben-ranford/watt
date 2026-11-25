import Foundation
import XCTest
@testable import Watt
@testable import WattHelperInstaller

@MainActor
final class HelperInstallerCommandTests: XCTestCase {
    func testActualCoordinatorExportArgumentsParseWithoutPrivilegeOrEffects() throws {
        let package = URL(fileURLWithPath: "/Users/example/Update package's files")
        let arguments = ProtectedUpdateCoordinator.administratorArguments(package: package)
        XCTAssertEqual(try InstallerCommand.parse(arguments), .release(installation: nil,
            manifest: package.appendingPathComponent("manifest.json"),
            archive: package.appendingPathComponent("release.tar"),
            request: package.appendingPathComponent("request.json")))
        let options = stride(from: 1, to: arguments.count, by: 2).map { Array(arguments[$0...($0 + 1)]) }
        let reordered = [arguments[0]] + options.reversed().flatMap { $0 }
        XCTAssertEqual(try InstallerCommand.parse(reordered), try InstallerCommand.parse(arguments))
    }

    func testDuplicateUnknownMissingAndMixedOperationFlagsAreRejected() throws {
        let valid = ["--rotate-release", "--manifest", "/manifest.json", "--archive", "/release.tar", "--request", "/request.json"]
        for invalid in [
            valid + ["--request", "/other.json"],
            valid + ["--destination", "/Library/foreign"],
            Array(valid.dropLast()),
            ["--rotate-release", "--manifest", "--archive", "/release.tar", "--request", "/request.json"],
            ["--rotate-release", "--manifest", "/manifest.json", "--archive", "/release.tar"],
            ["--rotate-release", "--manifest", "relative.json", "--archive", "/release.tar", "--request", "/request.json"],
            ["--uninstall", "--request", "/request.json", "--generation", "1"],
            ["--recover", "--request", "/request.json"],
            ["--remove-helper", "--request", "/request.json"]
        ] {
            XCTAssertThrowsError(try InstallerCommand.parse(invalid), invalid.joined(separator: " "))
        }
    }

    func testExplicitInstallationAndRemovalFlagsAreOrderIndependent() throws {
        let id = UUID()
        XCTAssertEqual(try InstallerCommand.parse(["--rotate-release", "--request", "/request.json", "--archive", "/release.tar",
                                                  "--installation", id.uuidString, "--manifest", "/manifest.json"]),
            .release(installation: id, manifest: URL(fileURLWithPath: "/manifest.json"), archive: URL(fileURLWithPath: "/release.tar"), request: URL(fileURLWithPath: "/request.json")))
        XCTAssertEqual(try InstallerCommand.parse(["--uninstall", "--request", "/request.json", "--generation", "2", "--installation", id.uuidString]),
            .remove(installation: id, generation: 2, uninstall: true, request: URL(fileURLWithPath: "/request.json")))
        XCTAssertEqual(try InstallerCommand.parse(["--recover", "--generation", "2", "--installation", id.uuidString]),
                       .recover(installation: id, generation: 2))
    }
    func testDocumentedCommandsRejectMalformedValues() throws {
        let id = UUID().uuidString
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        XCTAssertEqual(try InstallerCommand.parse(["--preflight", "--source", "/Applications/Watt.app"]),
                       .preflight(URL(fileURLWithPath: "/Applications/Watt.app")))
        XCTAssertThrowsError(try InstallerCommand.parse(["--preflight", "--source", "Watt.app"]))
        let approval = String(repeating: "ab", count: 32)
        XCTAssertEqual(
            try InstallerCommand.parse(["--bootstrap-reviewed", "--source", "/Applications/Watt.app", "--approval", approval]),
            .reviewed(source: URL(fileURLWithPath: "/Applications/Watt.app"), approval: approval, rotate: false)
        )
        XCTAssertEqual(
            try InstallerCommand.parse(["--rotate-reviewed", "--approval", approval, "--source", "/Applications/Watt.app"]),
            .reviewed(source: URL(fileURLWithPath: "/Applications/Watt.app"), approval: approval, rotate: true)
        )
        XCTAssertThrowsError(try InstallerCommand.parse(["--rotate-reviewed", "--source", "/Applications/Watt.app", "--approval", approval.uppercased()]))
        XCTAssertThrowsError(try InstallerCommand.parse(["--bootstrap-reviewed", "--source", "/Applications/Watt.app", "--approval", String(repeating: "a", count: 63)]))
        XCTAssertEqual(
            try InstallerCommand.parse(["--provision-release-key", "--public-key", key, "--identity", "io.github.ben-ranford.watt", "--installation", id]),
            .provision(installation: try XCTUnwrap(UUID(uuidString: id)), identity: "io.github.ben-ranford.watt", key: Data(repeating: 7, count: 32))
        )
        XCTAssertThrowsError(try InstallerCommand.parse(["--provision-release-key", "--installation", id, "--identity", "io.github.ben-ranford.watt", "--public-key", Data(repeating: 7, count: 31).base64EncodedString()]))
        XCTAssertEqual(
            try InstallerCommand.parse(["--discard-release-stage", "--installation", id]),
            .discard(installation: try XCTUnwrap(UUID(uuidString: id)))
        )
        XCTAssertThrowsError(try InstallerCommand.parse(["--recover", "--installation", id, "--generation", "0"]))
        XCTAssertThrowsError(try InstallerCommand.parse(["--remove-helper", "--installation", id, "--generation", "1", "--request", "/request.json"]))
        XCTAssertThrowsError(try InstallerCommand.parse(["--rotate-release", "--manifest", "/manifest.json", "--archive", "/release.tar"]))
        XCTAssertThrowsError(try InstallerCommand.parse(["--preflight", "--source", "/Applications/Watt.app", "--extra", String(repeating: "x", count: 40_000)]))
    }

    func testActualUninstallExportKeepsHistoricalInstallationCoordinates() throws {
        let installation = UUID()
        let request = URL(fileURLWithPath: "/Users/example/Removal package/request.json")
        let arguments = ProductionRemovalComposition.administratorArguments(installationID: installation, generation: 4, request: request)
        XCTAssertEqual(try InstallerCommand.parse(arguments),
                       .remove(installation: installation, generation: 4, uninstall: true, request: request))
    }

}
