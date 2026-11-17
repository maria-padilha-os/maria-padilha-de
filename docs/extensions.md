---
layout: default
title: Extensions
---

# Extensions

An extension adds a **tab to the top panel** (the dashboard), in the same tab
bar as Dashboard, Media, Performance and Weather. Settings → Extensions shows
each extension as a card with its description, version, permissions, state,
tab and shortcut; it only enables and disables them. The tab itself lives in
the top panel, never inside the settings window. Enabling or disabling takes
effect immediately, without restarting the shell.

## Layout

```
~/.config/padilha/extensions/<id>/
├── extension.json
└── Tab.qml
```

`<id>` is the directory name. It is the value stored in
`dashboard.extensionTabs` when the extension is enabled.

## Manifest

```json
{
    "name": "Guitar tuner",
    "description": "Tune by ear with a microphone",
    "version": "1.0",
    "icon": "tune",
    "tab": "Tab.qml",
    "shortcut": "Super + Alt + G",
    "permissions": ["microphone", "processes"]
}
```

`name`, `description`, `version`, `icon` and `tab` are required and must be
non-empty strings.

- `tab` is the entry shown as a tab in the top panel. It must be a relative
  `.qml` path inside the extension folder; `..`, absolute paths and missing
  files are rejected.
- `icon` is a Material symbol name used in the tab bar.
- `name` becomes the tab title.
- `shortcut` is optional. It is displayed as a reminder; the actual keybind is
  still declared in the shell keybinds. When present it must be a string, and
  two extensions claiming the same shortcut are both flagged (comparison
  ignores case and spaces around `+`).
- `permissions` (or its alias `capabilities`) is an optional list of
  capability names. Known names are listed below. An unknown name is shown as
  a custom capability with a warning; it does not make the manifest invalid.
- `requires` (or `dependencies`) is an optional list of other extension ids
  that must be installed. A missing dependency is shown as an actionable error
  on the card and the extension cannot be enabled until it is present.
- `commands` is an optional list of local executables the extension needs. The
  manager checks whether each one is on `PATH` and reports the missing ones; it
  never runs a package manager or fetches anything.

### Permissions

| name | what it means |
| --- | --- |
| `filesystem` | reads and writes files |
| `network` | connects to remote servers |
| `microphone` | captures audio from the microphone |
| `screen` | reads pixels from the screen |
| `notifications` | sends desktop notifications |
| `processes` | runs local commands and processes |
| `system` | reads system and filesystem information |
| `clipboard` | reads or writes the clipboard |

Permissions are metadata for the person choosing whether to enable an
extension. They are not a sandbox: QML still runs with your user's privileges.

## Managing

Settings → Extensions provides:

- a search box that matches names, ids, descriptions, shortcuts, permissions,
  requirements and error text;
- **All**, **Enabled**, **Disabled** and **Needs attention** filters;
- an empty state that explains where to put an extension instead of offering
  a download or install button;
- a card per discovered folder, including folders whose manifest is broken or
  whose id or shortcut collides with another extension.

Nothing is installed, downloaded or fetched from the network by the manager.
It scans the local folders, reads `extension.json`, and writes the enabled ids
to `dashboard.extensionTabs`. A folder with a broken manifest stays visible
with the exact problem and a suggested fix.

## Validation and errors

The manager never hides a discovered folder because its manifest is broken. It
surfaces actionable messages on the card:

- invalid JSON, an empty file, or a manifest that is not an object;
- missing or empty required fields;
- an unsafe or missing `tab` file;
- a duplicate id (every copy is listed, with the other folder named);
- a duplicate shortcut (both cards warn; the comparison ignores case and
  spacing around `+`);
- a missing extension dependency or local command.

A card with an error cannot be enabled. If an already-enabled extension
becomes invalid, its switch still lets you turn it off. Duplicate shortcuts
are warnings because the tabs themselves still work, but the shortcut is
ambiguous until one manifest changes.

The scanner reads `~/.config/padilha/extensions` first and the bundled
directories last, so a user extension still overrides a bundled extension with
the same id. Two folders at the same priority are a real duplicate and neither
can be enabled. The lower-priority bundled copy stays visible with a
"shadowed by" warning instead of disappearing.

## Enabling

