import Foundation
import Security
import Darwin

public enum ProtectedTrustError: Error { case unsafePath, invalidRecord, invalidCode, administratorRequired }

public struct ProtectedHelperRecord: Codable, Equatable, Sendable {
    public let installationID: UUID
    public let generation: UInt64
    public let build: UInt64
    public let appHashes: [Data]
    public let helperHashes: [Data]
    public let maintenanceHashes: [Data]
    public let maintenanceBinding: ProtectedMaintenanceBinding?

    public init(installationID: UUID, generation: UInt64, build: UInt64,
                appHashes: [Data], helperHashes: [Data], maintenanceHashes: [Data], maintenanceBinding: ProtectedMaintenanceBinding? = nil) throws {
        self.installationID = installationID; self.generation = generation; self.build = build
        self.appHashes = appHashes; self.helperHashes = helperHashes; self.maintenanceHashes = maintenanceHashes
        self.maintenanceBinding = maintenanceBinding
        try validate()
    }

    public func validate() throws {
        guard generation > 0, build > 0 else { throw ProtectedTrustError.invalidRecord }
        if let binding = maintenanceBinding {
            try binding.validate()
            guard binding.operation == .update, binding.installationID == installationID,
                  binding.nextGeneration == generation, binding.build == build,
                  Set(binding.replacementAppHashes) == Set(appHashes),
                  Set(binding.replacementHelperHashes) == Set(helperHashes),
                  Set(binding.replacementMaintenanceHashes) == Set(maintenanceHashes) else { throw ProtectedTrustError.invalidRecord }
        }
        for hashes in [appHashes, helperHashes, maintenanceHashes] {
            guard !hashes.isEmpty, hashes.count <= 16, Set(hashes).count == hashes.count,
                  hashes.allSatisfy({ $0.count == 20 }) else { throw ProtectedTrustError.invalidRecord }
        }
    }

    public var applicationURL: URL {
        Self.directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent("\(installationID.uuidString)-\(generation)", isDirectory: true)
            .appendingPathComponent("Watt.app", isDirectory: true)
    }

    public static let directory = URL(fileURLWithPath: "/Library/Application Support/Watt", isDirectory: true)
    public static let publicURL = directory.appendingPathComponent("helper-trust.json")
    public static let maintenanceResultURL = ProtectedMaintenanceBinding.resultURL
    public static func generationRecordURL(installationID: UUID, generation: UInt64) -> URL {
        directory.appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent("\(installationID.uuidString)-\(generation)", isDirectory: true)
            .appendingPathComponent("record.json")
    }

    /// Historical pins are root-established generation records, never helper claims.
    public static func readGenerationRecord(installationID: UUID, generation: UInt64) throws -> Self {
        guard generation > 0 else { throw ProtectedTrustError.invalidRecord }
        let record = try read(at: generationRecordURL(installationID: installationID, generation: generation),
                              expectedInstallationID: installationID)
        guard record.generation == generation else { throw ProtectedTrustError.invalidRecord }
        return record
    }

    public static let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/" + HelperIdentity.helperIdentifier)
    public static let plistURL = URL(fileURLWithPath: "/Library/LaunchDaemons/" + HelperIdentity.daemonPlist)

    /// Descriptor traversal rejects symlinks and writable ancestors, including the file itself.
    public static func read(at url: URL = publicURL, expectedInstallationID: UUID? = nil, requiredOwner: uid_t = 0) throws -> Self {
        let bytes = try readProtectedFile(at: url, requiredOwner: requiredOwner)
        let record = try JSONDecoder().decode(Self.self, from: bytes)
        try record.validate()
        guard expectedInstallationID == nil || expectedInstallationID == record.installationID else {
            throw ProtectedTrustError.invalidRecord
        }
        return record
    }

