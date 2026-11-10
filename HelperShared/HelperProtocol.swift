import Foundation

public enum HelperLimits {
    public static let requestBytes = 8 * 1024
    public static let replyBytes = 64 * 1024
    public static let diagnosticReplyBytes = 2 * 1024 * 1024
    public static let captureBytes = 1024 * 1024
    public static let runtimeSeconds = 4.0
    public static let minimumStartInterval = 3.0
}

public enum HelperCommand: String, Codable, Sendable {
    case ping, sample, diagnosticCapture, prepareUpdate
}

public struct HelperRequest: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    public let id: UUID
    public let generation: UUID
    public let receipt: UUID?
    public let command: HelperCommand

    public init(command: HelperCommand, id: UUID = UUID(), generation: UUID, receipt: UUID? = nil) {
        self.version = Self.currentVersion
        self.id = id
        self.generation = generation
        self.receipt = receipt
        self.command = command
    }

    /// `prepareUpdate` stops the privileged sampler. The app always binds that
    /// command to an update receipt; a request without one is not admitted.
    public var isAdmitted: Bool {
        command != .prepareUpdate || receipt != nil
    }
}

public enum HelperCaptureStatus: String, Codable, Sendable {
    case completed, launchFailed, timedOut, cancelled, outputLimit, interrupted
}

/// Raw source evidence only. It does not assert a schema, units, or usable estimates.
public struct HelperCapture: Codable, Equatable, Sendable {
    public let acquisitionID: UUID
    public let startedAt: Date
    public let duration: TimeInterval
    public let stdout: Data
    public let stderr: Data
    public let exitStatus: Int32?
    public let status: HelperCaptureStatus
    public let terminationConfirmed: Bool

    public init(acquisitionID: UUID = UUID(), startedAt: Date, duration: TimeInterval,
                stdout: Data, stderr: Data, exitStatus: Int32?, status: HelperCaptureStatus,
                terminationConfirmed: Bool) {
        self.acquisitionID = acquisitionID
        self.startedAt = startedAt
        self.duration = duration
        self.stdout = stdout
        self.stderr = stderr
        self.exitStatus = exitStatus
        self.status = status
        self.terminationConfirmed = terminationConfirmed
    }
}

public enum HelperReplyStatus: String, Codable, Sendable {
    case ready, sourceUnvalidated, preparingUpdate, busy, unavailable
}

public struct HelperReply: Codable, Equatable, Sendable {
    public let version: Int
    public let requestID: UUID
    public let generation: UUID
    public let receipt: UUID?
    public let command: HelperCommand
    public let build: String
    public let daemonInstance: UUID
    public let status: HelperReplyStatus
    public let capture: HelperCapture?

    public init(request: HelperRequest, build: String, daemonInstance: UUID,
                status: HelperReplyStatus, capture: HelperCapture? = nil) {
        version = HelperRequest.currentVersion
        requestID = request.id
        generation = request.generation
        receipt = request.receipt
        command = request.command
        self.build = build
        self.daemonInstance = daemonInstance
        self.status = status
        self.capture = capture
    }
}

public enum HelperProtocolError: Error, Equatable {
    case oversized, invalidEnvelope, unsupportedVersion, uncorrelatedReply
}

public enum HelperWire {
    public static func encode(_ request: HelperRequest) throws -> Data {
        let data = try JSONEncoder().encode(request)
        _ = try decodeRequest(data)
        return data
    }

    public static func decodeRequest(_ data: Data) throws -> HelperRequest {
        try checkObject(data, limit: HelperLimits.requestBytes,
                        keys: ["version", "id", "generation", "receipt", "command"])
        let request = try JSONDecoder().decode(HelperRequest.self, from: data)
        guard request.version == HelperRequest.currentVersion else { throw HelperProtocolError.unsupportedVersion }
        return request
    }

    public static func encode(_ reply: HelperReply) throws -> Data {
        try validate(reply)
        let data = try JSONEncoder().encode(reply)
        guard data.count <= limit(for: reply.command) else { throw HelperProtocolError.oversized }
        return data
    }

    public static func decodeReply(_ data: Data, for request: HelperRequest) throws -> HelperReply {
        try checkObject(data, limit: limit(for: request.command), keys: [
            "version", "requestID", "generation", "receipt", "command", "build", "daemonInstance", "status", "capture"
        ])
        let reply = try JSONDecoder().decode(HelperReply.self, from: data)
        try validate(reply)
        guard reply.requestID == request.id, reply.generation == request.generation,
              reply.receipt == request.receipt, reply.command == request.command else {
            throw HelperProtocolError.uncorrelatedReply
        }
        return reply
    }

    private static func limit(for command: HelperCommand) -> Int {
        command == .diagnosticCapture ? HelperLimits.diagnosticReplyBytes : HelperLimits.replyBytes
    }

    private static func validate(_ reply: HelperReply) throws {
        guard reply.version == HelperRequest.currentVersion else { throw HelperProtocolError.unsupportedVersion }
        guard !reply.build.isEmpty, reply.build.utf8.count <= 128 else { throw HelperProtocolError.invalidEnvelope }
        if let capture = reply.capture {
            guard reply.command == .diagnosticCapture,
                  capture.stdout.count + capture.stderr.count <= HelperLimits.captureBytes,
                  capture.duration.isFinite, capture.duration >= 0,
                  capture.startedAt.timeIntervalSince1970.isFinite else { throw HelperProtocolError.invalidEnvelope }
        }
    }

    private static func checkObject(_ data: Data, limit: Int, keys: Set<String>) throws {
        guard data.count <= limit else { throw HelperProtocolError.oversized }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: keys) else { throw HelperProtocolError.invalidEnvelope }
        if let capture = object["capture"] as? [String: Any] {
            let allowed: Set<String> = ["acquisitionID", "startedAt", "duration", "stdout", "stderr", "exitStatus", "status", "terminationConfirmed"]
            guard Set(capture.keys).isSubset(of: allowed) else { throw HelperProtocolError.invalidEnvelope }
        }
    }
}
