import Foundation
import NicheKit
import Testing

@MainActor
struct ContractTests {
    static let mode = ProcessInfo.processInfo.environment["NICHE_RECORD"] == nil ? "--check" : "--record"

    @Test func theProtocolTranscriptMatchesTheGolden() async throws {
        let server = try await RunningServer()
        defer { server.stop() }

        let result = try await run(
            ["python3", Repository.path("Verify/protocol.py"), Self.mode, Repository.path("Verify/golden/protocol.jsonl")],
            environment: ["NICHE_SOCKET": server.path]
        )
        #expect(result.status == 0, "\(result.output)")
    }

    @Test func theCommandInvocationsMatchTheGolden() async throws {
        let result = try await run(
            ["python3", Repository.path("Verify/command.py"), Self.mode, Repository.path("Verify/golden/command.jsonl")],
            environment: ["NICHE_COMMAND": Repository.products.appendingPathComponent("NicheCLI").path]
        )
        #expect(result.status == 0, "\(result.output)")
    }

    @Test func thePythonClientRequestsUpdatesAndReceivesIntents() async throws {
        let server = try await RunningServer()
        defer { server.stop() }
        async let finished = run(["python3", Repository.path("Verify/client.py")], environment: ["NICHE_SOCKET": server.path])

        for _ in 0..<500 where server.center.presented.first?.island.minimal?.text != "n=2" {
            try await Task.sleep(for: .milliseconds(10))
        }
        server.center.intent("other", from: "someone-else")
        server.center.intent("ping", from: "client-check", value: 2.5)

        let result = try await finished
        #expect(result.status == 0, "\(result.output)")
        #expect(result.output.contains("client: ok"))
        #expect(server.center.activities.isEmpty)
    }

    @Test func subscribersReceiveIntentsAndOpenedURLs() async throws {
        let server = try await RunningServer()
        defer { server.stop() }
        let connection = try await server.connect()
        #expect(try await connection.send(#"{"op":"subscribe"}"#) == #"{"ok":true}"#)

        server.center.intent("seek", from: "player", value: 43.5)
        #expect(await connection.next() == #"{"event":"intent","id":"player","intent":"seek","value":43.5}"#)

        server.center.intent("mute", from: "player", isOn: true)
        #expect(await connection.next() == #"{"event":"intent","id":"player","intent":"mute","isOn":true}"#)

        server.center.opened("https://example.com/a", from: "player")
        #expect(await connection.next() == #"{"event":"openURL","id":"player","url":"https://example.com/a"}"#)
    }

    @Test func hapticReachesTheHostWithItsStrength() async throws {
        let server = try await RunningServer()
        defer { server.stop() }
        let connection = try await server.connect()

        #expect(try await connection.send(#"{"op":"haptic","strength":3}"#) == #"{"ok":true}"#)
        #expect(try await connection.send(#"{"op":"haptic"}"#) == #"{"ok":true}"#)
        #expect(server.haptics == [3, nil])
    }
}