    public static func openProtectedFile(at url: URL, requiredOwner: uid_t = 0) throws -> Int32 {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.pathComponents.contains("..") else {
            throw ProtectedTrustError.unsafePath
        }
        var descriptor = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw ProtectedTrustError.unsafePath }
        var transferred = false
        defer { if !transferred { close(descriptor) } }
        let components = url.pathComponents.dropFirst()
        for (index, component) in components.enumerated() {
            let final = index == components.count - 1
            let next = openat(descriptor, component, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | (final ? 0 : O_DIRECTORY))
            guard next >= 0 else { throw ProtectedTrustError.unsafePath }
            close(descriptor); descriptor = next
            var info = stat()
            guard fstat(descriptor, &info) == 0, (info.st_uid == requiredOwner || (!final && info.st_uid == 0)), info.st_mode & 0o022 == 0,
                  final ? (info.st_mode & S_IFMT == S_IFREG && info.st_nlink == 1) : info.st_mode & S_IFMT == S_IFDIR else {
                throw ProtectedTrustError.unsafePath
            }
        }
        transferred = true
        return descriptor
    }

    public static func readProtectedFile(at url: URL, requiredOwner: uid_t = 0) throws -> Data {
        let descriptor = try openProtectedFile(at: url, requiredOwner: requiredOwner)
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_size > 0, info.st_size <= 65536 else {
            throw ProtectedTrustError.invalidRecord
        }
        var data = Data(count: Int(info.st_size))
        let count = data.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, $0.count) }
        guard count == data.count else { throw ProtectedTrustError.invalidRecord }
        return data
    }
}

public enum ExactCodeIdentity {
    public static func requirement(hashes: [Data], identifier: String) throws -> String {
        guard !hashes.isEmpty, hashes.count <= 16, hashes.allSatisfy({ $0.count == 20 }),
              [HelperIdentity.appIdentifier, HelperIdentity.helperIdentifier, HelperIdentity.appIdentifier + ".maintenance"].contains(identifier) else {
            throw ProtectedTrustError.invalidCode
        }
        return "identifier \"\(identifier)\" and (" + hashes.map { "cdhash H\"" + $0.map { String(format: "%02x", $0) }.joined() + "\"" }.joined(separator: " or ") + ")"
    }

    public static func verify(at url: URL, requirement text: String) throws -> Data {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess else {
            throw ProtectedTrustError.invalidCode
        }
        return try hash(of: code)
    }

    /// Derive every slice identity from the same staged file. Unknown/malformed formats fail closed.
    public static func allHashes(at url: URL, identifier: String) throws -> [Data] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 12, data.count <= 256 * 1024 * 1024 else { throw ProtectedTrustError.invalidCode }
        func word(_ offset: Int, little: Bool = false) throws -> UInt32 {
            guard offset >= 0, offset <= data.count - 4 else { throw ProtectedTrustError.invalidCode }
            let bytes = Array(data[offset..<offset + 4])
            let ordered = little ? Array(bytes.reversed()) : bytes
            return ordered.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
        let magic = try word(0)
        var architectures: [(UInt32, UInt32)] = []
        if magic == 0xcafebabe || magic == 0xcafebabf {
            let count = try word(4)
            guard count > 0, count <= 16 else { throw ProtectedTrustError.invalidCode }
            let stride = magic == 0xcafebabe ? 20 : 32
            guard 8 + Int(count) * stride <= data.count else { throw ProtectedTrustError.invalidCode }
            for index in 0..<Int(count) {
                architectures.append((try word(8 + index * stride), try word(12 + index * stride)))
            }
        } else if [UInt32(0xfeedface), 0xfeedfacf, 0xcefaedfe, 0xcffaedfe].contains(magic) {
            let little = magic == 0xcefaedfe || magic == 0xcffaedfe
            architectures.append((try word(4, little: little), try word(8, little: little)))
        } else { throw ProtectedTrustError.invalidCode }
        var hashes: [Data] = []
        for (architecture, subtype) in architectures {
            var code: SecStaticCode?
            let attributes = [kSecCodeAttributeArchitecture as String: NSNumber(value: architecture),
                              kSecCodeAttributeSubarchitecture as String: NSNumber(value: subtype)]
            guard SecStaticCodeCreateWithPathAndAttributes(url as CFURL, [], attributes as CFDictionary, &code) == errSecSuccess,
                  let code, SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
                throw ProtectedTrustError.invalidCode
            }
            hashes.append(try hash(of: code))
        }
        let unique = Array(Set(hashes)).sorted { $0.lexicographicallyPrecedes($1) }
        _ = try verify(at: url, requirement: requirement(hashes: unique, identifier: identifier))
        return unique
    }

    public static func hash(of code: SecStaticCode) throws -> Data {
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any], let hash = fields[kSecCodeInfoUnique as String] as? Data,
              hash.count == 20 else { throw ProtectedTrustError.invalidCode }
        return hash
    }
}

