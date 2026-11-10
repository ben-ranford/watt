import Foundation
#if SWIFT_PACKAGE
import WattHelperShared
#endif

@MainActor
protocol ComponentHelperTransport {
    func connect() async throws -> HelperPeer
    func request(_ request: HelperRequest) async throws -> HelperReply
}

extension ProductionHelperIPC: ComponentHelperTransport {}

/// Connection health is independent of source validation. Raw capture is never a reading.
@MainActor
final class ProductionHelperTelemetry: ComponentTelemetryService {
    private let transport: any ComponentHelperTransport
    init(transport: any ComponentHelperTransport) { self.transport = transport }

    func sampleComponents() async -> ServiceOutcome<ComponentEstimatePair> {
        do {
            _ = try await transport.connect()
            guard !Task.isCancelled else { return .failure(.cancelled) }
            _ = try await transport.request(.init(command: .sample, generation: UUID()))
            // G005 must establish the host schema and units from an authenticated capture
            // before a decoder may turn the daemon reply into an estimate pair.
            return .failure(.unknownStatus)
        } catch { return .failure(.disconnected) }
    }
}
