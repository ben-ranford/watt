import Foundation
import Darwin
#if SWIFT_PACKAGE
import WattHelperShared
#endif

@MainActor
final class ProductionHelperIPC: HelperIPCTransport {
    enum Failure: Error { case disconnected, timedOut, invalidReply, busy }
    private let policy: HelperTrustPolicy
    private var verifiedIdentity: HelperPeerIdentity?
    private var connection: NSXPCConnection?
    private var connectionGeneration = UUID()
    private var pending: [UUID: CheckedContinuation<HelperReply, Error>] = [:]
    private var deadlines: [UUID: Task<Void, Never>] = [:]
    private(set) var daemonInstance: UUID?
    private(set) var daemonBuild: String?
    /// Clears component observations immediately when the current authenticated session ends.
    var onInvalidated: (@MainActor () -> Void)?

    init(policy: HelperSigningPolicy) { self.policy = .certificate(policy) }
    init(trust: HelperTrustPolicy) { self.policy = trust }

    func connect() async throws -> HelperPeer {
        if connection == nil {
            guard let executable = Bundle.main.executableURL else { throw Failure.disconnected }
            _ = try policy.verifyExecutable(at: executable, helper: false)
            let requirement: String
            switch policy {
            case .certificate(let signing):
                verifiedIdentity = .appleTeam(signing.team)
                requirement = signing.helperRequirement
            case .protectedInstallation(let record):
                let protectedFile = try ProtectedHelperRecord.openProtectedFile(at: ProtectedHelperRecord.helperURL)
                close(protectedFile)
                guard try ProtectedHelperRecord.read(expectedInstallationID: record.installationID) == record,
                      let hash = try policy.verifyExecutable(at: ProtectedHelperRecord.helperURL, helper: true) else {
                    throw ServiceFailure.untrustedIdentity
                }
                verifiedIdentity = .protectedCodeHash(installationID: record.installationID, generation: record.generation, cdhash: hash)
                requirement = try ExactCodeIdentity.requirement(hashes: [hash], identifier: HelperIdentity.helperIdentifier)
            }
            let connection = NSXPCConnection(machServiceName: HelperIdentity.machService, options: .privileged)
            connection.setCodeSigningRequirement(requirement)
            connection.remoteObjectInterface = NSXPCInterface(with: WattHelperXPC.self)
            let generation = UUID()
            connectionGeneration = generation
            connection.invalidationHandler = { [weak self] in Task { @MainActor in self?.invalidate(generation: generation) } }
            connection.interruptionHandler = { [weak self] in Task { @MainActor in self?.invalidate(generation: generation) } }
            self.connection = connection
            connection.resume()
        }
        let reply = try await request(.init(command: .ping, generation: UUID()))
        guard reply.status == .ready else { invalidate(); throw Failure.invalidReply }
        daemonInstance = reply.daemonInstance
        daemonBuild = reply.build
        guard let verifiedIdentity else { throw ServiceFailure.untrustedIdentity }
        return HelperPeer(identifier: HelperIdentity.helperIdentifier, identity: verifiedIdentity, protocolVersion: reply.version)
    }

    func send(_ message: HelperMessage) async throws -> HelperMessage {
        let command: HelperCommand = message.command == .ping ? .ping : .prepareUpdate
        let reply = try await request(.init(command: command, id: message.requestID,
                                            generation: message.generation, receipt: message.receiptID))
        guard reply.status == (command == .ping ? .ready : .preparingUpdate) else { throw Failure.invalidReply }
        return message
    }

    func request(_ request: HelperRequest) async throws -> HelperReply {
        guard let connection else { throw Failure.disconnected }
        let generation = connectionGeneration
        guard pending.count < 8, pending[request.id] == nil else { throw Failure.busy }
        let data = try HelperWire.encode(request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending[request.id] = continuation
                deadlines[request.id] = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(request.command == .diagnosticCapture || request.command == .sample ? 5 : 3)) }
                    catch { return }
                    self?.finish(request.id, result: .failure(Failure.timedOut))
                    self?.invalidate()
                }
                guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] _ in
                    Task { @MainActor in self?.finish(request.id, result: .failure(Failure.disconnected)) }
                }) as? WattHelperXPC else {
                    finish(request.id, result: .failure(Failure.disconnected))
                    return
                }
                proxy.exchange(data) { [weak self] response in
                    Task { @MainActor in
                        guard let self, self.pending[request.id] != nil else { return }
                        do {
                            let reply = try HelperWire.decodeReply(response, for: request)
                            if let instance = self.daemonInstance, instance != reply.daemonInstance { throw Failure.invalidReply }
                            self.finish(request.id, result: .success(reply))
                        } catch {
                            self.finish(request.id, result: .failure(error))
                            self.invalidate()
                        }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.invalidate(generation: generation) }
        }
    }

    func invalidate() {
        let old = connection
        connection = nil
        connectionGeneration = UUID()
        old?.invalidationHandler = nil
        old?.interruptionHandler = nil
        old?.invalidate()
        daemonInstance = nil
        daemonBuild = nil
        verifiedIdentity = nil
        for task in deadlines.values { task.cancel() }
        deadlines.removeAll()
        let continuations = pending.values
        pending.removeAll()
        for continuation in continuations { continuation.resume(throwing: Failure.disconnected) }
        if old != nil { onInvalidated?() }
    }

    private func finish(_ id: UUID, result: Result<HelperReply, Error>) {
        deadlines.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(with: result)
    }

    private func invalidate(generation: UUID) {
        guard generation == connectionGeneration else { return }
        invalidate()
    }
}