/// Release builds use `protected-installation`. Certificate mode is the separate
/// Apple Development configuration. An unknown value fails closed.
public enum HelperTrustMode: Equatable, Sendable {
    case protectedInstallation
    case certificate

    public init?(plistValue: String?) {
        switch plistValue {
        case nil, "protected-installation": self = .protectedInstallation
        case "certificate": self = .certificate
        default: return nil
        }
    }
}

public enum QuarantineAttribute {
    public static let name = "com.apple.quarantine"

    /// Remove Gatekeeper's quarantine attribute from a verified bundle.
    /// Symlinks are rejected. Other extended attributes are left in place.
    /// Clearing this attribute does not change a cdhash.
    public static func clear(at root: URL) throws {
        guard root.isFileURL, root.path.hasPrefix("/") else { throw ProtectedTrustError.unsafePath }
        var remaining = 10_000
        try clearNode(root, remaining: &remaining)
    }

    private static func clearNode(_ url: URL, remaining: inout Int) throws {
        remaining -= 1
        guard remaining >= 0 else { throw ProtectedTrustError.unsafePath }
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw ProtectedTrustError.unsafePath }
        let kind = info.st_mode & S_IFMT
        guard kind == S_IFREG || kind == S_IFDIR else { throw ProtectedTrustError.unsafePath }
        if removexattr(url.path, name, XATTR_NOFOLLOW) != 0, errno != ENOATTR {
            throw ProtectedTrustError.unsafePath
        }
        guard kind == S_IFDIR else { return }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            throw ProtectedTrustError.unsafePath
        }
        for child in names where child != "." && child != ".." {
            try clearNode(url.appendingPathComponent(child), remaining: &remaining)
        }
    }
}

public enum HelperTrustPolicy: Sendable {
    case certificate(HelperSigningPolicy)
    case protectedInstallation(ProtectedHelperRecord)

    public var appRequirement: String { get throws {
        switch self {
        case .certificate(let policy): return policy.appRequirement
        case .protectedInstallation(let record): return try ExactCodeIdentity.requirement(hashes: record.appHashes, identifier: HelperIdentity.appIdentifier)
        }
    } }
    public var helperRequirement: String { get throws {
        switch self {
        case .certificate(let policy): return policy.helperRequirement
        case .protectedInstallation(let record): return try ExactCodeIdentity.requirement(hashes: record.helperHashes, identifier: HelperIdentity.helperIdentifier)
        }
    } }
    public func verifyExecutable(at url: URL, helper: Bool) throws -> Data? {
        switch self {
        case .certificate(let policy): try policy.verifyExecutable(at: url, helper: helper); return nil
        case .protectedInstallation: return try ExactCodeIdentity.verify(at: url, requirement: helper ? helperRequirement : appRequirement)
        }
    }
    /// Release helpers pin the root-owned cdhash record. A missing record does not
    /// fall back to a team requirement or to any caller with the same identifier.
    public static func configuredHelperProcess() throws -> Self {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { throw ProtectedTrustError.invalidCode }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { throw ProtectedTrustError.invalidCode }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any],
              let plist = fields[kSecCodeInfoPList as String] as? [String: Any],
              let mode = HelperTrustMode(plistValue: plist["WATTHelperTrustMode"] as? String) else {
            throw ProtectedTrustError.invalidCode
        }
        switch mode {
        case .certificate:
            return .certificate(try HelperSigningPolicy.configuredHelperProcess())
        case .protectedInstallation:
            let record = try ProtectedHelperRecord.read()
            var requirement: SecRequirement?
            let policy = Self.protectedInstallation(record)
            guard SecRequirementCreateWithString(try policy.helperRequirement as CFString, [], &requirement) == errSecSuccess,
                  let requirement, SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
                throw ProtectedTrustError.invalidCode
            }
            return policy
        }
    }
}

