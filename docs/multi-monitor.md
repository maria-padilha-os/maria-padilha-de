# Multiple monitors and hotplug

The shell treats outputs as a live list, not as indices into
`Quickshell.screens`. Adding, removing, rotating or scaling a monitor rebuilds
only the surfaces that belong to that connector; the rest of the session keeps
running.

## The screen model

`shell/services/Screens.qml` is the only place that reads
`Quickshell.screens`. It uses `shell/services/ScreenModel.js` to:

- filter outputs whose global config is disabled;
- collapse duplicate entries for the same connector, preferring the newest
  `ShellScreen` object while keeping the list position stable;
- expose a stable connector key (for example `DP-1`) instead of object identity
  or an array index;
- choose an active output: the focused monitor first, then the primary, then
  the first connected output;
- expose `revision` and `modelChanged(change)` with separate `added`,
  `removed`, `changed`, `moved`, `resized`, `scaled` and `rotated` flags.

Quickshell recreates a `ShellScreen` when an output is reconnected. Code must
compare connector names (`ShellState.forScreen`, `Screens.byName`) or compare
the current object only while it is known to be live. `ShellState.ComponentRef`
captures the component object that received a window reference and clears that
same object on destruction, so a removed output cannot clear a new output's
slot by looking the old screen up again.

If the last output disappears, `ShellState.forActive()` returns a detached
`ScreenState` with no screen. Shortcuts and IPC remain callable during the gap
and no longer dereference a missing monitor.

## Surfaces

| Surface | What happens on hotplug |
| --- | --- |
| Bar | One `BarWrapper` per connector in `Drawers.qml`. The bar is restored to its saved edge/offset; the default remains the built-in right edge. Disabled or excluded outputs never get a bar. |
| Launcher | One per drawer window, positioned bottom-centre by default with a per-output offset. Its `maxHeight` is recalculated from the new screen height when the window is recreated. |
| Dashboard | One per drawer window, top-centre by default with a per-output offset. The open tab belongs to that output's `ScreenState`; it does not leak to another monitor. |
| Notifications | A popup belongs to exactly one output. If that output is removed while the popup is still open, it moves to the new primary instead of appearing on every monitor. Sidebar history remains global. |
| Wallpaper | One background window per enabled output. The image is anchored to the window and its `sourceSize` follows the output's logical size and `devicePixelRatio`, so rotation and scaling re-render the same wallpaper rather than cropping a stale frame. A teardown guard prevents a late `Qt.callLater` from creating an image for a dead output. |
| Lock | The screencopy warm-up uses `Screens.primary` and tolerates no primary instead of indexing `Quickshell.screens[0]`. |

Per-monitor shell settings still live in
`~/.config/padilha/monitors/<connector>/shell.json`, as documented in the shell
configuration reference. They are read by the native `Caelestia.Config`
module; the model above only decides which outputs are live.

## Panel positions per output

`shell/services/PanelLayout.qml` persists a small metadata file:

```
${XDG_STATE_HOME:-~/.local/state}/padilha/panel-layout.json
```

Override it for an isolated test with `PADILHA_PANEL_LAYOUT=/tmp/layout.json`.

The file is keyed by connector and contains only:

- connector key/name;
- `width`, `height`, `x`, `y`, `devicePixelRatio`, orientation;
- the anchor/offset of the bar, launcher, dashboard, notifications and
  wallpaper panels;
- `lastSeen` for bounded retention.

It **never** contains screenshots, wallpaper pixels, window titles,
notification text, clipboard data or other screen contents. Unknown keys are
dropped by `shell/services/OutputLayout.js` when the file is loaded, so an old
or hand-edited file cannot smuggle private data back into the state that is
written next. Offline outputs are retained (up to 16) so reconnecting the same
connector restores its panel positions. Rotation and scaling update the
geometry while preserving those positions.

Inspect or edit the anchors without a settings UI:

