import Foundation
import Security
import XCTest
import WattHelperShared

private final class EchoHelper: NSObject, WattHelperXPC {
    func exchange(_ data: Data, withReply reply: @escaping (Data) -> Void) {
        guard let request = try? HelperWire.decodeRequest(data) else { reply(Data()); return }
        let result = HelperReply(request: request, build: "fixture", daemonInstance: UUID(), status: .ready)
        reply((try? HelperWire.encode(result)) ?? Data())
    }
}

private final class EchoListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: WattHelperXPC.self)
        connection.exportedObject = EchoHelper()
        connection.resume()
        return true
    }
}

private final class XPCReplyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Data?
    func save(_ data: Data) { lock.withLock { stored = data } }
    var data: Data? { lock.withLock { stored } }
}

final class HelperXPCTests: XCTestCase {
    func testAnonymousXPCSerializesCorrelatedBoundedEnvelope() throws {
        // Anonymous, same-process transport test only; this does not establish signed peer trust.
        let listener = NSXPCListener.anonymous()
        let delegate = EchoListenerDelegate()
        listener.delegate = delegate
        listener.resume()
        let connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: WattHelperXPC.self)
        connection.resume()
        defer { connection.invalidate(); listener.invalidate() }
        let request = HelperRequest(command: .ping, generation: UUID())
        let received = expectation(description: "XPC reply")
        let box = XPCReplyBox()
        let proxy = try XCTUnwrap(connection.remoteObjectProxyWithErrorHandler { _ in received.fulfill() } as? WattHelperXPC)
        proxy.exchange(try HelperWire.encode(request)) { response in box.save(response); received.fulfill() }
        wait(for: [received], timeout: 3)
        let response = try HelperWire.decodeReply(XCTUnwrap(box.data), for: request)
        XCTAssertEqual(response.status, .ready)
        withExtendedLifetime(delegate) {}
    }

    func testInvalidTeamCannotBuildRequirementInjection() {
        for team in ["", "ABCDEFGHI", "ABCDEFGHIJK", "ABCDE\" or true", "abcde12345"] {
            XCTAssertThrowsError(try HelperSigningPolicy(team: team))
        }
    }

    func testRequirementsCompileAndUnrelatedExecutableIsRejected() throws {
        let policy = try HelperSigningPolicy(team: "ABCDE12345")
        for value in [policy.appRequirement, policy.helperRequirement] {
            var requirement: SecRequirement?
            XCTAssertEqual(SecRequirementCreateWithString(value as CFString, [], &requirement), errSecSuccess)
            XCTAssertNotNil(requirement)
        }
        XCTAssertThrowsError(try policy.verifyExecutable(at: URL(fileURLWithPath: "/usr/bin/true"), helper: true))
    }
}
