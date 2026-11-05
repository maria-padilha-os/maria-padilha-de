---
layout: default
title: Extensions
---

# Extensions

An extension augments the desktop. It can provide a settings page and,
optionally, a **tab in the top panel** (the dashboard), alongside Dashboard,
Media, Performance and Weather.

## Layout

```
~/.config/lilith/extensions/<id>/
├── extension.json
├── Page.qml        # settings page
└── Tab.qml         # optional dashboard tab
```

`<id>` is the directory name; it is what the config stores when the tab is
enabled. Lilith also scans the packaged extensions in
`/usr/lib/lilith/share/extensions`; a user directory with the same id wins.

## Manifest

```json
{
    "name": "Guitar tuner",
    "description": "Tune by ear with a microphone",
    "version": "1.0",
    "icon": "tune",
    "entry": "Page.qml",
    "tab": "Tab.qml"
}
```

- `entry` is the QML shown in Settings → Extensions; defaults to `Page.qml`.
- `tab` is optional. When present, the extension can be added to the top panel.
- `icon` is a Material symbol name, used in the settings list and as the tab
  icon.

## Adding a tab

Open Settings → Extensions → the extension → **Show in the top panel**. The
enabled ids live in `dashboard.extensionTabs` in the shell config, so they
survive reloads. Tabs are appended after Weather and use the manifest `name` as
their title.

## Entry contract

Both entry points are plain QML items whose root declares:

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
`~/.config/lilith`, so use `api` for those services.

A tab should declare its own `implicitWidth` and `implicitHeight`; the dashboard
sizes itself to the item. A settings page gets the content area of the settings
window.

## Trust

Extensions are QML executed inside the shell process with your user's
privileges. The manifest is metadata, not a sandbox: only install code you
trust. Nothing loads at startup — a page or tab is created only when it is
opened or enabled — and a failure is reported in the settings page instead of
taking the shell down.

## Example

```sh
mkdir -p ~/.config/lilith/extensions
cp -r examples/extensions/hello ~/.config/lilith/extensions/hello
```

## Bundled extensions

The repository ships `calculator`, `maps`, `stopwatch`, `translator` and
`tuner` under `extensions/`; the installer and package put them in
`/usr/lib/lilith/share/extensions`. See `extensions/README.md` for what each
one does.
