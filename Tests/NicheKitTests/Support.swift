import Foundation
import NicheKit

enum Repository {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func path(_ relative: String) -> String {
        root.appendingPathComponent(relative).path
    }

    static var products: URL {
        Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") }?.bundleURL.deletingLastPathComponent()
            ?? root.appendingPathComponent(".build/debug")
    }
}

func island(_ json: String) throws -> DynamicIsland {
    try JSONDecoder().decode(DynamicIsland.self, from: Data(json.utf8))
}

func run(_ arguments: [String], environment: [String: String] = [:]) async throws -> (status: Int32, output: String) {
    let process = Process()
    nonisolated(unsafe) let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    process.standardOutput = pipe
    process.standardError = pipe

    return try await withCheckedThrowingContinuation { continuation in
        process.terminationHandler = { process in
            let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            continuation.resume(returning: (process.terminationStatus, output))
        }
        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

@MainActor
final class RunningServer {
    let center = ActivityCenter()
    let path: String
    private let server: Server
    private(set) var haptics: [Int32?] = []

    init() async throws {
        let folder = NSTemporaryDirectory() + "niche-" + UUID().uuidString.prefix(8)
        path = folder + "/s.sock"

        var record: (Int32?) -> Void = { _ in }
        server = Server(
            center: center,
            host: Server.Host(notch: { CGSize(width: 209, height: 38) }, version: { "0.1.0" }, haptic: { record($0) }),
            path: path
        )
        record = { [weak self] in self?.haptics.append($0) }
        try server.start()

        for _ in 0..<200 where !FileManager.default.fileExists(atPath: path) {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func stop() {
        server.stop()
    }

    func connect() async throws -> Connection {
        let path = path
        return Connection(client: try await Task.detached { try SocketClient(path: path, readTimeout: 5) }.value)
    }
}

struct Connection: Sendable {
    let client: SocketClient

    func send(_ json: String) async throws -> String {
        try await Task.detached {
            try client.write(Data(json.utf8))
            return client.read().map { String(decoding: $0, as: UTF8.self) } ?? ""
        }.value
    }

    func next() async -> String {
        await Task.detached {
            client.read().map { String(decoding: $0, as: UTF8.self) } ?? ""
        }.value
    }
}
