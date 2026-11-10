import Foundation

public struct UpdateLaunchRequest: Codable, Equatable, Sendable {
    public let receipt: MaintenanceReceipt
    public let identity: String
    public let build: UInt64
    public let minimumSystemVersion: String
    public let challenge: Data

    public init(receipt: MaintenanceReceipt, identity: String, build: UInt64,
                minimumSystemVersion: String, challenge: Data) throws {
        self.receipt = receipt; self.identity = identity; self.build = build
        self.minimumSystemVersion = minimumSystemVersion; self.challenge = challenge
        try validate()
    }
    public func validate() throws {
        guard receipt.isValid, build > 0, challenge.count == 32,
              !identity.isEmpty, identity.utf8.count <= 255,
              identity.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                  || (97...122).contains($0) || $0 == 46 || $0 == 45 }),
              minimumSystemVersion.utf8.count <= 32 else { throw MaintenanceProtocolError.invalidRequest }
        let parts = minimumSystemVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count), parts.allSatisfy({ part in
            !part.isEmpty && part.utf8.allSatisfy({ (48...57).contains($0) })
                && (part.count == 1 || part.first != "0") && Int(part) != nil
        }), let major = Int(parts[0]), major > 0 else { throw MaintenanceProtocolError.invalidRequest }
    }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 8 * 1024 else { throw MaintenanceProtocolError.oversized }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.validate(); return value
    }
}

/// Echoing a request is only correlation evidence. The caller must independently
/// authenticate the actual running process and code identity through the OS.
public struct UpdateLaunchAcknowledgement: Codable, Equatable, Sendable {
    public let request: UpdateLaunchRequest
    public init(request: UpdateLaunchRequest) { self.request = request }
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 8 * 1024 else { throw MaintenanceProtocolError.oversized }
        let value = try JSONDecoder().decode(Self.self, from: data)
        try value.request.validate(); return value
    }
}
