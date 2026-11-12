import Foundation
import NicheKit

let usage = """
usage: niche <command>

  request [options]        start a Live Activity and print its id
  update <id> [options]    update its content, optionally with an alert
  end <id> [options]       end it
  activities               print the activities
  configure <type> <json>  register the DynamicIsland for an attributes type
  events                   print state, content and intent events as JSON lines
  info                     print whether activities are enabled and the notch size
  send <json>              send one raw request and print the reply
  raw                      forward JSON lines from stdin, print replies and events

content:
  --state JSON             ActivityContent.state
  --staleDate TIME         ActivityContent.staleDate
  --relevanceScore N       ActivityContent.relevanceScore

request:
  --id ID   --type NAME   --attributes JSON   --start TIME

DynamicIsland (request, or update to change parts of it):
  --compactLeading NODE   --compactTrailing NODE   --minimal NODE
  --leading NODE   --trailing NODE   --center NODE   --bottom NODE
  --widgetURL URL   --dynamicIsland JSON

alert (request and update):
  --alert TITLE   --body TEXT   --sound NAME

end:
  --dismissalPolicy default | immediate | after:TIME

TIME is Unix seconds, or +SECONDS from now. JSON arguments also take @file.

NODE is JSON, @file, or a shorthand with optional ;key=value pairs:
  text:Hello  symbol:bolt.fill;foregroundStyle=orange  ring:0.6  progress:0.6
  image:~/cover.png  app:com.apple.Music  timer:90  stopwatch
  bars  video:~/clip.mp4  web:https://example.com
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("niche: \(message)\n".utf8))
    exit(1)
}

final class Connection: @unchecked Sendable {
    private let client: SocketClient

    init() {
        do {
            client = try SocketClient()
        } catch SocketClient.Failure.pathTooLong {
            fail("socket path is too long")
        } catch {
            fail("Niche is not running (no socket at \(SocketPath.current))")
        }
    }

    func write(_ line: Data) {
        do {
            try client.write(line)
        } catch {
            fail("lost the connection to Niche")
        }
    }

    func read() -> Data? {
        client.read()
    }

    func finishWriting() {
        client.finishWriting()
    }

    func request(_ body: [String: Any]) -> [String: Any] {
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { fail("could not encode the request") }
        write(data)
        guard let line = read(), let reply = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            fail("no reply from Niche")
        }
        return reply
    }
}

func emit(_ line: Data) {
    FileHandle.standardOutput.write(line + Data([0x0A]))
}

func finish(_ reply: [String: Any], printing: Bool = false) -> Never {
    guard reply["ok"] as? Bool == true else { fail(reply["error"] as? String ?? "request failed") }
    if printing, let data = try? JSONSerialization.data(withJSONObject: reply, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
        emit(data)
    }
    exit(0)
}

var arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty, !["help", "--help", "-h"].contains(arguments[0]) else {
    print(usage)
    exit(arguments.isEmpty ? 1 : 0)
}

let command = arguments.removeFirst()

switch command {
case "request":
    let reply = Connection().request(request("request", id: nil, options: arguments))
    if let id = reply["id"] as? String { print(id) }
    finish(reply)

case "update", "end":
    guard !arguments.isEmpty else { fail("\(command) needs an id") }
    let id = arguments.removeFirst()
    finish(Connection().request(request(command, id: id, options: arguments)))

case "configure":
    guard arguments.count == 2 else { fail("configure needs a type and a DynamicIsland as JSON or @file") }
    finish(Connection().request([
        "op": "configure",
        "for": arguments[0],
        "dynamicIsland": object(arguments[1], what: "DynamicIsland")
    ]))

case "haptic":
    var body: [String: Any] = ["op": "haptic"]
    body["strength"] = arguments.first.flatMap { Int($0) }
    finish(Connection().request(body))

case "activities", "info":
    finish(Connection().request(["op": command]), printing: true)

case "send":
    guard let text = arguments.first else { fail("send needs a JSON request") }
    finish(Connection().request(object(text, what: "request")), printing: true)

case "events":
    setvbuf(stdout, nil, _IONBF, 0)
    let connection = Connection()
    _ = connection.request(["op": "subscribe"])
    while let line = connection.read() { emit(line) }

case "raw":
    setvbuf(stdout, nil, _IONBF, 0)
    let connection = Connection()
    let reader = Thread {
        while let line = connection.read() { emit(line) }
        exit(0)
    }
    reader.start()
    while let line = readLine() {
        connection.write(Data(line.utf8))
    }
    connection.finishWriting()
    Thread.sleep(forTimeInterval: 0.5)

default:
    fail("unknown command \"\(command)\"\n\n\(usage)")
}
