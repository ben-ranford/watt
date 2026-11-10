import Darwin
import Foundation
import Security
#if SWIFT_PACKAGE
import WattHelperShared
#endif

public enum MaintenanceProcessWitness {
    /// Conservative fixed-helper inventory. Inspection failure is never absence proof.
    public static func helperProcessesAbsent() -> Bool {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0, estimate < 32_640 else { return false }
        let capacity = Int(estimate) + 128
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { proc_listallpids($0.baseAddress, Int32($0.count)) }
        guard count > 0, count < capacity else { return false }
        for pid in pids.prefix(Int(count)) where pid > 0 {
            var buffer = [CChar](repeating: 0, count: 4096)
            errno = 0
            let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            if length <= 0 {
                // ESRCH is a pid that is already gone. ENOENT is that same race on
                // macOS 27. A deleted executable can also fail the path lookup while
                // the kernel name remains, so a failed path still checks the name.
                if errno == ESRCH { continue }
                let pathErrno = errno
                let n = proc_name(pid, &buffer, UInt32(buffer.count))
                if n <= 0 {
                    if errno == ESRCH || errno == ENOENT || pathErrno == ENOENT { continue }
                    return false
                }
                guard let end = buffer.firstIndex(of: 0), end > 0,
                      let name = String(bytes: buffer[..<end].map({ UInt8(bitPattern: $0) }), encoding: .utf8),
                      name != "WattHelper", name != "powermetrics", name != HelperIdentity.helperIdentifier else { return false }
                continue
            }
            guard let end = buffer.firstIndex(of: 0), end > 0,
                  let path = String(bytes: buffer[..<end].map({ UInt8(bitPattern: $0) }), encoding: .utf8) else { return false }
            if path == ProtectedHelperRecord.helperURL.path || path == "/usr/bin/powermetrics"
                || URL(fileURLWithPath: path).lastPathComponent == "WattHelper" { return false }
        }
        return true
    }
    /// Kernel process start time defeats PID reuse; Security obtains the actual dynamic code.
    public static func observe(pid: Int32) throws -> MaintenanceProcessIdentity {
        var info = proc_bsdinfo()
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) == MemoryLayout.size(ofValue: info) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributePid: pid] as CFDictionary, [], &code) == errSecSuccess,
              let code, SecCodeCheckValidity(code, [], nil) == errSecSuccess else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            throw MaintenanceProtocolError.invalidRequest
        }
        var signing: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &signing) == errSecSuccess,
              let hash = (signing as? [String: Any])?[kSecCodeInfoUnique as String] as? Data, hash.count == 20 else {
            throw MaintenanceProtocolError.invalidRequest
        }
        let value = MaintenanceProcessIdentity(pid: pid, uid: info.pbi_uid,
            startedAtMicroseconds: info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec,
            codeDirectoryHash: hash)
        guard value.isValid else { throw MaintenanceProtocolError.invalidRequest }
        return value
    }

    public static func matches(_ expected: MaintenanceProcessIdentity) throws -> Bool {
        try observe(pid: expected.pid) == expected
    }

    public struct LiveObservation: Sendable {
        public let identity: MaintenanceProcessIdentity
        fileprivate init(identity: MaintenanceProcessIdentity) { self.identity = identity }
        public func hasExited() throws -> Bool { try MaintenanceProcessWitness.hasExited(identity) }
        public func waitForExit(timeout: TimeInterval) async throws -> Bool {
            guard timeout > 0, timeout <= 60 else { throw MaintenanceProtocolError.invalidRequest }
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(Int64(timeout * 1000)))
            while ContinuousClock.now < deadline {
                try Task.checkCancellation()
                if try hasExited() { return true }
                try await Task.sleep(for: .milliseconds(50))
            }
            return try hasExited()
        }
    }

    public static func observeLive(pid: Int32) throws -> LiveObservation {
        LiveObservation(identity: try observe(pid: pid))
    }

    /// A negative signal probe alone is insufficient: EPERM and inspection errors are unknown.
    private static func hasExited(_ expected: MaintenanceProcessIdentity) throws -> Bool {
        guard expected.isValid else { throw MaintenanceProtocolError.invalidRequest }
        if kill(expected.pid, 0) != 0 {
            guard errno == ESRCH else { throw MaintenanceProtocolError.invalidRequest }
            return true
        }
        var info = proc_bsdinfo()
        guard proc_pidinfo(expected.pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout.size(ofValue: info))) == MemoryLayout.size(ofValue: info) else {
            throw MaintenanceProtocolError.invalidRequest
        }
        return info.pbi_start_tvsec * 1_000_000 + info.pbi_start_tvusec != expected.startedAtMicroseconds
    }
}
