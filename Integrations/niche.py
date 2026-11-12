import json
import os
import queue
import socket
import threading
import traceback

SOCKET = os.environ.get("NICHE_SOCKET", os.path.expanduser("~/Library/Application Support/Niche/niche.sock"))


class NicheError(Exception):
    pass


class NicheClosed(Exception):
    pass


class Niche:
    def __init__(self, path=SOCKET):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(path)
        self.closed = threading.Event()
        self.replies = queue.Queue()
        self.events = queue.Queue()
        self.handlers = []
        self.close_handlers = []
        self.lock = threading.Lock()
        threading.Thread(target=self._read, daemon=True).start()
        threading.Thread(target=self._dispatch, daemon=True).start()

    def send(self, op, **fields):
        with self.lock:
            try:
                self.sock.sendall(json.dumps({"op": op, **fields}).encode() + b"\n")
            except OSError:
                raise NicheClosed() from None
            reply = self.replies.get()
        if reply is None:
            self.replies.put(None)
            raise NicheClosed()
        if not reply["ok"]:
            raise NicheError(reply["error"])
        return reply

    def request(self, **fields):
        return self.send("request", **fields)["id"]

    def update(self, id, **fields):
        self.send("update", id=id, **fields)

    def end(self, id, **fields):
        self.send("end", id=id, **fields)

    def configure(self, attributes_type, dynamic_island):
        self.send("configure", **{"for": attributes_type, "dynamicIsland": dynamic_island})

    def activities(self):
        return self.send("activities")["activities"]

    def subscribe(self, handler):
        self.handlers.append(handler)
        if len(self.handlers) == 1:
            self.send("subscribe")

    def on_intent(self, id, handler):
        def filtered(event):
            if event.get("event") == "intent" and event.get("id") == id:
                handler(event["intent"], event)

        self.subscribe(filtered)

    def on_close(self, handler):
        self.close_handlers.append(handler)

    def _read(self):
        try:
            for line in self.sock.makefile("r"):
                message = json.loads(line)
                (self.replies if "ok" in message else self.events).put(message)
        except (OSError, ValueError):
            pass
        finally:
            self.closed.set()
            self.replies.put(None)
            self.events.put(None)
            for handler in self.close_handlers:
                handler()

    def _dispatch(self):
        while (event := self.events.get()) is not None:
            for handler in self.handlers:
                try:
                    handler(event)
                except Exception:
                    traceback.print_exc()
