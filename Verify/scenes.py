import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "Integrations"))

from niche import Niche

PANEL = os.path.join(ROOT, "build", "verify", "panel")
BASELINE = os.path.join(HERE, "baseline")


def text(value, **fields):
    return {"type": "Text", "text": value, **fields}


def symbol(name, **fields):
    return {"type": "Image", "systemName": name, **fields}


def button(title=None, **fields):
    return {"type": "Button", "intent": "pin", **({"title": title} if title else {}), **fields}


def stack(kind, children, **fields):
    return {"type": kind, "children": children, **fields}


ICON = {"type": "Image", "app": "com.apple.finder"}

COMPACT = {
    "compact-both": {
        "compactLeading": stack("HStack", [symbol("bolt.fill", foregroundStyle="orange"),
                                           text("Build", font={"style": "caption", "weight": "semibold"})], spacing=4),
        "compactTrailing": {"type": "ProgressView", "value": 0.6, "progressViewStyle": "circular", "tint": "green"},
    },
    "compact-trailing-long": {
        "compactTrailing": text("A very long trailing label that is cut off", font="footnote"),
    },
    "compact-icon-label": {
        "compactLeading": {**ICON, "frame": {"width": 22, "height": 22}, "cornerRadius": 5},
        "compactTrailing": {"type": "Label", "title": "3", "systemImage": "bell.fill", "font": "footnote",
                            "foregroundStyle": "yellow"},
    },
    "compact-margins-conditions": {
        "compactLeading": stack("ZStack", [text("stale", **{"if": "{{isStale}}"}),
                                           text("{{state.count}} left", unless="{{isStale}}",
                                                font={"size": 13, "design": "rounded", "weight": "bold"})]),
        "compactTrailing": {"type": "AudioBars", "isActive": False, "tint": "#1ED760"},
        "contentMargins": [{"edges": "leading", "length": 14, "for": "compactLeading"},
                           {"edges": "all", "length": 2, "for": "compactTrailing"}],
    },
}