```sh
qs ipc call screens list
qs ipc call screens setPosition DP-1 bar '{"edge":"left","offsetX":24}'
qs ipc call screens setPosition DP-1 notifications '{"anchor":"bottom-right"}'
qs ipc call screens forget DP-1
```

Panel positions are presentation metadata only. The compositor's monitor
arrangement (which output is left of which) stays in Hyprland and is never
rewritten by the shell.

## Test matrix

Run the automated suite first:

```sh
bash tests/screens/run.sh
bash tests/all.sh
```

The screen suite covers model updates, output removal (including the last
output), duplicate connector entries, focus fallback, rotation/scale change
flags, layout restoration after a reconnect, privacy of the state file and a
QML-engine load of the same JS modules.

When physical monitors are unavailable, use a **nested** Hyprland or a headless
output. Do not create or remove outputs on the live desktop.

```sh
# A dedicated nested instance; never reuse the live signature.
export XDG_RUNTIME_DIR=$(mktemp -d)
chmod 700 "$XDG_RUNTIME_DIR"
cat >/tmp/padilha-nested.conf <<'EOF'
exec-once = padilha-session
general {
    layout = dwindle
}
EOF
Hyprland --config /tmp/padilha-nested.conf --socket padilha-test
```

From another terminal, point at that instance and create a virtual output:

```sh
export WAYLAND_DISPLAY=padilha-test
hyprctl output create headless
hyprctl monitors -j
hyprctl keyword monitor "HEADLESS-1,1920x1080@60,0x0,1"
```

If the compositor exposes wlr-output-management, `wlr-randr` is equivalent for
rotation/scale. The exact `hyprctl keyword monitor` transform flag varies by
Hyprland release; use `hyprctl keyword monitor` without arguments to see the
accepted form for the installed version.

| Case | Action in the nested/headless session | Expected |
| --- | --- | --- |
| Add output | `hyprctl output create headless`; set a monitor rule | One new bar, background and drawer window; no bar on an existing output is duplicated. |
| Remove secondary | `hyprctl output remove HEADLESS-1` | Its surfaces disappear; the remaining bar/panels keep working; no crash and no stale panel on the removed connector. |
| Remove primary | Remove the output listed first in `hyprctl monitors -j` | The next connected output becomes primary; launcher, dashboard and popup notifications target it. |
| Remove last output | Turn off the only headless output | Shell stays alive; shortcut/IPC calls do not throw; surfaces reappear when an output returns. |
| Rotate | `hyprctl keyword monitor "HEADLESS-1,1920x1080@60,0x0,1,transform,1"` (or `wlr-randr --transform 90`) | Bar, launcher, dashboard and notifications stay on-screen at the new aspect ratio; wallpaper fills without a stale crop. |
| Scale | `hyprctl keyword monitor "HEADLESS-1,2560x1440@60,0x0,1.5"` (or `wlr-randr --scale 1.5`) | Text and icons use the new logical size; wallpaper re-renders at the new pixel density; panel offsets are preserved. |
| Reconnect | Remove `HEADLESS-1`, then add it again | `panel-layout.json` still has the connector; the saved bar edge/panel anchors return. |
| Two outputs, same name | Create/remove quickly while the model settles | `Screens.screens` has one entry for that connector, never two bars on one output. |
| Open drawer during removal | Open the launcher on the removed output | The window is destroyed with the output; no binding to a deleted `ShellScreen`; the remaining session is usable. |
| State privacy | `cat "$XDG_STATE_HOME/padilha/panel-layout.json"` | Only connector keys, geometry and panel anchors are present; no image data, titles or notification text. |

Useful verification commands inside the nested session:

```sh
qs ipc call screens list
qs ipc call drawers list
qs ipc call wallpaper get
hyprctl monitors -j
```

Stop the nested compositor when done. The live session's `padilha-reload` is
not part of this test; restarting the live shell is a deliberate user action.
