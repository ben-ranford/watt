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
            let reply = try await transport.request(.init(command: .sample, generation: UUID()))
            guard !Task.isCancelled else { return .failure(.cancelled) }
            return PowerMetricsComponentDecoder.estimate(from: reply)
        } catch { return .failure(.disconnected) }
    }
}
