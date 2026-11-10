import Darwin
import Foundation

/// Bounded framed IPC over inherited anonymous pipes. No pathname rendezvous or claimed peer PID.
public enum MaintenanceChannel {
    public static func write(_ bytes: Data, to fd: Int32) throws {
        guard bytes.count <= 1_048_576 else { throw MaintenanceProtocolError.oversized }
        guard fcntl(fd, F_SETNOSIGPIPE, 1) == 0 else { throw MaintenanceProtocolError.invalidRequest }
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { throw MaintenanceProtocolError.invalidRequest }
        defer { _ = fcntl(fd, F_SETFL, flags) }
        let deadline = Date().addingTimeInterval(5)
        var size = UInt32(bytes.count).bigEndian
        var packet = withUnsafeBytes(of: &size) { Data($0) }; packet.append(bytes)
        try packet.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { throw MaintenanceProtocolError.invalidRequest }
                var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                guard poll(&descriptor, 1, Int32(remaining * 1000)) > 0 else { throw MaintenanceProtocolError.invalidRequest }
                let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if n < 0 && (errno == EAGAIN || errno == EINTR) { continue }
                guard n > 0 else { throw MaintenanceProtocolError.invalidRequest }
                offset += n
            }
        }
    }
    public static func read(from fd: Int32, timeout: TimeInterval = 5) throws -> Data {
        guard timeout > 0, timeout <= 60 else { throw MaintenanceProtocolError.invalidRequest }
        let deadline = Date().addingTimeInterval(timeout)
        func exact(_ count: Int) throws -> Data {
            var bytes = [UInt8](repeating: 0, count: count); var offset = 0
            while offset < count {
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { throw MaintenanceProtocolError.invalidRequest }
                var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                guard poll(&descriptor, 1, Int32(remaining * 1000)) > 0 else { throw MaintenanceProtocolError.invalidRequest }
                let n = bytes.withUnsafeMutableBytes {
                    Darwin.read(fd, $0.baseAddress!.advanced(by: offset), count - offset)
                }
                if n < 0 && (errno == EAGAIN || errno == EINTR) { continue }
                guard n > 0 else { throw MaintenanceProtocolError.invalidRequest }
                offset += n
            }
            return Data(bytes)
        }
        let header = try exact(4)
        let count = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count <= 1_048_576 else { throw MaintenanceProtocolError.oversized }
        return try exact(Int(count))
    }
}