EXPANDED = {
    "expanded-regions": {
        "expanded": {
            "leading": {"type": "Label", "title": "Timer", "systemImage": "timer", "font": "footnote",
                        "foregroundStyle": "orange"},
            "trailing": text("12:34", monospacedDigit=True, font={"style": "footnote", "weight": "medium"},
                             foregroundStyle="secondary"),
            "center": stack("VStack", [text("Title of the thing", font="headline"),
                                       text("A subtitle underneath", font="subheadline",
                                            foregroundStyle="secondary")], spacing=2),
            "bottom": stack("HStack", [
                button("Bordered"),
                button("Prominent", buttonStyle="borderedProminent", tint="green"),
                button(buttonStyle="plain", systemImage="play.fill", font={"size": 20},
                       frame={"width": 40, "height": 40}),
                {"type": "Toggle", "intent": "mute", "isOn": True, "systemImage": "speaker.slash.fill"},
                {"type": "Toggle", "intent": "mute", "isOn": False, "title": "Off", "buttonStyle": "plain"},
                {"type": "Link", "destination": "niche-pin://x", "title": "Link", "foregroundStyle": "cyan"},
            ], spacing=8),
        },
    },
    "expanded-controls": {
        "expanded": {
            "bottom": stack("VStack", [
                {"type": "ProgressView", "value": 0.4, "tint": "orange", "frame": {"maxWidth": "infinity"}},
                stack("HStack", [
                    {"type": "ProgressView", "value": 3, "total": 4, "progressViewStyle": "circular",
                     "frame": {"width": 28, "height": 28}},
                    {"type": "Slider", "value": 30, "total": 100, "intent": "seek", "frame": {"maxWidth": "infinity"}},
                    {"type": "AudioBars", "isActive": False, "frame": {"width": 24, "height": 18}},
                ], spacing=12),
                stack("HStack", [
                    text("mono 0123", font={"design": "monospaced", "size": 12}),
                    {"type": "Spacer"},
                    text("serif", font={"design": "serif", "weight": "heavy", "size": 14}),
                    {"type": "Spacer", "minLength": 20},
                    text("tracked", tracking=3, font="caption2", foregroundStyle="tertiary"),
                ]),
                stack("ZStack", [
                    text("background", padding=[10, 4], background="#FF453A80", cornerRadius=8, opacity=0.8),
                    symbol("star.fill", foregroundStyle="yellow", font={"size": 10}),
                ], alignment="bottomTrailing"),
                text("Two lines of text that wrap because the line limit is two and the text is long enough "
                     "to need it", lineLimit=2, font="caption", frame={"maxWidth": "infinity", "alignment": "leading"}),
            ], spacing=6, alignment="leading"),
        },
    },
    "expanded-priority": {
        "contentMargins": [{"edges": "horizontal", "length": 30, "for": "expanded"},
                           {"edges": "bottom", "length": 6, "for": "expanded"}],
        "expanded": {
            "leading": text("A leading region with priority that takes the full width", priority=1, font="callout",
                            lineLimit=1),
            "trailing": text("Trailing placed below when too wide", verticalPlacement="belowIfTooWide",
                             font="footnote", foregroundStyle="mint", contentMargins=[0, 0, 0, 12]),
            "center": text("Center", font="title3"),
            "bottom": text("Bottom", font="caption", foregroundStyle="indigo"),
        },
    },
    "expanded-sides-tall": {
        "expanded": {
            "leading": stack("VStack", [{**ICON, "frame": {"width": 44, "height": 44}},
                                        text("Left", font="caption2")], spacing=2),
            "trailing": stack("VStack", [symbol("airpodspro", font={"size": 30}, foregroundStyle="teal"),
                                         text("Right", font="caption2")], spacing=2),
            "center": text("Between", font="title2"),
        },
    },
    "expanded-minimum": {
        "expanded": {"center": text("Small", font="caption")},
    },
    "expanded-maximum": {
        "expanded": {"bottom": stack("VStack", [text(f"Row {row}", font="title") for row in range(1, 8)])},
    },
    "expanded-player": {
        "contentMargins": [{"edges": "horizontal", "length": 20, "for": "expanded"},
                           {"edges": "bottom", "length": 20, "for": "expanded"}],
        "expanded": {
            "leading": stack("HStack", [{**ICON, "frame": {"width": 16, "height": 16}},
                                        text("Player", font={"style": "footnote", "weight": "medium"},
                                             foregroundStyle="secondary")], spacing=6),
            "trailing": {"type": "AudioBars", "isActive": False, "tint": "#1ED760",
                         "frame": {"width": 20, "height": 16}},
            "bottom": stack("HStack", [
                {**ICON, "contentMode": "fill", "frame": {"width": 112, "height": 112}, "cornerRadius": 14},
                stack("VStack", [
                    stack("VStack", [text("{{state.title}}", lineLimit=1,
                                          font={"style": "subheadline", "weight": "semibold"}),
                                     text("{{state.artist}}", lineLimit=1, font="subheadline",
                                          foregroundStyle="secondary")],
                          alignment="leading", spacing=1, frame={"maxWidth": "infinity", "alignment": "leading"}),
                    {"type": "Spacer"},
                    stack("HStack", [
                        button(buttonStyle="plain", systemImage="backward.fill", font={"size": 18},
                               frame={"width": 40, "height": 40}),
                        button(buttonStyle="plain", systemImage="pause.fill", font={"size": 26},
                               frame={"width": 40, "height": 40}),
                        button(buttonStyle="plain", systemImage="forward.fill", font={"size": 18},
                               frame={"width": 40, "height": 40}),
                    ], spacing=18, frame={"maxWidth": "infinity"}),
                    {"type": "Spacer"},
                    {"type": "Slider", "intent": "seek", "value": "{{state.position}}", "total": "{{state.duration}}",
                     "frame": {"maxWidth": "infinity"}},
                    stack("HStack", [
                        text("1:05", font={"style": "caption", "weight": "semibold"}, monospacedDigit=True,
                             foregroundStyle="secondary"),
                        {"type": "Spacer"},
                        text("2:55", font={"style": "caption", "weight": "semibold"}, monospacedDigit=True,
                             foregroundStyle="secondary"),
                    ]),
                ], alignment="leading", spacing=0, frame={"height": 112, "maxWidth": "infinity"}),
            ], spacing=16, padding=[4, 0, 0, 0]),
        },
    },
}

STATE = {"count": 4, "title": "A song title that is fairly long", "artist": "The artist", "position": 65,
         "duration": 240}


def connect(seconds):
    deadline = time.time() + seconds
    while True:
        try:
            niche = Niche()
            if panel("window").returncode == 0:
                return niche
        except OSError:
            pass
        if time.time() > deadline:
            raise SystemExit("Niche is not running; start it with make run")
        time.sleep(0.5)


