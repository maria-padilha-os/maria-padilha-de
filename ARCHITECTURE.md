# Architecture

## Layers, bottom up

| # | layer | who owns it |
| --- | --- | --- |
| 1 | Linux, Wayland, Qt 6, Quickshell runtime | platform — pinned, never carried |
| 2 | Hyprland: windows, workspaces, input, layer surfaces, IPC | configured by us, not forked |
| 3 | Shell (`shell/`): bar, launcher, notifications, OSD, dashboard, lock | ours |
| 4 | Session: start, lock, suspend, log out | ours (user units; the DM entry is still the distro's) |
| 5 | Theme: wallpaper → palette → every application | ours |
| 6 | Settings: the UI that writes what 3–5 read | ours (planned) |

Layer 3 is a QML tree plus one C++ plugin (`Caelestia`: blob shaders, config
schema, services). The plugin links Qt and a handful of system libraries
(qalculate, pipewire, aubio, libcava) — not Quickshell's C++ headers, so the
fork builds without rebuilding the runtime.

## The palette loop

The reason the desktop reads as one product rather than twelve themed apps:

```
wallpaper
  └─ seed        Material's score: hue excitement, then chroma; mode from L*
      └─ scheme      six HCT tonal palettes, Material's role table
          └─ palette JSON   ~/.local/state/caelestia/scheme.json
          ├─ Hyprland scheme (lua)      ├─ GTK 3 / GTK 4 css
          ├─ btop theme                 ├─ Qt / Kvantum
          ├─ cava gradient              ├─ terminal escape sequences
          ├─ fuzzel, spicetify          ├─ nvim, discord
          └─ postHook: formats that don't fit the template language (mc skin)
```

`bin/padilha-theme` is the whole loop: `apply` renders `share/templates/` into
the application configs and pokes what needs poking. `bin/padilha-daylight`
picks the wallpaper by hour and runs the loop when the period changes.

The shell consumes the same JSON live (`services/Colours.qml`). Applications
that can't reload need a signal (btop and cava take `SIGUSR2`) or a restart.

Invariant: one input, every surface. Any colour on screen that didn't come
through this loop is a bug, not a preference.

## Rules

1. **No patch stacks.** Upstream enters exactly once, at import (`v2.5.0`).
   After that the tree is ours; changes are commits, not patches.
2. **One source of truth per artifact.** Shell code in `shell/`, palette logic
   in the theme engine, defaults in this repo. Never a hand-edited copy under
   `/usr` or a second checkout under `~/.config/quickshell`.
3. **Adapt at the boundary.** For anything we don't own — Hyprland, Quickshell
   — we change config and IPC, not source.

## Boundaries that bite

- **The config schema is C++.** `libcaelestia-config` defines every valid key
  and its default. A new *setting* is a C++ change; only layout and behaviour
  are QML.
- **Quickshell is the floor under roughly 500 files.** A breaking release there is a
  tree-wide edit, which is why it is pinned and watched.
- **Hyprland's Lua config is young.** Dispatcher names and environment
  handling still move between minor versions; the keybinds are the canary.

## Decisions

Architecture decision records live in `docs/adr/`. ADR 0001 (proposed) defines
the built-in assistant's separate panel and backend process, the
provider-agnostic chat service, and the permissioned home-folder policy:

- [ADR 0001 — Built-in AI assistant and permissioned home access](docs/adr/0001-built-in-ai-assistant.md)
