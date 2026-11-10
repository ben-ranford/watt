import Darwin
import Foundation
#if SWIFT_PACKAGE
import WattMaintenanceShared
#endif

do {
    if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--validate-archive" {
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        let directory = try BoundedUSTAR.openDirectory(url.deletingLastPathComponent())
        defer { close(directory) }
        let fd = openat(directory, url.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { close(fd) }
        var status = stat()
        guard fstat(fd, &status) == 0, status.st_mode & S_IFMT == S_IFREG,
              status.st_size >= 0, status.st_size <= BoundedUSTAR.maximumBytes else { throw MaintenanceProtocolError.oversized }
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0, count <= BoundedUSTAR.maximumBytes - bytes.count else { throw MaintenanceProtocolError.oversized }
            if count == 0 { break }; bytes.append(contentsOf: buffer.prefix(count))
        }
        guard bytes.count == status.st_size else { throw MaintenanceProtocolError.invalidRequest }
        _ = try BoundedUSTAR(validating: bytes)
        print("Archive validated")
        exit(0)
    }
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--recover-uninstall",
       let installation = UUID(uuidString: CommandLine.arguments[2]),
       let receiptID = UUID(uuidString: CommandLine.arguments[3]), geteuid() != 0 {
        let directory = try MaintenanceRemovalSession.directory(installationID: installation)
        let record = try MaintenanceRemovalSession.read(directory: directory)
        guard record.request.installationID == installation, record.request.receipt.id == receiptID else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let observer = try MaintenanceProcessWitness.observeLive(pid: getpid())
        let recovered = try MaintenanceRemovalSession.recover(directory: directory,
            receipt: record.request.receipt, observer: observer)
        print("Recovery phase: \(recovered.phase.rawValue)")
        exit(0)
    }
    guard CommandLine.arguments.count == 1, geteuid() != 0 else { throw MaintenanceProtocolError.invalidRequest }
    let parent = try MaintenanceProcessWitness.observe(pid: getppid())
    let request = try MaintenanceRequest.decode(MaintenanceChannel.read(from: STDIN_FILENO))
    guard request.parent == parent, parent.uid == getuid(),
          try MaintenanceProcessWitness.matches(parent) else { throw MaintenanceProtocolError.invalidRequest }
    if request.operation == .update {
        let envelope = try ProtectedUpdateEnvelope.decode(MaintenanceChannel.read(from: STDIN_FILENO))
        guard envelope.request == request else { throw MaintenanceProtocolError.invalidRequest }
        try ProtectedUpdateSession.validateLive(envelope)
        try MaintenanceChannel.write(JSONEncoder().encode(request), to: STDOUT_FILENO)
        guard try MaintenanceChannel.read(from: STDIN_FILENO) == Data("release".utf8) else { throw MaintenanceProtocolError.invalidRequest }
        let session = try ProtectedUpdateSession(envelope: envelope)
        try MaintenanceChannel.write(Data("accepted".utf8), to: STDOUT_FILENO)
        try await session.finish(timeout: 300)
    } else if request.operation == .uninstall, request.removalPlanSHA256 != nil {
        let plan = try JSONDecoder().decode(MaintenanceRemovalPlan.self, from: MaintenanceChannel.read(from: STDIN_FILENO))
        try plan.validateLiveParent(request)
        try MaintenanceChannel.write(JSONEncoder().encode(request), to: STDOUT_FILENO)
        guard try MaintenanceChannel.read(from: STDIN_FILENO) == Data("release".utf8) else { throw MaintenanceProtocolError.invalidRequest }
        let directory = try MaintenanceRemovalSession.directory(installationID: request.installationID)
        let session = try MaintenanceRemovalSession(directory: directory, request: request, plan: plan)
        // This acknowledgement follows exclusive writer acquisition and fsync of accepted ownership.
        try MaintenanceChannel.write(Data("accepted".utf8), to: STDOUT_FILENO)
        try await session.finish()
    } else {
        // Diagnostic mutual identity preflight has no filesystem or parent-exit effects.
        try MaintenanceChannel.write(JSONEncoder().encode(request), to: STDOUT_FILENO)
    }
    exit(0)
} catch {
    exit(1)
}
