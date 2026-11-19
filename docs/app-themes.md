---
layout: default
title: App themes
---

# Generated app themes

`padilha-theme apply` renders the current Material You palette into the
applications that can read a colour file. The templates live in
`share/templates/`; the generated files are the ones the applications actually
load. Editing a generated file only lasts until the next wallpaper, daylight or
theme change, so palette fixes belong in the template.

The coverage below is enforced by `tests/theme/check-app-contrast.py` and
`tests/fixtures/app-contrast.json`. The fixture names scheme roles rather than
literal colours, then checks every listed foreground/background pair against
several seeds and all four palette variants in both light and dark modes.

| App | Generated file | Template | Covered states |
| --- | --- | --- | --- |
| btop | `~/.config/btop/themes/caelestia.theme` | `share/templates/btop.theme` | Main text, selected process row, inactive text, graph labels, meter background, box borders and dividers, temperature/CPU/memory/network/process gradients |
| cava | `~/.config/cava/config` | `share/templates/cava.conf` | Explicit terminal background and foreground, eight-stop bar gradient, no inherited background from the previous terminal program |
| fuzzel | `~/.config/fuzzel/fuzzel.ini` | `share/templates/fuzzel.ini` | Entry text, prompt, placeholder, input, match, counter, selected row and its match, border; every colour is opaque |
| micro | `~/.config/micro/colorschemes/padilha.micro` | `share/templates/micro.micro` | Default and syntax text, comments, strings, identifiers, gutters, status/tab bars, selection, search, cursor line, diffs, whitespace warnings, divider |
| Midnight Commander | `~/.local/share/mc/skins/caelestia.ini` | `share/templates/mc-skin.ini`, `lib/mcskin.lua` | Panels, dialogs, menus, menus in the top/bottom bars, help, editor line state and frame, file highlights, diffs, selected/marked/disabled states |
| Spicetify | `~/.config/spicetify/Themes/caelestia/color.ini` | `share/templates/spicetify-dark.ini`, `share/templates/spicetify-light.ini` | Text, subtext, cards, sidebar, player, notifications and error notifications, selected row, hover highlight, buttons, equalizer; optional client theme |

## Reload behaviour

| App | How it picks up the new file |
| --- | --- |
| btop | `SIGUSR2` while running |
| cava | `SIGUSR2` while running |
| fuzzel | Reads its config on the next launch |
| micro | Reads the colourscheme on the next launch; select `padilha` as the colourscheme |
| Midnight Commander | The Maria Padilha fork reloads the skin on `SIGUSR1`; upstream mc keeps its current skin until restart |
| Spicetify | Run `spicetify apply` (or `spicetify refresh`) after the theme engine writes the file |

## Optional applications

btop, cava, fuzzel, micro and Midnight Commander are separate applications.
Maria Padilha writes their colour files when the app is present or configured,
but does not install a missing application just to apply a palette.

Spicetify is optional and is **not** bundled. It requires the user's own
Spotify client and a separately installed Spicetify CLI; Maria Padilha does not
install, download or redistribute Spotify or any Spotify assets. The theme
engine writes only the `color.ini` colour values. To use them:

```sh
spicetify config current_theme caelestia color_scheme caelestia
spicetify apply
```

If Spotify or Spicetify is absent, the generated file is inert. The
`enableSpicetify` switch still lets a user skip it entirely.

## Switches

Set the optional switches in `~/.config/padilha/theme.lua`; an omitted key means
enabled:

```lua
return {
    theme = {
        enableBtop = false,
        enableCava = false,
        enableFuzzel = false,
        enableMicro = false,
        enableMc = false,
        enableSpicetify = false,
    },
}
```
