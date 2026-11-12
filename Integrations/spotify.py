import os
import subprocess
import threading
import time

from niche import Niche, NicheClosed, NicheError

GREEN = "#1ED760"

QUERY = """
if application "Spotify" is not running then return ""
tell application "Spotify"
    if player state is stopped then return ""
    set t to current track
    return (id of t) & linefeed & (name of t) & linefeed & (artist of t) & linefeed & (artwork url of t) & linefeed & (duration of t) & linefeed & (player position) & linefeed & (player state as text)
end tell
"""


def cover(side, radius):
    frame = {"width": side, "height": side}
    return {"type": "ZStack", "children": [
        {"type": "Image", "source": "{{state.art}}", "contentMode": "fill", "frame": frame,
         "cornerRadius": radius, "if": "{{state.hasArt}}"},
        {"type": "Image", "app": "com.spotify.client", "frame": frame, "unless": "{{state.hasArt}}"},
    ]}


def bars(width, height):
    return {"type": "AudioBars", "isActive": "{{state.playing}}", "tint": GREEN,
            "frame": {"width": width, "height": height}}


def time_label(timer_counts_down, paused_text):
    style = {"font": {"style": "caption", "weight": "semibold"}, "monospacedDigit": True,
             "foregroundStyle": "secondary"}
    return {"type": "ZStack", "children": [
        {"type": "Text", "timerInterval": "{{state.interval}}", "countsDown": timer_counts_down,
         "if": "{{state.playing}}", **style},
        {"type": "Text", "text": paused_text, "unless": "{{state.playing}}", **style},
    ]}


def control(intent, symbol, font):
    return {"type": "Button", "intent": intent, "systemImage": symbol, "buttonStyle": "plain", "font": font,
            "frame": {"width": 40, "height": 40}}


COVER = 112

ISLAND = {
    "compactLeading": cover(24, 6),
    "compactTrailing": bars(18, 14),
    "minimal": cover(24, 6),
    "contentMargins": [
        {"edges": "horizontal", "length": 20, "for": "expanded"},
        {"edges": "bottom", "length": 20, "for": "expanded"},
    ],
    "expanded": {
        "leading": {"type": "HStack", "spacing": 6, "children": [
            {"type": "Image", "app": "com.spotify.client", "frame": {"width": 16, "height": 16}},
            {"type": "Text", "text": "Spotify", "font": {"style": "footnote", "weight": "medium"},
             "foregroundStyle": "secondary"},
        ]},
        "trailing": bars(20, 16),
        "bottom": {"type": "HStack", "spacing": 16, "padding": [4, 0, 0, 0], "children": [
            {"type": "Link", "destination": "spotify:", "children": [cover(COVER, 14)]},
            {"type": "VStack", "alignment": "leading", "spacing": 0,
             "frame": {"height": COVER, "maxWidth": "infinity"}, "children": [
                 {"type": "VStack", "alignment": "leading", "spacing": 1,
                  "frame": {"maxWidth": "infinity", "alignment": "leading"}, "children": [
                      {"type": "Text", "text": "{{state.title}}", "lineLimit": 1,
                       "font": {"style": "subheadline", "weight": "semibold"}},
                      {"type": "Text", "text": "{{state.artist}}", "lineLimit": 1,
                       "font": "subheadline", "foregroundStyle": "secondary"},
                  ]},
                 {"type": "Spacer"},
                 {"type": "HStack", "spacing": 18, "frame": {"maxWidth": "infinity"}, "children": [
                     control("previous", "backward.fill", {"size": 18}),
                     control("playPause", "{{state.icon}}", {"size": 26}),
                     control("next", "forward.fill", {"size": 18}),
                 ]},
                 {"type": "Spacer"},
                 {"type": "Slider", "intent": "seek", "timerInterval": "{{state.interval}}",
                  "value": "{{state.position}}", "total": "{{state.duration}}",
                  "frame": {"maxWidth": "infinity"}},
                 {"type": "HStack", "children": [
                     time_label(False, "{{state.elapsed}}"),
                     {"type": "Spacer"},
                     time_label(True, "{{state.remaining}}"),
                 ]},
             ]},
        ]},
    },
}


def osascript(script):
    try:
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=5)
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return ""


def spotify(command):
    osascript(f'tell application "Spotify" to {command}')


def clock(seconds):
    minutes, seconds = divmod(max(0, int(seconds)), 60)
    return f"{minutes}:{seconds:02d}"


def read():
    parts = osascript(QUERY).split("\n")
    if len(parts) < 7:
        return None

    track, title, artist, art, duration, position, status = parts[:7]
    duration = float(duration.replace(",", ".")) / 1000
    position = float(position.replace(",", "."))
    playing = status == "playing"
    start = time.time() - position
    return {
        "track": track,
        "start": start,
        "state": {
            "title": title,
            "artist": artist,
            "art": art,
            "hasArt": art.startswith("http"),
            "playing": playing,
            "icon": "pause.fill" if playing else "play.fill",
            "interval": [start, start + duration] if playing else None,
            "position": position,
            "duration": duration,
            "elapsed": clock(position),
            "remaining": clock(duration - position),
        },
    }


def changed(previous, current):
    if previous is None:
        return True
    if previous["track"] != current["track"] or previous["state"]["playing"] != current["state"]["playing"]:
        return True
    if current["state"]["playing"]:
        return abs(previous["start"] - current["start"]) > 1.5
    return abs(previous["state"]["position"] - current["state"]["position"]) > 0.5


def perform(intent, event):
    if intent == "playPause":
        spotify("playpause")
    elif intent == "next":
        spotify("next track")
    elif intent == "previous":
        spotify("previous track")
    elif intent == "seek":
        spotify(f"set player position to {float(event.get('value', 0)):.2f}")


def main():
    niche = Niche()
    refresh = threading.Event()

    def handle(intent, event):
        perform(intent, event)
        refresh.set()

    niche.on_close(lambda: os._exit(0))
    niche.on_intent("spotify", handle)

    shown = None
    while True:
        current = read()
        try:
            if current is None and shown is not None:
                niche.end("spotify", dismissalPolicy="immediate")
            elif current is not None and shown is None:
                niche.request(id="spotify", bound=True, attributesType="Spotify",
                              content={"state": current["state"]}, dynamicIsland=ISLAND)
            elif current is not None and changed(shown, current):
                niche.update("spotify", content={"state": current["state"]})
            else:
                current = shown
        except NicheError:
            pass
        shown = current

        if refresh.wait(1.0):
            refresh.clear()
            time.sleep(0.15)


try:
    main()
except NicheClosed:
    pass
