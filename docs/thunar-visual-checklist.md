---
layout: default
title: Thunar visual checklist
---

# Thunar visual checklist

Use this when changing `share/templates/thunar.css`. The stylesheet is rendered
into both GTK include points:

- `~/.config/gtk-3.0/thunar.css`
- `~/.config/gtk-4.0/thunar.css`

Check the same window in the light and dark palettes. The file is shared by the
GTK 3 build of Thunar and the GTK 4 port, so a selector must be valid in both.

## Layout and chrome

- [ ] The titlebar and window background use the generated surface, not a
      theme default. Window controls have breathing room and no clipped icons.
- [ ] Close, minimise and maximise buttons keep a circular pointer target; the
      close button uses the generated error container on hover, not a frozen
      red.
- [ ] Notebook tabs have a consistent top radius, 2px gaps, and a checked tab
      that is visibly attached to the content below it.
- [ ] The path bar has even 2px gaps between crumbs. Breadcrumb buttons,
      checked crumbs and the location entry share the same corner radius.
- [ ] The sidebar and the main view are separated by a 1px outline, not a wide
      empty paned gutter. Sidebar rows and the file frame have equal left and
      right padding.
- [ ] The status bar is inset from the window edges, has a 10px radius, and
      does not overlap the main view at the smallest window size.
- [ ] Menus and dialogs have the same 10px radius as the other raised
      surfaces, with a 6px menu inset and 12px dialog content padding.

## Views and selection

- [ ] Detailed list rows, compact list rows and icon-view cells all show the
      same hover tint and selected fill.
- [ ] Selected text in the list, icon, sidebar, tab and path bar is
      `onPrimaryContainer` on `primaryContainer`; no selected label turns into
      low-contrast primary-on-surface text.
- [ ] A focused selected row keeps a second, visible ring inside the selection
      instead of relying on colour alone.
- [ ] The rubberband has a solid primary edge and a translucent primary fill.
      It remains visible over both the list background and a selected row.
- [ ] Column headers stay readable and do not inherit the selected-row colours.
- [ ] Icon cells keep their spacing when selected; the selection does not
      jump or clip the label.

## Muted text and focus

- [ ] Disabled menu items, dialog hints and status text use
      `onSurfaceVariant`, not a low-alpha foreground.
- [ ] `Tab` and `Shift+Tab` walk the path bar, sidebar, main view, status bar
      and dialog buttons with a visible primary focus ring.
- [ ] `:focus` is never suppressed globally. The list, entries, toolbar
      buttons and dialog buttons all show the ring from the keyboard as well
      as with the pointer.
- [ ] The focus ring clears 3:1 against `surface`, `surfaceContainerLow` and
      `surfaceContainer`.
- [ ] The selected-text pair clears 4.5:1 in both palettes.

## Light and dark pass

- [ ] Apply a light scheme and a dark scheme, then reopen Thunar in each. The
      sidebar, frame and status bar stay distinguishable from the window
      surface without relying on a shadow.
- [ ] Switch back and forth without restarting Thunar; no colour is left over
      from the previous palette.
- [ ] Check both `gtk-3.0/thunar.css` and `gtk-4.0/thunar.css`; neither file
      contains a placeholder, an empty file or a hard-coded colour.

## Verify

```sh
python3 tests/theme/check-thunar-contrast.py .
bash tests/theme/run.sh
bash tests/all.sh
make lint
```

The contrast script generates the light and dark palettes across the fixture
seeds and variants and checks the text/selection pairs used by
`thunar.css`. The theme suite also renders both include points and asserts that
the generated CSS has no placeholders or hard-coded colours.

For a manual visual pass, use an empty workspace. Do not capture a terminal,
browser, private window or live notification.
