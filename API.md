# Niche API

Niche's API mirrors Apple's Live Activities API: ActivityKit for the lifecycle and WidgetKit's `DynamicIsland` for the presentation. Names, fields and behaviour follow Apple's, carried as JSON over a local socket so any language can use it.

- Socket: `~/Library/Application Support/Niche/niche.sock`, one JSON object per line each way (`NICHE_SOCKET` overrides the path)
- Command: `niche`, installed to `~/.local/bin` by `make install`

## How Apple's API maps

| Apple | Niche |
| --- | --- |
| `Activity.request(attributes:content:pushType:style:alertConfiguration:start:)` | `{"op":"request", …}` |
| `activity.update(_:alertConfiguration:timestamp:)` | `{"op":"update", …}` |
| `activity.end(_:dismissalPolicy:timestamp:)` | `{"op":"end", …}` |
| `Activity.activities` | `{"op":"activities"}` |
| `activityUpdates`, `activityStateUpdates`, `contentUpdates` | events after `{"op":"subscribe"}` |
| `ActivityContent(state:staleDate:relevanceScore:)` | `"content": {"state", "staleDate", "relevanceScore"}` |
| `AlertConfiguration(title:body:sound:)` | `"alertConfiguration": {"title", "body", "sound"}` |
| `ActivityUIDismissalPolicy` | `"dismissalPolicy": "default"`, `"immediate"` or `{"after": time}` |
| `ActivityState` | `pending`, `active`, `stale`, `ended`, `dismissed` |
| `ActivityAuthorizationInfo().areActivitiesEnabled` | `{"op":"info"}` |
| `ActivityConfiguration(for:) { … } dynamicIsland: { … }` | `{"op":"configure","for":…,"dynamicIsland":…}` |
| `DynamicIsland { expanded } compactLeading: compactTrailing: minimal:` | the `dynamicIsland` object |
| `DynamicIslandExpandedRegion(.leading / .trailing / .center / .bottom)` | `expanded.leading`, `.trailing`, `.center`, `.bottom` |
| `.widgetURL`, `.contentMargins(_:_:for:)` | fields of `dynamicIsland` |
| `DynamicIslandExpandedRegion(_:priority:)`, `.dynamicIsland(verticalPlacement: .belowIfTooWide)`, region `.contentMargins` | `priority`, `verticalPlacement`, `contentMargins` on the region's root view |
| `ActivityViewContext` (`state`, `attributes`, `activityID`, `isStale`) | `{{state.x}}`, `{{attributes.x}}`, `{{activityID}}`, `{{isStale}}` |
| `Button(intent:)`, `Toggle(isOn:intent:)`, `Link(destination:)` | views of the same name; intents arrive as events |

Dates are Unix seconds, as in Apple's push payloads.

## Lifecycle

```json
{"op":"configure","for":"Delivery","dynamicIsland":{ … }}

{"op":"request","attributesType":"Delivery","attributes":{"items":3},
 "content":{"state":{"minutes":12},"staleDate":1794500000,"relevanceScore":50}}
→ {"ok":true,"id":"B0EFE326-…"}

{"op":"update","id":"B0EFE326-…","content":{"state":{"minutes":8}},
 "alertConfiguration":{"title":"Almost there","body":"8 minutes away","sound":"default"}}

{"op":"end","id":"B0EFE326-…","content":{"state":{"minutes":0}},"dismissalPolicy":{"after":1794500600}}
```

Every request gets one reply line, `{"ok":true,…}` or `{"ok":false,"error":"…"}`.

- **request** starts an activity. It uses the `dynamicIsland` registered for its `attributesType`, or one passed inline as `"dynamicIsland"`. `start` in the future leaves it `pending` until then.
- **update** replaces the content and re-renders. With `alertConfiguration` the island expands for a few seconds, plays the sound and taps the trackpad. An update whose `timestamp` is older than the last one is ignored.
- **end** marks it `ended`. `default` and `immediate` remove it at once, as the Dynamic Island does; `{"after": time}` keeps the final content in the notch until then (four hours at most).
- **staleDate** passing moves it to `stale` and re-renders with `{{isStale}}` true. An update with a later or no `staleDate` makes it `active` again.

