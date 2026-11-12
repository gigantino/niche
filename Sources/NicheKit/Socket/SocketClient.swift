import Foundation

public final class SocketClient: @unchecked Sendable {
    public enum Failure: Error {
        case pathTooLong
        case notListening(path: String)
        case disconnected
    }

    private let descriptor: Int32
    private var buffer = Data()

    public init(path: String = SocketPath.current, readTimeout: TimeInterval? = nil) throws {
        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw Failure.notListening(path: path) }
        if let readTimeout {
            var limit = timeval(tv_sec: Int(readTimeout), tv_usec: Int32(readTimeout.truncatingRemainder(dividingBy: 1) * 1_000_000))
            setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }

        let status = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard status == 0 else { throw Failure.notListening(path: path) }
    }

    deinit {
        if descriptor >= 0 { close(descriptor) }
    }

    public func write(_ line: Data) throws {
        var data = line
        data.append(0x0A)
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let sent = Darwin.write(descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                guard sent > 0 else { throw Failure.disconnected }
                offset += sent
            }
        }
    }

    public func read() -> Data? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[buffer.startIndex..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
                return line
            }
            var chunk = [UInt8](repeating: 0, count: 65536)
            let count = Darwin.read(descriptor, &chunk, chunk.count)
            guard count > 0 else { return nil }
            buffer.append(contentsOf: chunk[0..<count])
        }
    }

    public func finishWriting() {
        shutdown(descriptor, SHUT_WR)
    }
}
