---
layout: default
title: Plugins
---

# Plugins

A plugin is a directory under `~/.config/lilith/plugins/` with a manifest and a
QML entry point. Settings → Plugins lists what is installed and opens the entry
inside the settings window.

## Manifest

`plugin.json`:

```json
{
    "name": "Hello",
    "description": "Minimal demo plugin",
    "version": "1.0",
    "entry": "Page.qml"
}
```

`entry` defaults to `Page.qml`.

## Entry

A QML file whose root item is shown in the settings content area. The shell's
modules are on the import path, so a plugin can use `qs.services`,
`Caelestia.Config`, `Caelestia.I18n`, and the `qs.components` controls.

## Trust

Plugins are QML executed inside the shell process with your user's privileges.
The manifest is metadata, not a sandbox: only install code you trust. Nothing
loads at startup — a plugin runs only when you open it from Settings → Plugins,
and a failing entry reports an error instead of taking the shell down.

## Example

Copy the demo from the checkout:

```sh
mkdir -p ~/.config/lilith/plugins
cp -r examples/plugins/hello ~/.config/lilith/plugins/hello
```
