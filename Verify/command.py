import json
import os
import socket
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NICHE = os.environ.get("NICHE_COMMAND", os.path.join(ROOT, ".build", "debug", "NicheCLI"))


def normalize(value):
    if isinstance(value, dict):
        return {key: normalize(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, (int, float)) and not isinstance(value, bool) and value > 1e9:
        return "<time>"
    return value


class FakeNiche:
    def __init__(self, path):
        self.requests = []
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(path)
        self.server.listen(4)
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while True:
            connection, _ = self.server.accept()
            threading.Thread(target=self.serve, args=(connection,), daemon=True).start()

    def serve(self, connection):
        reader = connection.makefile("r")
        for line in reader:
            try:
                request = json.loads(line)
            except json.JSONDecodeError:
                request = {"unparsed": line.strip()}
            self.requests.append(request)

            if request.get("id") == "refuse":
                reply = {"ok": False, "error": "refused by the fake"}
            elif request.get("op") == "activities":
                reply = {"ok": True, "activities": [{"id": "one", "activityState": "active", "content": {},
                                                     "attributes": {"url": "https://example.com/a"}}]}
            else:
                reply = {"ok": True, "id": request.get("id", "generated-id")}
            connection.sendall(json.dumps(reply).encode() + b"\n")

            if request.get("op") == "subscribe":
                connection.sendall(b'{"event":"intent","id":"one","intent":"go"}\n')
                connection.close()
                return
        connection.close()


def main():
    folder = tempfile.mkdtemp(prefix="niche-pin-")
    path = os.path.join(folder, "s.sock")
    fake = FakeNiche(path)

    island = os.path.join(folder, "island.json")
    with open(island, "w") as handle:
        json.dump({"minimal": {"type": "Text", "text": "from file"}}, handle)

    cases = [
        [],
        ["help"],
        ["--help"],
        ["nope"],
        ["request"],
        ["request", "--id", "a", "--type", "Delivery", "--attributes", '{"items":3}', "--state", '{"minutes":12}',
         "--staleDate", "+60", "--relevanceScore", "50", "--start", "+5"],
        ["request", "--compactLeading", "symbol:hammer.fill;foregroundStyle=orange", "--compactTrailing", "text:3/10",
         "--minimal", "ring:0.6;tint=green;frame.width=18"],
        ["request", "--leading", "app:com.apple.Music", "--trailing", "bars", "--center", "text:Hello: world",
         "--bottom", "progress:0.25", "--widgetURL", "myapp://x"],
        ["request", "--compactLeading", "image:~/cover.png;cornerRadius=6", "--compactTrailing", "timer:90"],
        ["request", "--compactLeading", "stopwatch", "--compactTrailing", "video:~/clip.mp4",
         "--minimal", "web:https://example.com"],
        ["request", "--compactLeading", '{"type":"Text","text":"raw"}', "--minimal", "@" + island],
        ["request", "--dynamicIsland", "@" + island, "--compactLeading", "text:after"],
        ["request", "--compactLeading", "text:before", "--dynamicIsland", '{"compactLeading":{"type":"Spacer"}}'],
        ["request", "--alert", "Title", "--body", "Body", "--sound", "Pop", "--compactLeading", "text:x"],
        ["request", "--compactLeading", "text:x;isActive=true;opacity=0.5;lineLimit=2;font.weight=bold"],
        ["request", "--compactLeading", "bogus:1"],
        ["request", "--compactLeading", "text:x;novalue"],
        ["request", "--compactLeading"],
        ["request", "--frobnicate", "1"],
        ["request", "--state", "not json"],
        ["request", "--state", "[1]"],
        ["request", "--state", "@/nonexistent/file.json"],
        ["request", "--relevanceScore", "high"],
        ["request", "--staleDate", "tomorrow"],
        ["request", "--id", "refuse", "--compactLeading", "text:x"],
        ["update"],
        ["update", "a", "--state", '{"minutes":8}', "--alert", "Almost there", "--body", "8 minutes away"],
        ["update", "a", "--compactTrailing", "text:4/10", "--timestamp", "1794500000"],
        ["update", "a", "--timestamp", "+1"],
        ["end"],
        ["end", "a"],
        ["end", "a", "--state", '{"minutes":0}', "--dismissalPolicy", "after:+10"],
        ["end", "a", "--dismissalPolicy", "immediate"],
        ["end", "a", "--dismissalPolicy", "default"],
        ["end", "a", "--dismissalPolicy", "after:1794500600"],
        ["end", "a", "--dismissalPolicy", "after:soon"],
        ["end", "refuse"],
        ["configure"],
        ["configure", "Delivery"],
        ["configure", "Delivery", "@" + island],
        ["configure", "Delivery", '{"compactLeading":{"type":"Text","text":"{{state.minutes}}"}}'],
        ["configure", "Delivery", "nope"],
        ["haptic"],
        ["haptic", "3"],
        ["haptic", "strong"],
        ["activities"],
        ["info"],
        ["send"],
        ["send", '{"op":"info"}'],
        ["send", "@" + island],
        ["send", "nope"],
        ["events"],
        ["raw"],
        ["end", "a", "--dismissalPolicy", "bogus"],
        ["haptic", "99999999999"],
        ["send", '{"op":"haptic","strength":12345678901234567890}'],
        ["request", "--compactLeading", "text:x;value=1e3;isOn=false"],
    ]
    absent = [
        ["info"],
        ["request", "--frobnicate", "1"],
        ["request", "--state", "nope"],
        ["end", "a", "--dismissalPolicy", "bogus"],
        ["configure", "Delivery", "nope"],
        ["send", "nope"],
        ["update"],
    ]

    results = []
    for arguments in cases:
        before = len(fake.requests)
        completed = subprocess.run(
            [NICHE, *arguments],
            input='{"op":"info"}\n{"op":"activities"}\n' if arguments == ["raw"] else "",
            capture_output=True, text=True, timeout=10, env={**os.environ, "NICHE_SOCKET": path},
        )
        shown = [argument.replace(folder, "<tmp>") for argument in arguments]
        results.append(normalize({
            "arguments": shown,
            "status": completed.returncode,
            "stdout": completed.stdout.replace(folder, "<tmp>"),
            "stderr": completed.stderr.replace(folder, "<tmp>"),
            "requests": fake.requests[before:],
        }))

    for arguments in absent:
        missing = subprocess.run([NICHE, *arguments], capture_output=True, text=True,
                                 env={**os.environ, "NICHE_SOCKET": os.path.join(folder, "absent.sock")})
        results.append({"arguments": arguments, "socket": "absent", "status": missing.returncode,
                        "stdout": missing.stdout, "stderr": missing.stderr.replace(folder, "<tmp>")})

    output = "".join(json.dumps(result, sort_keys=True) + "\n" for result in results)
    if len(sys.argv) == 3 and sys.argv[1] == "--record":
        with open(sys.argv[2], "w") as handle:
            handle.write(output)
        print(f"recorded {len(results)} invocations to {sys.argv[2]}")
    elif len(sys.argv) == 3 and sys.argv[1] == "--check":
        with open(sys.argv[2]) as handle:
            expected = handle.read().splitlines()
        got = output.splitlines()
        different = [index for index in range(max(len(expected), len(got)))
                     if (expected[index] if index < len(expected) else None) != (got[index] if index < len(got) else None)]
        if not different:
            print(f"command: {len(results)} invocations match")
            return
        for index in different:
            print(f"invocation {index + 1} differs\n  expected: {expected[index] if index < len(expected) else '<missing>'}"
                  f"\n  got:      {got[index] if index < len(got) else '<missing>'}")
        raise SystemExit(1)
    else:
        sys.stdout.write(output)


main()
