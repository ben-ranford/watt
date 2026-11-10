import XCTest
import WattHelperShared
@testable import WattHelperRuntime
import Darwin

final class HelperProtocolTests: XCTestCase {
    func testRequestRoundTripAndUnknownFieldsRejected() throws {
        let request = HelperRequest(command: .diagnosticCapture, generation: UUID())
        let data = try HelperWire.encode(request)
        XCTAssertEqual(try HelperWire.decodeRequest(data), request)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["executable"] = "/bin/sh"
        XCTAssertThrowsError(try HelperWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
        object.removeValue(forKey: "executable")
        object["version"] = 999
        XCTAssertThrowsError(try HelperWire.decodeRequest(JSONSerialization.data(withJSONObject: object)))
    }

    func testOversizedRequestsRejectedBeforeParsing() {
        XCTAssertThrowsError(try HelperWire.decodeRequest(Data(repeating: 32, count: HelperLimits.requestBytes + 1))) {
            XCTAssertEqual($0 as? HelperProtocolError, .oversized)
        }
    }

    func testReplyCorrelationAndNormalCaptureRejection() throws {
        let request = HelperRequest(command: .ping, generation: UUID())
        let reply = HelperReply(request: request, build: "test", daemonInstance: UUID(), status: .ready)
        let data = try HelperWire.encode(reply)
        XCTAssertEqual(try HelperWire.decodeReply(data, for: request), reply)
        XCTAssertThrowsError(try HelperWire.decodeReply(data, for: .init(command: .ping, generation: UUID())))
        let capture = HelperCapture(startedAt: Date(), duration: 1, stdout: Data(), stderr: Data(),
                                    exitStatus: 0, status: .completed, terminationConfirmed: true)
        XCTAssertThrowsError(try HelperWire.encode(HelperReply(request: request, build: "test", daemonInstance: UUID(),
                                                               status: .sourceUnvalidated, capture: capture)))
    }

    func testMaximumDiagnosticCaptureFitsSerializedBudget() throws {
        let request = HelperRequest(command: .diagnosticCapture, generation: UUID())
        let capture = HelperCapture(startedAt: Date(), duration: 1,
                                    stdout: Data(repeating: 0, count: HelperLimits.captureBytes), stderr: Data(),
                                    exitStatus: 0, status: .completed, terminationConfirmed: true)
        let reply = HelperReply(request: request, build: "test", daemonInstance: UUID(), status: .sourceUnvalidated, capture: capture)
        let data = try HelperWire.encode(reply)
        XCTAssertLessThan(data.count, HelperLimits.diagnosticReplyBytes)
        XCTAssertEqual(try HelperWire.decodeReply(data, for: request), reply)
        let oversized = HelperCapture(startedAt: Date(), duration: 1, stdout: capture.stdout, stderr: Data([1]),
                                      exitStatus: 0, status: .completed, terminationConfirmed: true)
        XCTAssertThrowsError(try HelperWire.encode(HelperReply(request: request, build: "test", daemonInstance: UUID(),
                                                               status: .sourceUnvalidated, capture: oversized)))
    }

    func testFixedCommandMatchesLocalHelp() {
        XCTAssertEqual(FixedPowerSampler.executable, "/usr/bin/powermetrics")
        XCTAssertEqual(FixedPowerSampler.arguments, ["-f", "plist", "-n", "1", "-i", "1000", "-s", "cpu_power,gpu_power"])
    }
}

private actor CountingCaptureRunner: HelperCaptureRunning {
    var count = 0
    func capture() async -> HelperCapture {
        count += 1
        try? await Task.sleep(for: .milliseconds(50))
        return .init(startedAt: Date(), duration: 0.05, stdout: Data(), stderr: Data(),
                     exitStatus: 0, status: .completed, terminationConfirmed: true)
    }
}

final class HelperSamplerTests: XCTestCase, @unchecked Sendable {
    func testConcurrentClientsShareAcquisitionAndNoQueuedSample() async {
        let runner = CountingCaptureRunner()
        let coordinator = HelperSamplerCoordinator(runner: runner, now: { 100 })
        async let a = coordinator.capture()
        async let b = coordinator.capture()
        let results = await (a, b)
        XCTAssertEqual(results.0?.acquisitionID, results.1?.acquisitionID)
        let count = await runner.count
        XCTAssertEqual(count, 1)
        let skipped = await coordinator.capture()
        XCTAssertNil(skipped)
        await coordinator.stop()
        let stopped = await coordinator.capture()
        XCTAssertNil(stopped)
    }

    func testRealFixedChildIsBoundedAndReaped() async {
        let capture = await FixedPowerSampler().capture()
        XCTAssertTrue(capture.terminationConfirmed)
        XCTAssertLessThan(capture.duration, 4.5)
        XCTAssertLessThanOrEqual(capture.stdout.count + capture.stderr.count, HelperLimits.captureBytes)
        XCTAssertNotNil(capture.exitStatus)
        // This proves process plumbing only; an unprivileged host normally reports permission denied.
    }
}

private final class HelperTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 100.0
    func now() -> Double { lock.withLock { value } }
    func advance(_ interval: Double) { lock.withLock { value += interval } }
}

