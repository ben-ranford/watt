import Foundation
import Security

@objc public protocol WattHelperXPC {
    func exchange(_ request: Data, withReply reply: @escaping (Data) -> Void)
}

public enum HelperIdentity {
    public static let appIdentifier = "io.github.ben-ranford.watt"
    public static let helperIdentifier = "io.github.ben-ranford.watt.helper"
    public static let machService = helperIdentifier
    public static let daemonPlist = helperIdentifier + ".plist"
    public static let executableName = "WattHelper"
    public static let build = "1"
}

public enum HelperSigningError: Error { case missingTeam, invalidRequirement, invalidSignature }

/// Team must come from the signed bundle's build configuration, never from an XPC payload.
public struct HelperSigningPolicy: Sendable {
    public let team: String
    public init(team: String) throws {
        guard team.utf8.count == 10, team.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) }) else {
            throw HelperSigningError.missingTeam
        }
        self.team = team
    }

    public var appRequirement: String { requirement(identifier: HelperIdentity.appIdentifier) }
    public var helperRequirement: String { requirement(identifier: HelperIdentity.helperIdentifier) }

    private func requirement(identifier: String) -> String {
        "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    }

    public func verifyExecutable(at url: URL, helper: Bool) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else {
            throw HelperSigningError.invalidSignature
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString((helper ? helperRequirement : appRequirement) as CFString, [], &requirement) == errSecSuccess,
              let requirement else { throw HelperSigningError.invalidRequirement }
        guard SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw HelperSigningError.invalidSignature
        }
    }

    public static func configured(bundle: Bundle = .main) throws -> HelperSigningPolicy {
        guard let team = bundle.object(forInfoDictionaryKey: "WATTSigningTeam") as? String else {
            throw HelperSigningError.missingTeam
        }
        return try .init(team: team)
    }

    /// A command-line helper can be inside an app bundle; read its own signed Mach-O metadata.
    public static func configuredHelperProcess() throws -> HelperSigningPolicy {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { throw HelperSigningError.invalidSignature }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { throw HelperSigningError.invalidSignature }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any],
              let plist = fields[kSecCodeInfoPList as String] as? [String: Any],
              let team = plist["WATTSigningTeam"] as? String else { throw HelperSigningError.missingTeam }
        let policy = try HelperSigningPolicy(team: team)
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(policy.helperRequirement as CFString, [], &requirement) == errSecSuccess,
              let requirement,
              SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw HelperSigningError.invalidSignature
        }
        return policy
    }
}