Settings → Extensions lists the installed extensions with an on/off switch.
Enabled tabs are appended after Weather, in the order the manifest names sort.
The enabled ids live in `dashboard.extensionTabs` in the shell config, so they
survive reloads. Disabling a tab removes it from the dashboard immediately;
no shell restart is required.

## Tab contract

`Tab.qml` is a plain QML item whose root declares:

```qml
property var api
```

The shell assigns `api` while creating the item, so it is available from
`Component.onCompleted`:

| key | value |
| --- | --- |
| `config` | `GlobalConfig` |
| `colours` | the `Colours` theme singleton |
| `brightness` | monitor brightness service |
| `hypr` | monitor and bind service |
| `paths` | the `Paths` helper |
| `extension` | the manifest of the running extension, including `dirPath` |

Extension files may import `Caelestia.Config` and `Caelestia.I18n`. The `qs.*`
modules are internal to the shell tree and cannot be resolved from
`~/.config/padilha`, so use `api` for those services.

A tab declares its own `implicitWidth` and `implicitHeight`; the dashboard
sizes itself to the item. It can also declare `minimumWidth` and
`minimumHeight`, which the dashboard uses to clamp the panel at narrow window
sizes, and `property bool active: true` — the shell sets it to true only while
the tab is selected, so network or audio work should wait for that flag.

## Trust

Extensions are QML executed inside the shell process with your user's
privileges. The manifest is metadata, not a sandbox: only install code you
trust. Nothing loads at startup — a tab is created only when its extension is
enabled and the top panel is open.

## Bundled extensions

The repository ships `calculator`, `maps`, `stopwatch`, `translator`, `tuner`,
`system-monitor`, `pomodoro`, `disk-usage`, `notes`, `calendar` and
`unit-converter` under `extensions/` and `share/extensions/`; the installer and
package put them in `/usr/lib/maria-padilha/share/extensions`. The dashboard
scanner also reads the checkout directories while developing. See
`extensions/README.md`.

The calculator tab shows a display, a four-column keypad and a scrollable
history. It stacks those sections at 360×460 and puts history beside the keypad
on a full dashboard. The keypad inserts qalc syntax and the same qalc command
still owns parsing and error messages.

The translator tab fills the dashboard surface and switches to a compact layout
below 640×420. Its [layout checklist](translator-layout-checklist.html) records
the visual, sizing and interaction checks.

The Files tab keeps arrow/Enter/Backspace navigation, adds `Ctrl + L` for its
address bar and `Ctrl + F` for search, and has an opt-in Vim toggle (`j`/`k`,
`h`/`l`, `gg`/`G`, `Ctrl + d`/`Ctrl + u`, `/`, `Esc`). Its
[keyboard checklist](files-keyboard-checklist.html) covers the Files tab and the
file dialog sidebar/address bar, including the no-destructive-key rule.

`notes` stores plain-text files and `calendar` stores `events.json` under
`~/.local/share/padilha/` (honouring `XDG_DATA_HOME`); neither has network
access. `unit-converter` works entirely from a local factor table.
`system-monitor` reads CPU and memory from the shell services and the load
average from `/proc/loadavg`. `pomodoro` only counts down while its tab is
selected and uses `notify-send` for phase changes. `disk-usage` lists the
mounted filesystems reported by the `Storage` service and never writes to them.

### Maps tiles and keys

`maps` follows the palette with CARTO's `light_all` / `dark_all` raster styles
and falls back to standard OpenStreetMap tiles (with a visible notice and a
dimmed dark-mode canvas) when CARTO is unavailable or has no key.
OpenStreetMap is always credited; CARTO is credited whenever a key is configured.

CARTO's raster tiles need a free API key. Supply it at runtime, never in this
checkout:

```sh
export PADILHA_MAPS_CARTO_KEY='YOUR_KEY'
# or ~/.config/padilha/maps.conf (chmod 600)
# carto_key = YOUR_KEY
```

The environment wins over the file; `XDG_CONFIG_HOME` is honoured. Request a
key at <https://carto.com/basemaps/apikey/> and see
<https://docs.carto.com/faqs/carto-basemaps> for the free-tier limits
(non-commercial 5 million tile requests per calendar month, commercial 1
million; keys are per-customer). The extension only asks for the nine visible
tiles at a time and caches them under
`$XDG_CACHE_HOME/caelestia/maps/carto/<style>/<z>/<x>/<y>.png`; the key is
never written to the cache. See `extensions/maps/README.md` for the full
provider and Nominatim notes.