/// Matches the complete app receipt without introducing a dependency on the maintenance module.
public struct ProtectedMaintenanceReceipt: Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public init(id: UUID, createdAt: Date) { self.id = id; self.createdAt = createdAt }
}
public enum ProtectedMaintenanceOperation: String, Codable, Sendable { case update, uninstall }

/// An administrator-confirmed binding is necessary, but inventory/process observations
/// remain necessary before any consumer reports transaction completion.
public struct ProtectedMaintenanceBinding: Codable, Equatable, Sendable {
    public let receipt: ProtectedMaintenanceReceipt
    public let installationID: UUID
    public let previousGeneration: UInt64
    public let nextGeneration: UInt64
    public let operation: ProtectedMaintenanceOperation
    public let signedPayloadSHA256: Data?
    public let archiveSHA256: Data?
    public let build: UInt64
    public let replacementAppHashes: [Data]
    public let replacementHelperHashes: [Data]
    public let replacementMaintenanceHashes: [Data]
    public let removalPlanSHA256: Data?
    public static let resultURL = URL(fileURLWithPath: "/Library/Application Support/Watt-maintenance-result.json")

    public init(receipt: ProtectedMaintenanceReceipt, installationID: UUID,
                previousGeneration: UInt64, nextGeneration: UInt64, operation: ProtectedMaintenanceOperation,
                signedPayloadSHA256: Data? = nil, archiveSHA256: Data? = nil, build: UInt64,
                replacementAppHashes: [Data] = [], replacementHelperHashes: [Data] = [],
                replacementMaintenanceHashes: [Data] = [], removalPlanSHA256: Data? = nil) throws {
        self.receipt = receipt; self.installationID = installationID
        self.previousGeneration = previousGeneration; self.nextGeneration = nextGeneration; self.operation = operation
        self.signedPayloadSHA256 = signedPayloadSHA256; self.archiveSHA256 = archiveSHA256; self.build = build
        self.replacementAppHashes = replacementAppHashes; self.replacementHelperHashes = replacementHelperHashes
        self.replacementMaintenanceHashes = replacementMaintenanceHashes; self.removalPlanSHA256 = removalPlanSHA256
        try validate()
    }
    public func validate() throws {
        guard receipt.createdAt.timeIntervalSince1970.isFinite, previousGeneration > 0, build > 0 else { throw ProtectedTrustError.invalidRecord }
        switch operation {
        case .update:
            guard previousGeneration < UInt64.max, nextGeneration == previousGeneration + 1,
                  signedPayloadSHA256?.count == 32, archiveSHA256?.count == 32, removalPlanSHA256 == nil else { throw ProtectedTrustError.invalidRecord }
            for hashes in [replacementAppHashes, replacementHelperHashes, replacementMaintenanceHashes] {
                guard !hashes.isEmpty, hashes.count <= 16, Set(hashes).count == hashes.count,
                      hashes.allSatisfy({ $0.count == 20 }) else { throw ProtectedTrustError.invalidRecord }
            }
        case .uninstall:
            guard nextGeneration == previousGeneration, signedPayloadSHA256 == nil, archiveSHA256 == nil,
                  replacementAppHashes.isEmpty, replacementHelperHashes.isEmpty, replacementMaintenanceHashes.isEmpty,
                  removalPlanSHA256?.count == 32 else { throw ProtectedTrustError.invalidRecord }
        }
    }
    public static func decode(_ bytes: Data) throws -> Self {
        guard bytes.count <= 16384 else { throw ProtectedTrustError.invalidRecord }
        let result = try JSONDecoder().decode(Self.self, from: bytes)
        try result.validate(); return result
    }
    public static func readResult() throws -> Self {
        let binding = try decode(ProtectedHelperRecord.readProtectedFile(at: resultURL))
        guard binding.operation == .uninstall else { throw ProtectedTrustError.invalidRecord }
        return binding
    }
}