private struct InterruptedCaptureRunner: HelperCaptureRunning {
    func capture() async -> HelperCapture {
        .init(startedAt: Date(), duration: 4, stdout: Data(), stderr: Data(),
              exitStatus: nil, status: .interrupted, terminationConfirmed: false)
    }
}

extension HelperSamplerTests {
    func testStartSpacingSkipsMissedIntervalsWithoutCatchup() async {
        let clock = HelperTestClock()
        let runner = CountingCaptureRunner()
        let coordinator = HelperSamplerCoordinator(runner: runner, now: { clock.now() })
        let first = await coordinator.capture()
        XCTAssertNotNil(first)
        clock.advance(2.99)
        let early = await coordinator.capture()
        XCTAssertNil(early)
        clock.advance(0.02)
        let next = await coordinator.capture()
        XCTAssertNotNil(next)
        clock.advance(100)
        let late = await coordinator.capture()
        XCTAssertNotNil(late)
        let burst = await coordinator.capture()
        XCTAssertNil(burst)
        let count = await runner.count
        XCTAssertEqual(count, 3)
    }

    func testUnprovenTerminationClosesAdmission() async {
        let coordinator = HelperSamplerCoordinator(runner: InterruptedCaptureRunner())
        let first = await coordinator.capture()
        XCTAssertEqual(first?.status, .interrupted)
        let subsequent = await coordinator.capture()
        XCTAssertNil(subsequent)
    }

    func testCancelledCaptureDoesNotLeaveOwnedChild() async {
        let task = Task { await FixedPowerSampler().capture() }
        task.cancel()
        let capture = await task.value
        XCTAssertTrue(capture.terminationConfirmed)
        XCTAssertLessThan(capture.duration, 4.5)
    }
}

private actor RecoveringFixtureRunner: HelperCaptureRunning {
    private var first = true
    func capture() async -> HelperCapture {
        let fixture: FixedPowerSampler.TestFixture = first ? .overflowingStreams : .successful
        first = false
        return await FixedPowerSampler.captureFixture(fixture)
    }
}

extension HelperSamplerTests {
    func testIgnoringTERMChildTimesOutIsKilledAndReaped() async throws {
        let capture = await FixedPowerSampler.captureFixture(.ignoresTermination)
        XCTAssertEqual(capture.status, .timedOut)
        XCTAssertEqual(capture.exitStatus, 128 + SIGKILL)
        XCTAssertTrue(capture.terminationConfirmed)
        XCTAssertGreaterThanOrEqual(capture.duration, 3.5)
        XCTAssertLessThan(capture.duration, 4.5)
        try assertFixtureReaped(capture)
    }

    func testBothPipesOverflowWithinCombinedCapAndRecoveryIsAllowed() async {
        let clock = HelperTestClock()
        let coordinator = HelperSamplerCoordinator(runner: RecoveringFixtureRunner(), now: { clock.now() })
        let first = await coordinator.capture()
        XCTAssertEqual(first?.status, .outputLimit)
        XCTAssertEqual(first?.terminationConfirmed, true)
        XCTAssertGreaterThan(first?.stdout.count ?? 0, 0)
        XCTAssertGreaterThan(first?.stderr.count ?? 0, 0)
        XCTAssertEqual((first?.stdout.count ?? 0) + (first?.stderr.count ?? 0), HelperLimits.captureBytes)
        XCTAssertLessThan(first?.duration ?? 99, 4.5)
        clock.advance(3)
        let second = await coordinator.capture()
        XCTAssertEqual(second?.status, .completed)
        XCTAssertEqual(second?.exitStatus, 0)
        XCTAssertEqual(second?.terminationConfirmed, true)
        XCTAssertEqual(second?.stdout, Data("fixture complete".utf8))
    }

    func testCancellationDuringLiveChildEscalatesToKILLAndReaps() async throws {
        let task = Task { await FixedPowerSampler.captureFixture(.ignoresTermination) }
        try await Task.sleep(for: .milliseconds(150))
        task.cancel()
        let capture = await task.value
        XCTAssertEqual(capture.status, .cancelled)
        XCTAssertEqual(capture.exitStatus, 128 + SIGKILL)
        XCTAssertTrue(capture.terminationConfirmed)
        XCTAssertLessThan(capture.duration, 2)
        try assertFixtureReaped(capture)
    }

    private func assertFixtureReaped(_ capture: HelperCapture) throws {
        let text = try XCTUnwrap(String(data: capture.stdout, encoding: .utf8))
        let pid = try XCTUnwrap(Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        var status: Int32 = 0
        XCTAssertEqual(waitpid(pid, &status, WNOHANG), -1)
        XCTAssertEqual(errno, ECHILD, "Runner must have reaped its owned fixture process")
    }
}
