import Foundation
import Network
import OSLog

@MainActor
public final class Server {
    public struct Host {
        public var notch: () -> CGSize?
        public var version: () -> String?
        public var haptic: (Int32?) -> Void

        public init(notch: @escaping () -> CGSize?, version: @escaping () -> String?, haptic: @escaping (Int32?) -> Void) {
            self.notch = notch
            self.version = version
            self.haptic = haptic
        }
    }

    @MainActor
    private final class Client {
        let connection: NWConnection
        var buffer = Data()
        var subscribed = false
        var bound: Set<String> = []

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    private let center: ActivityCenter
    private let host: Host
    private let path: String
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: Client] = [:]
    private let encoder = JSONEncoder()
    private let log = Logger(subsystem: "ch.ggtn.niche", category: "server")

    public init(center: ActivityCenter, host: Host, path: String = SocketPath.current) {
        self.center = center
        self.host = host
        self.path = path
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
    }

    public func start() throws {
        let path = path
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        unlink(path)

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: path)
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { connection in
            MainActor.assumeIsolated { self.accept(connection) }
        }
        listener.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                switch state {
                case .ready:
                    chmod(path, 0o600)
                    self.log.notice("listening on \(path, privacy: .public)")
                case .failed(let error):
                    self.log.error("listener failed: \(error, privacy: .public)")
                default:
                    break
                }
            }
        }
        listener.start(queue: .main)
        self.listener = listener

        center.onEvent = { [weak self] in self?.broadcast($0) }
    }

    public func stop() {
        listener?.cancel()
        unlink(path)
    }

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        clients[ObjectIdentifier(client)] = client
        connection.start(queue: .main)
        receive(client)
    }

    private func receive(_ client: Client) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, complete, error in
            MainActor.assumeIsolated {
                if let data {
                    client.buffer.append(data)
                    self.drain(client)
                }
                if complete || error != nil {
                    self.drop(client)
                } else {
                    self.receive(client)
                }
            }
        }
    }

    private func drain(_ client: Client) {
        while let newline = client.buffer.firstIndex(of: 0x0A) {
            let line = Data(client.buffer[client.buffer.startIndex..<newline])
            client.buffer.removeSubrange(client.buffer.startIndex...newline)
            guard line.contains(where: { $0 > 0x20 }) else { continue }
            send(handle(line, from: client), to: client)
        }
    }

    private func drop(_ client: Client) {
        guard clients.removeValue(forKey: ObjectIdentifier(client)) != nil else { return }
        client.connection.cancel()
        for id in client.bound {
            try? center.end(id, dismissalPolicy: .immediate)
        }
    }

    private func handle(_ line: Data, from client: Client) -> Reply {
        do {
            return try perform(JSONDecoder().decode(Request.self, from: line), from: client)
        } catch {
            return Reply(ok: false, error: Self.describe(error))
        }
    }

    private func perform(_ request: Request, from client: Client) throws -> Reply {
        guard let operation = Request.Operation(rawValue: request.op) else {
            throw APIError(message: "unknown op \"\(request.op)\"")
        }

        switch operation {
        case .configure:
            guard let type = request.for, let island = request.dynamicIsland else {
                throw APIError(message: "configure needs \"for\" and \"dynamicIsland\"")
            }
            try center.configure(for: type, dynamicIsland: island)
        case .request:
            let id = try center.request(
                id: request.id,
                attributesType: request.attributesType,
                attributes: request.attributes,
                content: request.content ?? ActivityContent(),
                dynamicIsland: request.dynamicIsland,
                alert: request.alertConfiguration,
                start: request.start
            )
            if request.bound == true {
                client.bound.insert(id)
            } else {
                client.bound.remove(id)
            }
            return Reply(id: id)
        case .update:
            try center.update(
                try id(of: request),
                content: request.content,
                dynamicIsland: request.dynamicIsland,
                alert: request.alertConfiguration,
                timestamp: request.timestamp
            )
        case .end:
            try center.end(
                try id(of: request),
                content: request.content,
                dismissalPolicy: request.dismissalPolicy ?? .default,
                timestamp: request.timestamp
            )
        case .activities:
            return Reply(activities: center.snapshot())
        case .subscribe:
            client.subscribed = true
        case .info:
            let notch = host.notch()
            return Reply(
                areActivitiesEnabled: notch != nil,
                notch: notch.map { [$0.width, $0.height] },
                version: host.version()
            )
        case .haptic:
            host.haptic(request.strength)
        }
        return Reply()
    }

    private func id(of request: Request) throws -> String {
        guard let id = request.id else { throw APIError(message: "\(request.op) needs an id") }
        return id
    }

    private func broadcast(_ event: NotchEvent) {
        for client in clients.values where client.subscribed {
            send(event, to: client)
        }
    }

    private func send(_ value: some Encodable, to client: Client) {
        guard var data = try? encoder.encode(value) else { return }
        data.append(0x0A)
        client.connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private static func describe(_ error: Error) -> String {
        if let error = error as? APIError { return error.message }
        guard let error = error as? DecodingError else { return "invalid JSON" }

        let (message, context): (String, DecodingError.Context) = switch error {
        case .keyNotFound(let key, let context): ("missing \"\(key.stringValue)\"", context)
        case .typeMismatch(_, let context): (context.debugDescription, context)
        case .valueNotFound(_, let context): (context.debugDescription, context)
        case .dataCorrupted(let context): (context.debugDescription, context)
        @unknown default: ("invalid request", DecodingError.Context(codingPath: [], debugDescription: ""))
        }

        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? message : "\(path): \(message)"
    }
}
