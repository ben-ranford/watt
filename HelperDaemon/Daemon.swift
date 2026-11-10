import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
import WattHelperRuntime
#endif

private final class ReplySender: @unchecked Sendable {
    let send: (Data) -> Void
    init(_ send: @escaping (Data) -> Void) { self.send = send }
}

private final class Session: NSObject, WattHelperXPC, @unchecked Sendable {
    private let coordinator: HelperSamplerCoordinator
    private let instance: UUID
    private let lock = NSLock()
    private var pending = 0
    init(coordinator: HelperSamplerCoordinator, instance: UUID) {
        self.coordinator = coordinator
        self.instance = instance
    }

    func exchange(_ data: Data, withReply reply: @escaping (Data) -> Void) {
        guard let request = try? HelperWire.decodeRequest(data) else { reply(Data()); return }
        let admitted = lock.withLock {
            guard pending < 4 else { return false }
            pending += 1
            return true
        }
        guard admitted else { reply(Data()); return }
        let sender = ReplySender(reply)
        Task {
            defer { lock.withLock { pending -= 1 } }
            var capture: HelperCapture?
            let status: HelperReplyStatus
            switch request.command {
            case .ping: status = .ready
            case .prepareUpdate:
                await coordinator.stop()
                status = .preparingUpdate
            case .sample:
                // Never decode or present guessed schema. Source capture must establish it first.
                status = .sourceUnvalidated
            case .diagnosticCapture:
                capture = await coordinator.capture()
                status = capture == nil ? .busy : .sourceUnvalidated
            }
            let response = HelperReply(request: request, build: HelperIdentity.build, daemonInstance: instance,
                                       status: status, capture: capture)
            sender.send((try? HelperWire.encode(response)) ?? Data())
        }
    }
}

private final class ListenerDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    let coordinator = HelperSamplerCoordinator()
    let instance = UUID()
    let policy: HelperTrustPolicy
    private let lock = NSLock()
    private var connections: [UUID: NSXPCConnection] = [:]
    init(policy: HelperTrustPolicy) { self.policy = policy }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let id = UUID()
        let admitted = lock.withLock {
            guard connections.count < 8 else { return false }
            connections[id] = connection
            return true
        }
        guard admitted else { return false }
        guard let requirement = try? policy.appRequirement else { remove(id); return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: WattHelperXPC.self)
        connection.exportedObject = Session(coordinator: coordinator, instance: instance)
        connection.invalidationHandler = { [weak self] in self?.remove(id) }
        connection.interruptionHandler = { [weak connection] in connection?.invalidate() }
        connection.resume()
        return true
    }

    private func remove(_ id: UUID) { _ = lock.withLock { connections.removeValue(forKey: id) } }
}

@main
struct WattHelperMain {
    static func main() {
        do {
            let policy = try HelperTrustPolicy.configuredHelperProcess()
            let delegate = ListenerDelegate(policy: policy)
            let listener = NSXPCListener(machServiceName: HelperIdentity.machService)
            listener.setConnectionCodeSigningRequirement(try policy.appRequirement)
            listener.delegate = delegate
            listener.resume()
            withExtendedLifetime(delegate) { RunLoop.current.run() }
        } catch {
            // An absent or invalid protected record never permits a privileged listener.
            fputs("WattHelper: validated trust configuration required\n", stderr)
            exit(78)
        }
    }
}