### Events

After `{"op":"subscribe"}` the connection receives:

```json
{"event":"activityUpdate","id":"…","activityState":"active","content":{…}}
{"event":"contentUpdate","id":"…","content":{…}}
{"event":"activityStateUpdate","id":"…","activityState":"stale"}
{"event":"intent","id":"…","intent":"callDriver"}
{"event":"intent","id":"…","intent":"mute","isOn":true}
{"event":"intent","id":"…","intent":"seek","value":43.7}
{"event":"openURL","id":"…","url":"https://…"}
```

## DynamicIsland

```json
{
  "compactLeading": View,
  "compactTrailing": View,
  "minimal": View,
  "expanded": {"leading": View, "trailing": View, "center": View, "bottom": View},
  "widgetURL": "myapp://order/12",
  "contentMargins": [{"edges": "trailing", "length": 8, "for": "expanded"}]
}
```

`contentMargins` takes `edges` (`all`, `horizontal`, `vertical`, `top`, `bottom`, `leading`, `trailing`) and `for` (`expanded`, `compactLeading`, `compactTrailing`, `minimal`).

The system decides the presentation, as on iPhone:

- **Compact**: one activity. `compactLeading` and `compactTrailing` sit either side of the notch, each side as wide as its content.
- **Minimal**: two or more. The most relevant one is attached to the notch with its `minimal` view (37–45 pt wide); the next one is a detached circle to the right. Order is by `relevanceScore`, then most recent.
- **Expanded**: press and hold the notch, or an alert arrives. `leading` and `trailing` flank the notch, `center` sits under it, `bottom` under everything. It is 84–200 pt tall, sized to its content (Apple stops at 160), with Apple's 44 pt corners, and closes when the pointer leaves. A side region with the highest `priority` gets the full width under the notch.
- **Tap** opens `widgetURL`. Tapping empty space in the expanded view does the same.

The look follows iOS: black background, white text, the iOS text styles (`body` is 17 pt and the default), the iOS dark-mode system colours, and blue as the default tint.

## Views

Views are JSON objects named after their SwiftUI counterparts.

| `type` | Fields |
| --- | --- |
| `Text` | `text`; or `timerInterval` `[start, end]` with `countsDown`; or `date` with `style` (`timer`, `relative`, `offset`, `time`, `date`) |
| `Image` | `systemName`; or `source` (file path or http URL); or `app` (bundle id, its icon); `contentMode` (`fit`, `fill`) |
| `Label` | `title`, `systemImage` |
| `ProgressView` | `value`, `total`; or `timerInterval` with `countsDown`; `progressViewStyle` (`linear`, `circular`), `tint` |
| `HStack`, `VStack`, `ZStack` | `children`, `spacing`, `alignment` |
| `Spacer` | `minLength` |
| `Button` | `intent`, and `children` or `title` and/or `systemImage`; `buttonStyle` (`bordered` by default, `borderedProminent`, `plain`), `tint` |
| `Toggle` | `isOn`, `intent`, and a label like `Button` |
| `Link` | `destination`, and a label like `Button` |

Modifiers, as fields on any view: `font` (a text style such as `"headline"`, or `{"size", "weight", "design"}`), `foregroundStyle`, `lineLimit`, `monospacedDigit`, `symbolEffect` (`pulse`, `variableColor`), `frame` (`width`, `height`, `maxWidth`, `maxHeight`, `alignment`; `"infinity"` is allowed for the max values), `padding` (a number, `[horizontal, vertical]` or `[top, leading, bottom, trailing]`), `background`, `cornerRadius`, `opacity`, `blur`, `scaleEffect`, `tracking`, `layoutPriority`.

Colors are SwiftUI names (`orange`, `secondary`, `accentColor`, …) or `#RRGGBB` / `#RRGGBBAA`.

### Context

Where Apple's view closure reads `context`, a view here uses placeholders, filled in on every update:

```json
{"type": "Text", "text": "{{state.driver}} is {{state.minutes}} min away"}
{"type": "ProgressView", "value": "{{state.progress}}"}
{"type": "Text", "text": "Reconnecting…", "if": "{{isStale}}"}
```

