# Niche

Niche is a personal macOS app that turns the MacBook notch into a Dynamic Island. Other programs show Live Activities in it through a local socket API that mirrors Apple's ActivityKit and WidgetKit name for name. `API.md` is the reference for that API. Read it before you write an integration or change the protocol.

## Commands

| Command | What it does |
| --- | --- |
| `swift build` | Builds everything in debug. |
| `make test` | Runs the tests. Takes about 10 seconds. Needs no running app. |
| `make run` | Builds the release app into `build/Niche.app` and relaunches it. |
| `make install` | Builds the app and links the `niche` command into `~/.local/bin`. |
| `make verify` | Runs the tests, relaunches the app, and compares a screenshot of every scene in `Verify/scenes.py` with `Verify/baseline`. |
| `make baseline` | Relaunches the app and records a screenshot for each scene that has none. To record a scene again, delete its file in `Verify/baseline` first. |
| `make golden` | Records `Verify/golden/` again from an in-process server and the built command. Needs no running app. |

`make run`, `make verify`, and `make baseline` replace the app on the owner's real notch, so two agents cannot run them at the same time. Integrations exit when the app restarts. Start them again afterwards (`python3 Integrations/spotify.py &`). The scene script waits while the pointer is near the notch and stops if another activity is showing.

## Layout

```
Sources/NicheKit/        Everything a client can observe except pixels. No AppKit, no SwiftUI.
  Model/                 Activity, DynamicIsland, Node (the view tree), JSONValue, placeholder resolution
  ActivityCenter.swift   The lifecycle: request, update, end, stale, dismissal, ordering
  Wire/                  Request, Reply, NotchEvent: the JSON lines of the protocol
  Socket/                Server (listener and dispatch), SocketClient, SocketPath
Sources/Niche/           The app. Pixels, pointer, built-in activities. Never parses a JSON line.
  Notch/                 NotchModel (what shows, pointer behaviour), geometry, panel, shape, layout
  Views/                 NodeView renders a Node. Kinds/ holds the larger view types. Styles.swift holds fonts and colours.
  BuiltIn/               Activities that run inside the app, such as AirPods
  System/                Haptics
Sources/NicheCLI/        The niche command. Flags and shorthands become a Request.
Integrations/            Python programs that use the socket. niche.py is the shared client.
Tests/NicheKitTests/     Lifecycle, decoding, the protocol, command and Python client contracts, API.md coverage
Tests/NicheTests/        Pointer behaviour with a fake pointer, the tuned delays, geometry, built-ins
Verify/                  The contract scripts, their golden files, the scenes, and the screenshot baseline
```

`Niche` and `NicheCLI` import `NicheKit`. `NicheKit` imports neither. The compiler enforces that direction.

## Rules

- Write code without comments. Names and structure carry the meaning.
- Keep Apple's names and behaviour. Anything Apple does not have goes in the "Added on top" list in `API.md`.
- Behaviour is pinned by `Verify/golden/` and `Verify/baseline/`. When a check fails, fix the code. Record a new golden or baseline only when the change is intended, and say so in your report with the diff.
- The `niche` command passes values through and lets the server refuse them. Do not validate in the command what the server already validates.
- `NotchModel` reaches the outside world only through `NotchEnvironment`, and every delay lives in `NotchTiming`. Keep it that way so the pointer tests keep working.
- Island animations use `Animation.notch(stiffness:damping:)`, which is a spring that a new target can redirect. Do not use `interpolatingSpring` for the island.
- Swift 6 strict concurrency, macOS 14, SwiftPM only, no third-party packages.
- `Assets/` holds private video files and is gitignored. Never commit or publish it.
- The tinted outline (`keylineTint`) is left out on purpose. Do not add it.
- QuartzNotch (GPLv3) is a reference for how features work. Never paste its code.
- Look at a screenshot of any panel you build before you report it. Keep one left edge, and put the main content in the `bottom` region.
- Commit messages have a conventional subject, a short body, and no co-author or session trailer.

## Add an external integration

Use this route unless the feature needs an API that only an app can call.

1. Create `Integrations/<name>.py` and import the client with `from niche import Niche`.
2. Call `niche.request(id="<name>", bound=True, content={"state": …}, dynamicIsland=…)`. `bound=True` ends the activity when your script exits.
3. Call `niche.update("<name>", content={"state": …})` when the data changes. Views read the state through `{{state.x}}` placeholders, so the island is sent once.
4. Handle buttons with `niche.on_intent("<name>", handler)`. All handlers share one background thread, so a slow handler delays the next event. A handler may call `niche` again.
5. A call raises `NicheError` with the server's message when the server refuses it, and `NicheClosed` when the app has quit. Decide what each means for your script. `niche.on_close(handler)` runs when the app goes away.

