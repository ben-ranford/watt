import Foundation

public struct MaintenanceReceipt: Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public init(id: UUID = UUID(), createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
    }
    public var isValid: Bool { createdAt.timeIntervalSince1970.isFinite }
}

public enum MaintenanceOperation: String, Codable, Sendable {
    case update, removeHelper, uninstall
}

/// Descriptive until compared with an independently observed OS process identity.
public struct MaintenanceProcessIdentity: Codable, Equatable, Sendable {
    public let pid: Int32
    public let uid: UInt32
    public let startedAtMicroseconds: UInt64
    public let codeDirectoryHash: Data
    public init(pid: Int32, uid: UInt32, startedAtMicroseconds: UInt64, codeDirectoryHash: Data) {
        self.pid = pid
        self.uid = uid
        self.startedAtMicroseconds = startedAtMicroseconds
        self.codeDirectoryHash = codeDirectoryHash
    }
    public var isValid: Bool { pid > 0 && startedAtMicroseconds > 0 && codeDirectoryHash.count == 20 }
}

public enum MaintenanceProtocolError: Error {
    case invalidRequest, oversized
}

/// No executable, shell command, or privileged destination comes from the UI.
public struct MaintenanceRequest: Codable, Equatable, Sendable {
    public let receipt: MaintenanceReceipt
    public let installationID: UUID
    public let generation: UInt64
    public let operation: MaintenanceOperation
    public let parent: MaintenanceProcessIdentity
    public let candidateSHA256: Data?
    public let removalPlanSHA256: Data?

    public init(receipt: MaintenanceReceipt, installationID: UUID, generation: UInt64,
                operation: MaintenanceOperation, parent: MaintenanceProcessIdentity,
                candidateSHA256: Data? = nil, removalPlanSHA256: Data? = nil) throws {
        self.receipt = receipt
        self.installationID = installationID
        self.generation = generation
        self.operation = operation
        self.parent = parent
        self.candidateSHA256 = candidateSHA256
        self.removalPlanSHA256 = removalPlanSHA256
        try validate()
    }

    public func validate() throws {
        guard receipt.isValid, generation > 0, parent.isValid,
              removalPlanSHA256 == nil || (operation == .uninstall && removalPlanSHA256?.count == 32),
              operation == .update ? candidateSHA256?.count == 32 : candidateSHA256 == nil else {
            throw MaintenanceProtocolError.invalidRequest
        }
    }

    public static func decode(_ bytes: Data) throws -> Self {
        guard bytes.count <= 8 * 1024 else { throw MaintenanceProtocolError.oversized }
        let value = try JSONDecoder().decode(Self.self, from: bytes)
        try value.validate()
        return value
    }
}

/// Receipts and files alone do not establish completion. The consumer must verify
/// actual inventory and the authenticated process witness before accepting evidence.
public enum MaintenanceProgress: Equatable, Sendable {
    case adminRequired(MaintenanceReceipt)
    case handoffAccepted(MaintenanceReceipt)
    case interrupted(MaintenanceReceipt, String)
    case completed(MaintenanceReceipt)
}
