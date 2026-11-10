import XCTest
#if SWIFT_PACKAGE
import WattHelperShared
#endif
@testable import Watt

@MainActor
final class ComponentTelemetryTests: XCTestCase {
    private final class Source: ComponentTelemetryService {
        var outcome: ServiceOutcome<ComponentEstimatePair> = .failure(.unknownStatus)
        func sampleComponents() async -> ServiceOutcome<ComponentEstimatePair> { outcome }
    }
    private final class SuspendedSource: ComponentTelemetryService {
        var pending: CheckedContinuation<ServiceOutcome<ComponentEstimatePair>, Never>?
        func sampleComponents() async -> ServiceOutcome<ComponentEstimatePair> {
            await withCheckedContinuation { pending = $0 }
        }
    }
    private final class FailingSystem: TelemetryService {
        func sample() async -> ServiceOutcome<PowerReading> { .failure(.disconnected) }
    }
    private final class Transport: ComponentHelperTransport {
        var events: [String] = []
        var connectionFailure: ServiceFailure?
        func connect() async throws -> HelperPeer {
            events.append("connect")
            if let connectionFailure { throw connectionFailure }
            return HelperPeer(identifier: "test", team: "test", protocolVersion: 1)
        }
        func request(_ request: HelperRequest) async throws -> HelperReply {
            events.append(request.command.rawValue)
            return HelperReply(request: request, build: "test", daemonInstance: UUID(), status: .sourceUnvalidated)
        }
    }
    private func pair(_ clock: FakeWattClock, cpu: Double = 2, gpu: Double = 1) -> ComponentEstimatePair {
        .init(acquisitionID: UUID(), startedAt: clock.now.addingTimeInterval(-1), duration: 1,
              cpuWatts: cpu, gpuWatts: gpu, provenance: "Test source with established units")
    }
    func testComponentFailurePreservesSystemAndNoIDs() async {
        let clock = FakeWattClock(), source = Source()
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        XCTAssertEqual(store.statusReading.value(for: .delta), 42.1)
        XCTAssertTrue(store.statusReading.components.isEmpty)
        XCTAssertTrue(store.availableComponentIDs.isEmpty)
    }
    func testFreshPairSurvivesMissingSystemAndExpires() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock))
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        XCTAssertEqual(store.statusReading.mode, .perComponent)
        XCTAssertEqual(store.availableComponentIDs, ["cpu", "gpu"])
        XCTAssertNil(store.statusReading.value(for: .delta))
        XCTAssertEqual(store.statusReading.components.map(\.name), ["CPU estimate", "GPU estimate"])
        clock.advance(by: 4.1)
        XCTAssertTrue(store.availableComponentIDs.isEmpty)
        XCTAssertTrue(store.statusReading.components.isEmpty)
    }
    func testInvalidSiblingSuppressesWholePair() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock, gpu: .nan))
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        XCTAssertEqual(store.componentFailure, .invalidData)
        XCTAssertTrue(store.availableComponentIDs.isEmpty)
        XCTAssertTrue(store.statusReading.components.isEmpty)
        XCTAssertEqual(store.statusReading.value(for: .delta), 42.1)
    }
    func testReplayAndWakeDoNotResurrectPair() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock))
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        store.handleWake()
        XCTAssertTrue(store.availableComponentIDs.isEmpty)
        clock.advance(by: 3)
        await store.refreshComponents()
        XCTAssertEqual(store.componentFailure, .invalidData)
        XCTAssertTrue(store.statusReading.components.isEmpty)
    }
    func testNewCompletePairRecoversFromUnavailable() async {
        let clock = FakeWattClock(), source = Source()
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        clock.advance(by: 3)
        source.outcome = .success(pair(clock, cpu: 0, gpu: 0))
        await store.refreshComponents()
        XCTAssertEqual(store.statusReading.components.map(\.watts), [0, 0])
        XCTAssertNil(store.componentFailure)
    }
    func testMergedComponentsDoNotRefreshSystemTimestamp() async {
        let clock = FakeWattClock(), source = Source()
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock, componentTelemetry: source)
        clock.advance(by: 4)
        source.outcome = .success(pair(clock))
        await store.refreshComponents()
        XCTAssertEqual(store.statusReading.timestamp, PowerReading.sampleCharging.timestamp)
        clock.advance(by: 2)
        XCTAssertNil(store.statusReading.value(for: .delta))
        XCTAssertEqual(store.availableComponentIDs, ["cpu", "gpu"])
    }
    func testDefaultSelectionAnnouncesBothAsEstimates() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock))
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        preferences.componentReadings = true
        let label = MenuBarStatusLabel(reading: store.statusReading, preferences: preferences)
        XCTAssertTrue(label.text?.contains("CPU estimate 2.0") == true)
        XCTAssertTrue(label.accessibilityReading.contains("GPU estimate 1.0 watts"))
    }

    func testWakeRejectsLateInflightReply() async {
        let clock = FakeWattClock(), source = SuspendedSource()
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        let request = Task { await store.refreshComponents() }
        while source.pending == nil { await Task.yield() }
        store.handleWake()
        source.pending?.resume(returning: .success(pair(clock)))
        await request.value
        XCTAssertNil(store.freshComponentEstimate)
        XCTAssertTrue(store.availableComponentIDs.isEmpty)
    }
    func testWallClockRollbackCannotExtendFreshness() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock))
        let store = PowerReadingStore(currentReading: .unavailable, clock: clock, componentTelemetry: source)
        await store.refreshComponents()
        let wall = clock.now
        clock.advance(by: 6)
        clock.now = wall
        XCTAssertNil(store.freshComponentEstimate)
        XCTAssertTrue(store.statusReading.components.isEmpty)
    }

    func testProductionTelemetryConnectsBeforeRequestAndKeepsRawSourceUnavailable() async {
        let transport = Transport()
        let provider = ProductionHelperTelemetry(transport: transport)
        let outcome = await provider.sampleComponents()
        XCTAssertEqual(transport.events, ["connect", "sample"])
        guard case .failure(.unknownStatus) = outcome else { return XCTFail("Raw source must stay unavailable") }
    }
    func testProductionTelemetryDoesNotSampleAfterAuthenticationFailure() async {
        let transport = Transport()
        transport.connectionFailure = .untrustedIdentity
        let outcome = await ProductionHelperTelemetry(transport: transport).sampleComponents()
        XCTAssertEqual(transport.events, ["connect"])
        guard case .failure = outcome else { return XCTFail("Connection failure must fail closed") }
    }

    func testSystemFailureStillPresentsFreshPairWithoutCachedBatteryValues() async {
        let clock = FakeWattClock(), source = Source()
        source.outcome = .success(pair(clock))
        let store = PowerReadingStore(currentReading: .sampleCharging, clock: clock,
            telemetry: FailingSystem(), componentTelemetry: source)
        await store.refreshComponents()
        await store.refresh()
        XCTAssertEqual(store.failure, .disconnected)
        let presentation = store.statusReading
        XCTAssertEqual(presentation.mode, .perComponent)
        XCTAssertNil(presentation.value(for: .delta))
        XCTAssertNil(presentation.value(for: .charger))
        XCTAssertNil(presentation.value(for: .draw))
        XCTAssertNil(presentation.batteryPercentage)
        let panel = StatusPanelModel(reading: presentation)
        XCTAssertTrue(panel.showsComponents)
        XCTAssertEqual(panel.components.map(\.id), ["cpu", "gpu"])
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        preferences.componentReadings = true
        XCTAssertTrue(MenuBarStatusLabel(reading: presentation, preferences: preferences)
            .accessibilityReading.contains("GPU estimate"))
    }

}