def panel(*arguments):
    return subprocess.run([PANEL, *arguments], capture_output=True, text=True)


def pointer_is_clear():
    return panel("pointer").stdout.strip() == "clear"


def capture(folder, name):
    window = panel("window")
    if window.returncode != 0:
        raise SystemExit(window.stderr.strip())
    subprocess.run(["screencapture", "-x", "-o", "-l", window.stdout.strip(), os.path.join(folder, name + ".png")],
                   check=True)


def settled_capture(folder, name, settle):
    for attempt in range(5):
        while not pointer_is_clear():
            time.sleep(1)
        time.sleep(settle)
        if pointer_is_clear():
            capture(folder, name)
            return
    raise SystemExit(f"the pointer kept entering the notch area during {name}")


def matches(folder, name):
    expected = os.path.join(BASELINE, name + ".png")
    return not os.path.exists(expected) or panel("diff", expected, os.path.join(folder, name + ".png")).returncode == 0


def compare(folder, names):
    failed = []
    for name in names:
        expected = os.path.join(BASELINE, name + ".png")
        if not os.path.exists(expected):
            failed.append(f"{name}: no baseline; run make baseline and look at the new screenshot")
            continue
        result = panel("diff", expected, os.path.join(folder, name + ".png"))
        if result.returncode != 0:
            failed.append(f"{name}: {(result.stdout or result.stderr).strip()} pixels differ")
    if failed:
        print("\n".join(failed))
        raise SystemExit(f"scenes: {len(failed)} of {len(names)} fail; new captures are in {folder}")
    print(f"scenes: {len(names)} match the baseline")


def record(folder, names):
    added = [name for name in names if not os.path.exists(os.path.join(BASELINE, name + ".png"))]
    for name in added:
        shutil.copy(os.path.join(folder, name + ".png"), os.path.join(BASELINE, name + ".png"))
    print(f"scenes: recorded {len(added)} new ({', '.join(added) or 'none'}); "
          f"to record a scene again, delete its file in {BASELINE} first")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode not in ("check", "record"):
        raise SystemExit("usage: scenes.py check | record")
    folder = os.path.join(ROOT, "build", "verify", "scenes")
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder, exist_ok=True)
    os.makedirs(BASELINE, exist_ok=True)
    niche = connect(20)
    time.sleep(1)

    for attempt in range(20):
        others = [a["id"] for a in niche.activities() if not a["id"].startswith("pin-")]
        if not others:
            break
        time.sleep(0.5)
    else:
        raise SystemExit(f"other activities are showing ({', '.join(others)}); stop their integrations first")
    for name, island in COMPACT.items():
        for attempt in range(3):
            niche.request(id="pin-scene", bound=True, dynamicIsland=island, content={"state": STATE})
            settled_capture(folder, name, 1.6)
            if matches(folder, name):
                break

    niche.request(id="pin-scene", bound=True, content={"relevanceScore": 1},
                  dynamicIsland={"minimal": symbol("bolt.fill", foregroundStyle="orange"),
                                 "compactLeading": text("unused")})
    niche.request(id="pin-second", bound=True, content={"relevanceScore": 9},
                  dynamicIsland={"compactLeading": text("12", font={"style": "footnote", "weight": "bold"},
                                                        foregroundStyle="green")})
    settled_capture(folder, "minimal-detached", 1.6)
    niche.end("pin-second", dismissalPolicy="immediate")
    niche.end("pin-scene", dismissalPolicy="immediate")
    settled_capture(folder, "empty", 1.0)

    for name, island in EXPANDED.items():
        island = {"compactLeading": symbol("circle.fill", foregroundStyle="blue"), **island}
        for attempt in range(4):
            while not pointer_is_clear():
                time.sleep(1)
            niche.request(id="pin-scene", bound=True, dynamicIsland=island, content={"state": STATE},
                          alertConfiguration={"title": name, "sound": "pin-silent"})
            time.sleep(1.9)
            clear = pointer_is_clear()
            if clear:
                capture(folder, name)
            niche.end("pin-scene", dismissalPolicy="immediate")
            time.sleep(1.0)
            if clear and matches(folder, name):
                break

    names = [*COMPACT, "minimal-detached", "empty", *EXPANDED]
    if mode == "record":
        record(folder, names)
    else:
        compare(folder, names)


main()
