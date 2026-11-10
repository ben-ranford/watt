import CryptoKit
import Foundation

/// Explicit release trust is separate from local helper installation trust.
struct UpdateConfiguration {
    let manifestURL: URL
    let artifactURL: URL
    let trust: UpdateTrust

    init(info: [String: Any], hostSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) throws {
        func value(_ key: String) throws -> String {
            guard let text = info[key] as? String, !text.isEmpty,
                  text == text.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.contains("$("), !text.contains("${") else { throw ServiceFailure.invalidData }
            return text
        }
        func endpoint(_ key: String) throws -> URL {
            guard let url = URL(string: try value(key)), url.scheme == "https",
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                  url.fragment == nil, url.query == nil,
                  url.port == nil || url.port == 443 else { throw ServiceFailure.invalidData }
            return url
        }
        manifestURL = try endpoint("WATTUpdateManifestURL")
        artifactURL = try endpoint("WATTUpdateArtifactURL")
        let identity = try value("CFBundleIdentifier")
        guard identity.utf8.count <= 255, identity.contains("."),
              identity.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || $0 == 46 || $0 == 45 }) else { throw ServiceFailure.invalidData }
        let buildText = try value("CFBundleVersion")
        guard buildText.utf8.allSatisfy({ (48...57).contains($0) }),
              buildText.first != "0", let build = UInt64(buildText), build > 0,
              let key = Data(base64Encoded: try value("WATTUpdatePublicKey")), key.count == 32 else { throw ServiceFailure.invalidData }
        let publicKey: Curve25519.Signing.PublicKey
        do { publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key) }
        catch { throw ServiceFailure.invalidData }
        trust = UpdateTrust(identity: identity, currentBuild: build, hostSystemVersion: hostSystemVersion, publicKey: publicKey)
        try trust.requireCompatible(UpdateManifest(identity: identity, build: build, sha256: Data(repeating: 0, count: 32),
                                                  minimumSystemVersion: try value("LSMinimumSystemVersion")))
    }

    static func configured(bundle: Bundle = .main) throws -> Self {
        try Self(info: bundle.infoDictionary ?? [:])
    }
}
