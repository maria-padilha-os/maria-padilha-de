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

## Status

Foundation. `shell/` is the upstream Caelestia QML/C++ tree, imported at
v2.5.0 as our base. It builds with the system toolchain (`tools/build.sh`,
223 targets, Qt 6.11) and the result loads as a Quickshell configuration.
What runs the desktop today is still the `caelestia-shell` package plus
patches; the fork is not installed yet.

## What "ours" means

- **Owned**: shell behaviour and layout, theme engine, session, settings,
  installer, branding, every default.
- **Tracked, never carried**: Hyprland, Quickshell, Qt, and the libraries the
  shell links against (qalculate, pipewire, aubio, libcava). We pin them,
  watch them, adapt to them — we do not fork them.

`UPSTREAM.md` records what we watch and why; `tools/upstream-watch.sh` reports
what moved since our pins.

## Next

1. Build `shell/` from source and run it instead of the package — prove the
   fork is real before adding anything to it.
2. Fold the three local patches and the hand edits into the tree, so they stop
   existing as patches.
3. Replace the Caelestia CLI theme pass with `padilha-theme` (own palette
   maths, own templates, no Python dependency).
4. Session: greeter, `uwsm`/systemd integration, session restore.
5. Settings application, then packaging.

## Layout

| path | what |
| --- | --- |
| `shell/` | the desktop shell (QML + C++ plugin), forked from Caelestia 2.5.0 |
| `tools/` | maintenance scripts |
| `upstream.json` | pinned versions of everything we sit on |
| `ARCHITECTURE.md` | how the pieces fit and where data flows |
| `UPSTREAM.md` | what we track and how we absorb it |

## Lineage

The shell descends from [Caelestia](https://github.com/caelestia-dots/shell),
GPL-3.0 — see `shell/LICENSE`. Keeping that licence is the price of standing on
someone else's work; from here the code is ours to maintain.