`Integrations/spotify.py` shows the whole pattern. Check your integration with `niche activities`, then look at the notch.

A placeholder that is the whole string takes the value's type. `"text": "{{state.count}}"` fails when `count` is a number. Write `"text": "{{state.count}} left"`, or send the number as a string.

## Add a built-in activity

1. Create a file in `Sources/Niche/BuiltIn/` with a class that conforms to `BuiltInActivity`.
2. Add it to `BuiltInActivities.all()` in `Sources/Niche/BuiltIn/BuiltInActivity.swift`. Without that line it never starts, and `BuiltInActivitiesTests` fails.
3. Build the island from typed values, so the compiler checks every field: `Node(.image) { $0.systemName = "calendar" }` inside a `DynamicIsland(…)`. Pass it as `JSONValue(encoding: island)`.
4. Drive the activity only through `ActivityCenter.request`, `update`, and `end`. To react to its buttons, call `center.onIntent(for: id) { intent, isOn, value in … }`.
5. Test the island builder in `Tests/NicheTests/`, as `AirPodsIslandTests` does.

`BuiltIn/AirPods/` is the example.

## Add a view type or a modifier

1. Add the case to `Node.Kind` and any new field to `Node` in `Sources/NicheKit/Model/Node.swift`.
2. The `switch` in `Sources/Niche/Views/NodeView.swift` stops compiling. Render the new case there. If the view needs more than a few lines, put it in `Sources/Niche/Views/Kinds/<Name>Node.swift`.
3. Document it in `API.md`. `DocumentationTests` fails until the type is named there.
4. Add a scene that uses it to `Verify/scenes.py`, run `make baseline`, and look at the new screenshot. `make baseline` leaves the existing screenshots alone, and `make verify` fails for a scene that has none.

A modifier is a new field on `Node`, applied in the fixed order in `NodeView.body`. A shorthand for the command goes in `Sources/NicheCLI/NodeShorthand.swift` and in the usage text in `main.swift`, with a new case in `Verify/command.py` and `make golden`.

## Add an operation or an event

1. Add the case to `Request.Operation` and any field to `Request` or `Reply` in `Sources/NicheKit/Wire/`.
2. The `switch` in `Server.perform` stops compiling. Handle the case there. Anything it needs from the app comes through `Server.Host`.
3. For an event, add the case to `NotchEvent.Name` and send it from `ActivityCenter`.
4. Document it in `API.md`. `DocumentationTests` fails until every operation and event is named there.
5. Add steps to `Verify/protocol.py`, then run `make golden`. Review the diff of the golden file. Only the new steps may differ.

`niche send '<json>'` reaches any operation, so a dedicated command is optional.

## Change pointer behaviour

1. Edit `Sources/Niche/Notch/NotchModel.swift`. A new input, such as a file drop, enters through `AppDelegate` or `NotchPanel` and calls one method on the model.
2. Add any new delay to `NotchTiming` and any new outside effect to `NotchEnvironment`.
3. Test it in `Tests/NicheTests/NotchModelTests.swift`. `World` is the fake pointer, button, and haptic. The tests use short delays, so give a delay you test a value that no other delay hides. Break your change on purpose once to see the test fail.
4. `TuningTests` pins the delays and animations the owner tuned. Change those values only when the owner asks.

Haptics and the feel of the animation cannot be checked by a test. Say in your report that the owner has to try them.

## Known gaps

- A trailing region with `belowIfTooWide` is drawn over a leading region that has `priority`. `expanded-priority.png` in the baseline shows it. Fixing it means recording that screenshot again.
- Enumerated strings such as `buttonStyle` fall back to the default when misspelt instead of returning an error. A misspelt field name in a JSON view is ignored the same way.
- The command crashes on a number it cannot encode, such as `--relevanceScore nan`.
- The pointer logic in `NotchModel` runs on several timers and is tested on the real clock with short delays. Rewriting it as one pure state machine would make those tests exact, but nothing can prove the feel is unchanged without a pointer trace recorded by the owner.
- `AlertConfiguration.title` and `body` are accepted and not shown.
- Not built: `ActivityStyle.transient`, Apple's limits (eight hours, payload size, activity count), file drop, starting integrations at login.
