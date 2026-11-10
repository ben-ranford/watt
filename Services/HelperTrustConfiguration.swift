import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
#endif

/// Helper trust is independent of update endpoints and release verification keys.
enum HelperTrustConfiguration {
    case certificate(HelperSigningPolicy)
    case protectedInstallation(publicRecordURL: URL, expectedInstallationID: UUID)

    static func configured(bundle: Bundle = .main) throws -> Self {
        if bundle.object(forInfoDictionaryKey: "WATTHelperTrustMode") as? String == "certificate" {
            return .certificate(try HelperSigningPolicy.configured(bundle: bundle))
        }
        let record = try ProtectedHelperRecord.read()
        return .protectedInstallation(publicRecordURL: ProtectedHelperRecord.publicURL, expectedInstallationID: record.installationID)
    }

    func policy() throws -> HelperTrustPolicy {
        switch self {
        case .certificate(let policy): return .certificate(policy)
        case .protectedInstallation(let url, let identifier):
            guard url == ProtectedHelperRecord.publicURL else { throw ServiceFailure.untrustedIdentity }
            return .protectedInstallation(try ProtectedHelperRecord.read(at: url, expectedInstallationID: identifier))
        }
    }
}
