import json
import os
import re
import socket
import sys
import time

SOCKET = os.environ.get("NICHE_SOCKET", os.path.expanduser("~/Library/Application Support/Niche/niche.sock"))
UUID = re.compile(r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")


class Client:
    def __init__(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(SOCKET)
        self.buffer = b""

    def write(self, line):
        self.sock.sendall(line.encode() + b"\n")

    def lines(self, timeout):
        self.sock.settimeout(timeout)
        try:
            while b"\n" not in self.buffer:
                chunk = self.sock.recv(65536)
                if not chunk:
                    return
                self.buffer += chunk
        except socket.timeout:
            return
        while b"\n" in self.buffer:
            line, self.buffer = self.buffer.split(b"\n", 1)
            yield json.loads(line)

    def until_reply(self):
        received = []
        deadline = time.time() + 5
        while time.time() < deadline:
            for message in self.lines(0.5):
                received.append(message)
                if "ok" in message:
                    return received
        raise SystemExit(f"no reply, got {received}")

    def drain(self, seconds):
        received = []
        deadline = time.time() + seconds
        while time.time() < deadline:
            received.extend(self.lines(max(0.01, deadline - time.time())))
        return received

    def close(self):
        self.sock.close()


def normalize(value):
    if isinstance(value, dict):
        return {key: "<notch>" if key == "notch" else normalize(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, str) and UUID.match(value):
        return "<uuid>"
    if isinstance(value, (int, float)) and not isinstance(value, bool) and value > 1e9:
        return "<time>"
    return value


def mine(message, generated):
    def owned(identifier):
        return identifier is None or identifier.startswith("pin-") or identifier in generated

    if "activities" in message:
        message = dict(message, activities=[a for a in message["activities"] if owned(a.get("id"))])
    if message.get("event") in ("intent", "openURL"):
        return None
    return message if owned(message.get("id")) else None


def run():
    now = time.time()
    text = {"type": "Text", "text": "{{state.label}} {{attributes.kind}} {{activityID}} {{isStale}}"}
    island = {
        "compactLeading": text,
        "compactTrailing": {"type": "ProgressView", "value": "{{state.progress}}", "progressViewStyle": "circular"},
        "minimal": {"type": "Image", "systemName": "bolt.fill"},
        "expanded": {"center": text, "bottom": {"type": "Button", "intent": "go", "title": "Go"}},
    }
    typed = {"compactLeading": {"type": "Text", "text": "{{attributes.name}}"}}

    steps = [
        ("a", {"op": "info"}),
        ("a", "not json"),
        ("a", "[1, 2]"),
        ("a", {"op": "nope"}),
        ("a", {"id": "pin-a"}),
        ("a", {"op": "update"}),
        ("a", {"op": "update", "id": "pin-missing"}),
        ("a", {"op": "end", "id": "pin-missing"}),
        ("a", {"op": "end"}),
        ("a", {"op": "request", "id": "pin-a"}),
        ("a", {"op": "request", "id": "pin-a", "attributesType": "PinUnknown"}),
        ("a", {"op": "configure", "for": "PinType"}),
        ("a", {"op": "configure", "dynamicIsland": typed}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": {"compactLeading": {"type": "Nope"}}}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": {"compactLeading": {"text": "x"}}}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": {"minimal": {"type": "Text", "padding": [1, 2, 3]}}}),
        ("a", {"op": "request", "id": "pin-a",
               "dynamicIsland": {"expanded": {"bottom": {"type": "VStack", "children": [
                   {"type": "Text", "frame": {"maxWidth": "wide"}}]}}}}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": {"compactLeading": {"type": "Text", "lineLimit": "two"}}}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": {"contentMargins": [{"edges": "top"}]}}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": island, "content": {"staleDate": "soon"}}),
        ("a", {"op": "end", "id": "pin-a", "dismissalPolicy": "later"}),
        ("a", {"op": "end", "id": "pin-a", "dismissalPolicy": {"after": "x"}}),
        ("a", {"op": "haptic", "strength": "hard"}),
        ("a", {"op": "activities"}),
        ("a", {"op": "subscribe"}),
        ("a", {"op": "request", "id": "pin-a", "attributesType": "PinInline", "attributes": {"kind": "demo"},
               "content": {"state": {"label": "one", "progress": 0.25}, "relevanceScore": 5},
               "dynamicIsland": island}),
        ("a", {"op": "activities"}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "two", "progress": 0.5}}}),
        ("a", {"op": "update", "id": "pin-a", "dynamicIsland": {"expanded": {"leading": {"type": "Spacer"}}}}),
        ("a", {"op": "update", "id": "pin-a", "dynamicIsland": {"minimal": {"type": "Bogus"}}}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "three"}, "staleDate": now + 0.5}}),
        ("wait", 1.0),
        ("a", {"op": "activities"}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "four"}, "staleDate": now - 5}}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "five"}}}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "six"}}, "timestamp": now + 1000}),
        ("a", {"op": "update", "id": "pin-a", "content": {"state": {"label": "ignored"}}, "timestamp": now - 1000}),
        ("a", {"op": "update", "id": "pin-a"}),
        ("a", {"op": "activities"}),
        ("a", {"op": "configure", "for": "PinType", "dynamicIsland": typed}),
        ("a", {"op": "request", "attributesType": "PinType", "attributes": {"name": "typed"}}),
        ("a", {"op": "activities"}),
        ("a", {"op": "configure", "for": "PinType", "dynamicIsland": {"compactLeading": {"type": "Text", "text": "re"}}}),
        ("a", {"op": "configure", "for": "PinType", "dynamicIsland": {"compactLeading": {"type": "Nope"}}}),
        ("a", {"op": "request", "id": "pin-p", "dynamicIsland": typed, "start": now + 3.0,
               "content": {"state": {"n": 1}}}),
        ("a", {"op": "update", "id": "pin-p", "content": {"state": {"n": 2}}}),
        ("a", {"op": "activities"}),
        ("wait", 3.2),
        ("a", {"op": "end", "id": "pin-p", "content": {"state": {"n": 3}}, "dismissalPolicy": {"after": now + 5.6}}),
        ("a", {"op": "update", "id": "pin-p", "content": {"state": {"n": 4}}}),
        ("a", {"op": "activities"}),
        ("wait", 2.0),
        ("end-generated", "default"),
        ("b", {"op": "request", "id": "pin-b", "bound": True, "dynamicIsland": typed}),
        ("b", {"op": "request", "id": "pin-c", "dynamicIsland": typed}),
        ("wait", 0.3),
        ("close-b", None),
        ("wait", 0.5),
        ("a", {"op": "request", "id": "pin-c", "bound": True, "dynamicIsland": typed}),
        ("a", {"op": "request", "id": "pin-a", "dynamicIsland": typed, "content": {"relevanceScore": 1}}),
        ("a", {"op": "end", "id": "pin-a", "dismissalPolicy": "immediate", "timestamp": now}),
        ("a", {"op": "end", "id": "pin-a"}),
        ("a", {"op": "end", "id": "pin-c", "dismissalPolicy": {"after": now - 1}}),
        ("a", {"op": "activities"}),
    ]

    clients = {"a": Client(), "b": Client()}
    generated = set()
    transcript = []

    def record(step, received):
        kept = [m for m in (mine(message, generated) for message in received) if m is not None]
        transcript.append({"step": step, "received": kept})

    for target, payload in steps:
        if target == "wait":
            record({"wait": payload}, clients["a"].drain(payload))
        elif target == "close-b":
            clients["b"].close()
            record({"close": "b"}, [])
        elif target == "end-generated":
            for identifier in sorted(generated):
                clients["a"].write(json.dumps({"op": "end", "id": identifier, "dismissalPolicy": payload}))
                record({"to": "a", "end": "<uuid>"}, clients["a"].until_reply())
        else:
            line = payload if isinstance(payload, str) else json.dumps(payload)
            clients[target].write(line)
            received = clients[target].until_reply()
            for message in received:
                if isinstance(payload, dict) and payload.get("op") == "request" and "id" not in payload and message.get("ok"):
                    generated.add(message["id"])
            record({"to": target, "send": payload}, received)

    record({"wait": 0.3}, clients["a"].drain(0.3))
    clients["a"].close()
    return [normalize(entry) for entry in transcript]


def main():
    transcript = run()
    output = "".join(json.dumps(entry, sort_keys=True) + "\n" for entry in transcript)
    if len(sys.argv) == 3 and sys.argv[1] == "--record":
        with open(sys.argv[2], "w") as handle:
            handle.write(output)
        print(f"recorded {len(transcript)} steps to {sys.argv[2]}")
    elif len(sys.argv) == 3 and sys.argv[1] == "--check":
        with open(sys.argv[2]) as handle:
            expected = handle.read()
        if expected == output:
            print(f"protocol: {len(transcript)} steps match")
            return
        wanted, got = expected.splitlines(), output.splitlines()
        for index in range(max(len(wanted), len(got))):
            left = wanted[index] if index < len(wanted) else "<missing>"
            right = got[index] if index < len(got) else "<missing>"
            if left != right:
                print(f"step {index + 1} differs\n  expected: {left}\n  got:      {right}")
        raise SystemExit(1)
    else:
        sys.stdout.write(output)


main()
