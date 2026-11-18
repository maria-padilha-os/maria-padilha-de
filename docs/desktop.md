---
layout: default
title: Desktop
---

# The Maria Padilha desktop

The shell is a fork of [Caelestia](https://github.com/caelestia-dots/shell),
adapted to this desktop. It provides the bar, launcher, notifications, OSD,
dashboard, optional in-shell lock, and the panels around them. Screen locking
itself goes through `padilha-lock` and `hyprlock`.

## Day and night

`padilha-daylight` switches between a light wallpaper at 06:00 and a dark one at
18:00. Each switch rebuilds the Material You palette from the image and applies
it to Hyprland, GTK 3/4, Qt/Kvantum, terminals, btop, lazygit, Thunderbird, cava, fuzzel, Neovim,
Discord, Midnight Commander, and Firefox's chrome and new tab page. The Neovim
colorscheme follows the same palette and switches between its ayu-inspired
light and dark variants.

## Package updates

**Settings → Updates** lists pending pacman upgrades with the installed and
candidate versions plus the download and installed size. The list is read-only:
nothing is downloaded or installed until you choose **Review and apply** and
then **Confirm update**. The manager never adds a timer, updates in the
background, or starts a reboot.

A confirmed update runs pacman through the existing polkit agent (pkexec). It
does not install a second privileged helper or a root daemon. Every attempt
writes a log under `~/.local/state/padilha/updates`; a failure shows its last
lines in the page and the full path has a **Copy log path** button. Low battery
always gets a warning, and a large update (500 MiB or more by download or
installed size) warns when the session is on battery.

The same flow is available from a terminal:

```sh
padilha update check          # read-only list, or --json
padilha update apply          # lists, asks y/N, then applies
padilha update apply --yes    # skip the prompt only after you reviewed check
padilha update log            # newest log path
padilha-update check          # same command under its own name
```

## Colour picker

The palette icon in the bar opens the colour picker. Nothing samples the screen
until you press **Pick colour**; **Escape** cancels. It uses `hyprpicker`, so it
works on Wayland without a screenshot file, and no picker process is left
running once a colour is chosen. The panel shows the swatch, HEX, RGB, and HSL
values, and each row copies its value on click. The HEX copy button changes to
a check mark to confirm the write, and the whole panel follows the active
light or dark palette. `padilha-colour` is the same parser used by the panel and
can also be called directly (`padilha-colour pick`, `padilha-colour parse VALUE`).

## Screenshots and recording

The utilities drawer has a screenshots and recording card. It can capture the
focused monitor, the focused window, or a region selected with `slurp`, and it
can record the monitor, a window, or a region with `wf-recorder`. Start is
always explicit; a configurable countdown, a **Cancel** button, an in-panel
**REC** badge, and a pulsing dot in the bar make an active capture obvious.
**Stop** finalises the file and the recordings list opens it or shows its
folder.

Files are timestamped and stay local: the default screenshot folder is
`~/Pictures/Screenshots` and recordings go to `~/Videos/Recordings`. Both can
be changed in the settings card or under `utilities.capture` in
`~/.config/padilha/init.lua`. A screenshot is copied to the clipboard only when
the copy switch is on for that capture (or `--copy` is passed); nothing is
uploaded. The panel never starts recording when it opens.

Capture from an empty workspace. The command warns when Hyprland's active
workspace is not the configured `capture` workspace, and `--strict-workspace`
makes that a refusal. See [CONFIG.md](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/CONFIG.md#screenshots-and-recording)
for all commands and environment overrides.

## Media player

The media item in the bar shows the active MPRIS track's cover and a progress
line. Click it to open the media popout: title, artist and album, artwork with
a themed fallback, seek, play/pause, previous/next, and volume when the player
exposes it. If several MPRIS players are open, the popout can pick which one
the bar follows.

Opening the widget never starts playback, and it never scans processes or
media files; it only reads the players already exported on the session bus.
With no player it shows a plain **Nothing playing** state. While the popout is
open, **Space** or **K** toggles playback, **J**/**L** or **Left**/**Right**
seeks ten seconds, **Shift + Left**/**Right** changes track, **Up**/**Down**
changes the player volume, **Home**/**End** seeks to the start or end, and
**Escape** closes it.

## Calculator

The launcher has a native calculator mode. Tap `Super` to open the launcher and
type `>calc 2+2`; the `Qalculator` binding uses libqalculate, so units,
currency, variables, and exact fractions work. Clicking the result copies the
raw value. `XF86Calculator` opens galculator, and `qalc -i` in a terminal gives
the full REPL. IPython is deliberately not used: it starts slower and evaluates
Python semantics rather than human-readable math.

## Weather

Weather uses a location you choose; it never looks up your address from the
network. Search for a city in **Settings → Language & region** and pick a
result, or enter a city or `latitude,longitude` directly. The saved place is
shown in the weather panel and can be cleared, which also stops refreshes.

The panel shows the last update time, keeps the last saved response while a
refresh fails, and says when it is showing stale weather. Units, language and
the refresh interval are in the same settings page. Provider URL and its
optional key live in `~/.config/padilha/weather.conf`, never in this checkout;
see [CONFIG.md](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/CONFIG.md#weather).

## Keys

| keys | action |
| --- | --- |
| `Super + h/j/k/l` | focus window |
| `Super + Shift + h/j/k/l` | move window |
| `Super + Ctrl + h/j/k/l` | resize window |
| `Super + Alt + h/l` | previous / next workspace |
| `Super + Alt + j/k` | previous / next monitor |
| `Super + Shift + P` | show all panels |
| `Super + Escape` | lock (`hyprlock`) |

The full map is in
[KEYBINDS.md](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/KEYBINDS.md).

## Configuration

User configuration lives in `~/.config/padilha/`:

| file | role |
| --- | --- |
| `init.lua` | the main configuration |
| `local.lua` | per-machine overrides |
| `ui.lua` | generated by the settings UI |
| `weather.conf` | private weather provider URL/key (optional) |

Apply a change with `padilha-config compile && padilha-reload`.
