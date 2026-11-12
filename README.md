# Niche

Niche shows Live Activities in the notch of a MacBook. It is a Dynamic Island for macOS. Each program on the Mac can show an activity.

## Requirements

- A Mac that has a notch
- macOS 14 or later
- Xcode

## Install Niche

1. Install the app and the `niche` command.

   ```sh
   make install
   ```

2. Start the app.

   ```sh
   make run
   ```

## Make something for the notch

Give this repository to your coding agent. Tell the agent what you want to see in the notch.

Niche uses the names of the Live Activities API from Apple. The names come from ActivityKit and WidgetKit:

- `request`, `update`, and `end`
- `ActivityContent`
- `DynamicIsland`, with `compactLeading`, `compactTrailing`, `minimal`, and `expanded`

An agent that can write a Live Activity for iPhone can write one for Niche. The agent sends JSON through a local socket. The agent does not compile a widget.

Give these instructions to the agent:

1. Read `AGENTS.md`. This file has a procedure for each type of change.
2. Read `API.md`. This file gives the Niche name for each Apple name.
3. Use the names and the behavior of the Apple API.
4. Run `make test`. All the tests must pass.

## Example

1. Show an activity.

   ```sh
   niche request --id build --compactLeading "symbol:hammer.fill;foregroundStyle=orange" --compactTrailing "text:3/10"
   ```

2. Change the activity.

   ```sh
   niche update build --compactTrailing "text:4/10"
   ```

3. Remove the activity.

   ```sh
   niche end build
   ```

`Integrations/spotify.py` is a full example. It shows a Spotify player with the cover, the controls, and a seek bar.
