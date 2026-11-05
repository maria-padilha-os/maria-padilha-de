---
layout: default
title: Extensions
---

# Extensions

An extension adds a **tab to the top panel** (the dashboard), in the same tab
bar as Dashboard, Media, Performance and Weather. Settings → Extensions only enables
and disables them; the tab itself lives in the top panel, never inside the
settings window.

## Layout

```
~/.config/lilith/extensions/<id>/
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
    "tab": "Tab.qml"
}
```

- `tab` is the entry shown as a tab in the top panel.
- `icon` is a Material symbol name used in the tab bar.
- `name` becomes the tab title.

## Enabling

Settings → Extensions lists the installed extensions with an on/off switch.
Enabled tabs are appended after Weather, in the order the manifest names sort.
The enabled ids live in `dashboard.extensionTabs` in the shell config, so they
survive reloads.

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
`~/.config/lilith`, so use `api` for those services.

A tab declares its own `implicitWidth` and `implicitHeight`; the dashboard
sizes itself to the item. It can also declare `property bool active: true` —
the shell sets it to true only while the tab is selected, so network or audio
work should wait for that flag.

## Trust

Extensions are QML executed inside the shell process with your user's
privileges. The manifest is metadata, not a sandbox: only install code you
trust. Nothing loads at startup — a tab is created only when its extension is
enabled and the top panel is open.

## Bundled extensions

The repository ships `calculator`, `maps`, `stopwatch`, `translator` and
`tuner` under `extensions/`; the installer and package put them in
`/usr/lib/lilith/share/extensions`. See `extensions/README.md`.
