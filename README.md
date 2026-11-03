# Padilha

Maria Padilha is the pomba-gira of the crossroads — the Brazilian Lilith, the
one who owns the place where paths meet and a choice has to be made. A desktop
is a crossroads too: the layer where you meet the machine. The project is
**Padilha**; when it needs a full name, **Desktop Maria Padilha**.

## What it is

A desktop environment in the sense GNOME and KDE are: the shell you look at,
the palette that colours every application, the session that starts and ends
the day, the settings that tie it together, and the package that installs it.

It stands on Linux, Wayland, Qt 6, Hyprland and Quickshell. Everything above
that line is ours.

## Which one is running?

This machine runs **this tree**, not the Caelestia package:

- `~/.config/quickshell/caelestia` is a symlink into `shell/`, the session
  starts it as `qs -c caelestia`, and the C++ modules are loaded from
  `build/qml`.
- Wallpapers and every colour come from `bin/padilha-theme` and
  `bin/padilha-daylight`; the config comes from `bin/padilha-config`.
- `caelestia-cli` is still installed, but nothing in the session or the shell
  executes it any more.

The *code*, though, is still mostly Caelestia's: the fork is v2.5.0 plus the
commits in `git log -- shell/`. That is what descending from it means in
practice, and the name survives where it is an interface rather than
branding — the Quickshell config is still called `caelestia`, so app ids,
window classes and existing rules keep working. The About page calls the
desktop Padilha.

## Status

First light. `shell/` (a fork of Caelestia v2.5.0, and by now more than the
four patches that started it) is what this machine runs: it builds with the system toolchain
(`tools/build.sh`, 223 targets, Qt 6.11) and the session starts it through
`~/.config/quickshell/caelestia`, a symlink into this tree.

The package builds: `packaging/PKGBUILD` runs the same CMake build and installs
the shell into `/etc/xdg/quickshell/caelestia` (where `qs -c caelestia` looks),
the commands into `/usr/lib/padilha`, and the session units into
`/usr/lib/systemd/user`.

Configuration is ours too. `bin/padilha-config` compiles
`~/.config/padilha/init.lua` into the shell's JSON, and `bin/padilha-session`
runs that compile at login before starting the shell.

Keys and types are validated against the module's own `qmltypes`, so a typo
is a compile error with a suggestion, not a line the shell silently ignores.
The checkout is the source of truth; the package is built from it.

Colours are ours as well. `bin/padilha-theme` reads a wallpaper, scores its
colours the way Material does, builds the HCT tonal palettes in Lua and writes
`scheme.json` plus every application template — no Python in that path.
`bin/padilha-daylight` chooses the wallpaper by the hour: white for the day,
black for the night, both painted by Maria Padilha, both seeded from the red
of their candles.

Nothing in the session or the shell executes the Python `caelestia` CLI any
more: the launcher is `qs`, and wallpaper, scheme, lock, toasts, screenshots,
recording, the clipboard and the emoji picker are our own commands. The
package is only still installed because removing it needs root.

## What "ours" means

- **Owned**: shell behaviour and layout, theme engine, session, settings,
  installer, branding, every default.
- **Tracked, never carried**: Hyprland, Quickshell, Qt, and the libraries the
  shell links against (qalculate, pipewire, aubio, libcava). We pin them,
  watch them, adapt to them — we do not fork them.

`UPSTREAM.md` records what we watch and why; `tools/upstream-watch.sh` reports
what moved since our pins.

## Next

1. The greeter: the session entry is packaged; the display-manager side and a
   greeter theme are still the distribution's, and are the last pieces that
   need root.
2. The settings application as a *writer of `init.lua`*, now that the compiler
   carries UI edits instead of overwriting them.
3. Live config: watch `init.lua`, recompile and reload the shell on save;
   `settings.watchFiles` is deliberately off today.

## Layout

| path | what |
| --- | --- |
| `shell/` | the desktop shell (QML + C++ plugin), forked from Caelestia 2.5.0 |
| `bin/` | `padilha-config` (config compiler), `padilha-session` (login entry point), `padilha-theme` (palette engine), `padilha-daylight` (the two-wallpaper clock), `padilha-reload` (restart the shell safely), `padilha` (the small command surface), `padilha-shot` / `-record` / `-clipboard` / `-emoji` (utilities) |
| `lib/` | the Lua under `padilha-theme`: colour maths, scheme roles, templates, apply |
| `share/` | templates, the two default wallpapers, theme defaults, emoji data |
| `packaging/` | the PKGBUILD and what a package installs where |
| `session/` | systemd user units and the session-restore script |
| `examples/` | a reference `init.lua` |
| `tests/` | contract tests for the compiler |
| `tools/` | maintenance scripts |
| `upstream.json` | pinned versions of everything we sit on |
| `CONFIG.md` | the user-facing config contract (Lua in, JSON out) |
| `ARCHITECTURE.md` | how the pieces fit and where data flows |
| `UPSTREAM.md` | what we track and how we absorb it |

## Lineage

The shell descends from [Caelestia](https://github.com/caelestia-dots/shell),
GPL-3.0 — see `shell/LICENSE`. Keeping that licence is the price of standing on
someone else's work; from here the code is ours to maintain.
