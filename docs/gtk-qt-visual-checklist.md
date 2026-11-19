---
layout: default
title: GTK and Qt visual checklist
---

# GTK and Qt visual checklist

Use this when changing `share/templates/gtk.css`, `qtlight.colors`,
`qtdark.colors` or `qtengine.json`. The GTK stylesheet is rendered twice, to:

- `~/.config/gtk-3.0/gtk.css`
- `~/.config/gtk-4.0/gtk.css`

The Qt colour scheme is rendered to
`~/.config/qtengine/caelestia.colors` and selected by
`~/.config/qtengine/config.json`. Both files use the same generated palette as
Thunar, so a dialog, menu, tooltip or file chooser should not drift from the
rest of the desktop.

## Audit summary

The GTK template started as a short libadwaita colour list. It was missing the
standard GTK compatibility names (`theme_*`, `insensitive_*`, `borders`,
`unfocused_*`, links and placeholders), the destructive/success/warning/error
families, and explicit rules for menus, tooltips, disabled text, selections,
focus rings, borders and file choosers. All of those now resolve to generated
scheme roles.

The Qt schemes had three readability problems: disabled text was blended
towards a surface by `ColorEffect=3`/`ColorAmount=0.5`, inactive foregrounds
used a different role from group to group, and the selection focus decoration
was the same colour as the selection fill. Disabled and inactive text now use
`onSurfaceVariant` directly, selection focus uses `onPrimaryContainer`, and all
colour groups carry the same foreground/background keys. The light and dark
WM sections had frozen RGB blend values; they now come from generated roles
through the template's `{{ $colour | rgb }}` filter.

`qtengine.json` carries no palette values: the widget style is a widget style,
not a colour, and the icon theme follows `{{ $mode }}`. The colour scheme path
is the file `padilha-theme apply` writes.

## Contrast targets

- [ ] Body text and disabled text are at least **4.5:1** against the surface
      behind them.
- [ ] Menu, tooltip and dialog text is at least **4.5:1**; the disabled menu
      item is still readable and visibly muted.
- [ ] Selected text is `onPrimaryContainer` on `primaryContainer` in GTK,
      Thunar and Qt.
- [ ] A focus ring is at least **3:1** against `surface`, `surfaceContainer`
      and `surfaceContainerHighest`.
- [ ] A focused selected row keeps a second, visible ring instead of relying on
      the selection fill alone.
- [ ] Borders and separators use `outline` when they are the only visual
      boundary of a control; `outlineVariant` is reserved for decorative
      separators that are not required to identify a control.

## GTK 3 and GTK 4

- [ ] Open a GTK 3 app, a GTK 4 app and a libadwaita app. The window, headerbar,
      sidebar, view, card and dialog backgrounds all use the palette rather
      than a stock theme colour.
- [ ] Open a menu and a popover. The background, border, hover row and disabled
      row are distinguishable, and the disabled label is not faded below body
      contrast.
- [ ] Hover and focus a tooltip. Its text clears 4.5:1 and its border is
      visible over both the window and a card.
- [ ] Open a file chooser. The places sidebar, path bar, list view, location
      entry and selected row use the same roles as Thunar's equivalents.
- [ ] Disable a button, entry, check box, radio button and switch. Each keeps a
      readable label and a visible disabled boundary.
- [ ] Tab through the dialog, menu, sidebar, file list and entry. Every stop
      shows the primary focus ring; no global rule suppresses it.
- [ ] Select a row with the pointer and then focus it with the keyboard. The
      selection fill does not swallow the focus ring.
- [ ] A selected entry has `onPrimaryContainer` text on `primaryContainer`, not
      primary-on-surface.
- [ ] Error, warning and success text and badges use the generated families,
      and the message still carries words or an icon rather than colour alone.

## Qt

- [ ] Launch an app under qtengine (`QT_QPA_PLATFORMTHEME=qtengine`). Its
      window, headerbar, view, button, tooltip and selection colours match the
      same light or dark palette.
- [ ] Open a context menu and a tooltip. The menu rows, disabled action and
      tooltip text are readable.
- [ ] Disable a toolbar action and a dialog button; the label stays above 4.5:1
      and the control still looks inactive.
- [ ] Focus a selected list item. The focus decoration is visible inside the
      selection fill.
- [ ] Check the active and inactive titlebar foregrounds in both modes; the
      inactive titlebar must remain readable.
- [ ] Confirm the light and dark files expose the same keys, so switching mode
      does not fall back to a stock colour for one group.

## Light, dark and switching

- [ ] Apply a light scheme and a dark scheme, then reopen a GTK 3 app, a GTK 4
      app, a libadwaita app and a Qt app in each.
- [ ] Switch back and forth without logging out. No menu, tooltip, disabled
      label or border is left over from the previous palette.
- [ ] Both `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` are present and identical;
      neither contains `{{`, an empty file or a frozen colour.
- [ ] The Qt colour file contains no frozen hex or RGB triple; the WM
      `activeBlend` and `inactiveBlend` lines are generated RGB values.
- [ ] Restart the app after the switch when it does not watch the colour file;
      Qt and GTK do not all reload a stylesheet live.

## Flatpak and portal caveats

The theme engine writes the host user config only. It never edits an app's
sandbox, cache or private copy of a theme.

- A Flatpak app has its own `~/.var/app/<application-id>/config`. It does not
  automatically see the host's `~/.config/gtk-3.0`, `gtk-4.0` or `qtengine`
  files. If it ignores the palette, that is a sandbox/portal configuration
  issue, not a reason to copy a generated file into the app's cache.
- libadwaita apps that use the XDG desktop portal follow the portal's
  `color-scheme` setting. If the light/dark preference does not follow the
  wallpaper, check that `xdg-desktop-portal` and the desktop's settings portal
  are running before changing any app file.
- Qt Flatpaks may bundle a platform theme and ignore the host
  `QT_QPA_PLATFORMTHEME`. A user-level Flatpak override that exposes the host
  theme is a deliberate opt-in; do not write into `~/.var/app/*/config` or
  `~/.var/app/*/cache` as part of a theme apply.
- The engine does not install packages, run a privileged helper or write under
  `/usr`. When a sandbox blocks the host config, report it instead of
  escalating.

## Verify

```sh
python3 tests/theme/check-gtk-qt-contrast.py .
python3 tests/theme/check-thunar-contrast.py .
bash tests/theme/run.sh
bash tests/all.sh
make lint
```

The contrast scripts generate the light and dark palettes across the fixture
seeds and variants, then check the text, disabled, selection, focus and border
pairs each stylesheet paints. The theme suite also renders both GTK include
points and both Qt modes and asserts that the generated files have no
placeholders or frozen colour values.

For a manual visual pass, use an empty workspace. Do not capture a terminal,
browser, private window or live notification.
