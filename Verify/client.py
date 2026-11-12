import os
import sys
import threading
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Integrations"))

from niche import Niche, NicheError


def expect(actual, expected, what):
    if actual != expected:
        raise SystemExit(f"client: {what}\n  expected: {expected}\n  got:      {actual}")


def main():
    niche = Niche()
    events, intents = [], []
    arrived = threading.Event()

    def record(event):
        if event.get("id") == "client-check":
            events.append(event["event"])

    def intent(name, event):
        intents.append((name, event.get("value")))
        arrived.set()

    def broken(event):
        raise RuntimeError("a failing handler must not stop the others")

    niche.subscribe(broken)
    niche.subscribe(record)
    niche.on_intent("client-check", intent)

    try:
        niche.request(id="client-check", dynamicIsland={"minimal": {"type": "Nope"}})
        refused = None
    except NicheError as error:
        refused = str(error)
    expect(refused, "minimal.type: Cannot initialize Kind from invalid String value Nope", "a refused request raises")

    identifier = niche.request(id="client-check", bound=True, content={"state": {"n": 1}},
                               dynamicIsland={"minimal": {"type": "Text", "text": "n={{state.n}}"}})
    niche.update(identifier, content={"state": {"n": 2}})
    expect([activity["id"] for activity in niche.activities()], ["client-check"], "activities lists the request")

    if not arrived.wait(5):
        raise SystemExit("client: no intent arrived")
    niche.end(identifier, dismissalPolicy="immediate")
    time.sleep(0.2)

    expect(intents, [("ping", 2.5)], "the intent handler gets its own activity's intents")
    expect(events, ["activityUpdate", "contentUpdate", "intent", "activityStateUpdate", "activityStateUpdate"],
           "subscribers see every event in order")
    print("client: ok")


main()
