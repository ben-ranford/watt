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
    func testActualUninstallExportKeepsHistoricalInstallationCoordinates() throws {
        let installation = UUID()
        let request = URL(fileURLWithPath: "/Users/example/Removal package/request.json")
        let arguments = ProductionRemovalComposition.administratorArguments(installationID: installation, generation: 4, request: request)
        XCTAssertEqual(try InstallerCommand.parse(arguments),
                       .remove(installation: installation, generation: 4, uninstall: true, request: request))
    }

}