A string that is only a placeholder takes the value's own type, so numbers and booleans work in typed fields. `if` and `unless` show or hide a view.

## Where it differs from Apple

Not possible to copy literally:

- **Views are data, not compiled SwiftUI.** Apple's views live in a widget extension inside the app. Here they are the JSON above, limited to the listed views and modifiers.
- **Intents come back as events.** `Button(intent:)` cannot run an App Intent in another process, so the intent's name is delivered to subscribers.
- **No push tokens.** `pushType`, `pushToken` and channels have no meaning locally; the socket is the transport.
- **No Lock Screen.** The Lock Screen view of `ActivityConfiguration`, `activityBackgroundTint`, `activitySystemActionForegroundColor` and `supplementalActivityFamilies` are absent.
- **Tap without a `widgetURL` expands**, because there is no app to open.

- **No key line.** `keylineTint` is accepted and ignored: the tinted outline is left out on purpose, it does not suit the desktop.

- **Taller expanded view.** Up to 200 pt instead of Apple's 160.

Not implemented yet: `ActivityStyle.transient` and Apple's limits (eight hours, payload size, activity count).

Added on top, none of it required:

- `"id"` in `request` to choose the id (requesting an existing id replaces it)
- `"bound": true` in `request` to end the activity when the requesting connection closes
- `"dynamicIsland"` in `update` to change parts of an activity's island
- view `Slider` (`value` and `total`, or `timerInterval` to advance on its own; `intent`, `tint`): dragging or clicking it raises the intent with the chosen `value`. Apple has no slider in Live Activities.
- views `Video` (`source`, looping and muted), `WebView` (`source` or `html`; `niche.send("name")` in the page raises an intent) and `AudioBars` (`isActive`, `tint`)
- `{"op":"haptic"}` to tap the trackpad

## Command

```sh
niche configure Delivery @delivery.json
id=$(niche request --type Delivery --attributes '{"items":3}' --state '{"minutes":12}')
niche update "$id" --state '{"minutes":8}' --alert "Almost there" --body "8 minutes away"
niche end "$id" --state '{"minutes":0}' --dismissalPolicy after:+10

niche request --id build --compactLeading "symbol:hammer.fill;foregroundStyle=orange" --compactTrailing "text:3/10"
niche update build --compactTrailing "text:4/10"
niche end build

niche activities
niche events
```

`niche help` lists every option and the view shorthands. Times are Unix seconds or `+SECONDS` from now.

## A long-running integration

```python
import json, os, socket

sock = socket.socket(socket.AF_UNIX)
sock.connect(os.path.expanduser("~/Library/Application Support/Niche/niche.sock"))
lines = sock.makefile("rw")

def send(request):
    lines.write(json.dumps(request) + "\n")
    lines.flush()

def button(intent, symbol):
    return {"type": "Button", "intent": intent, "systemImage": symbol, "buttonStyle": "plain", "font": "title3"}

send({"op": "subscribe"})
send({"op": "request", "id": "player", "bound": True,
      "content": {"state": {"title": "Midnight City", "artist": "M83"}},
      "dynamicIsland": {
          "compactLeading": {"type": "Image", "app": "com.apple.Music", "cornerRadius": 6},
          "compactTrailing": {"type": "AudioBars"},
          "minimal": {"type": "AudioBars"},
          "expanded": {
              "leading": {"type": "Image", "app": "com.apple.Music", "frame": {"width": 52, "height": 52}},
              "center": {"type": "VStack", "children": [
                  {"type": "Text", "text": "{{state.title}}", "font": "headline"},
                  {"type": "Text", "text": "{{state.artist}}", "font": "subheadline", "foregroundStyle": "secondary"}]},
              "bottom": {"type": "HStack", "spacing": 28, "children": [
                  button("previous", "backward.fill"),
                  button("playPause", "pause.fill"),
                  button("next", "forward.fill")]},
          }}})

for line in lines:
    message = json.loads(line)
    if message.get("event") == "intent":
        print("pressed", message["intent"])
```

`Integrations/niche.py` wraps this socket code for Python integrations. `Integrations/spotify.py` is a complete example built on it: a Spotify player with artwork, a seek bar and controls.
