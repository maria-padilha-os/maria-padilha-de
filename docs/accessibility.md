---
layout: default
title: Accessibility and keyboard-only use
---

# Accessibility and keyboard-only use

Maria Padilha's shell is a Quickshell surface, not a toolkit application. This
page records what the shell guarantees, how to check it with a keyboard and a
screen reader, and the limits that are still real.

## Keyboard model

The shell registers shortcuts; your Hyprland configuration owns the actual
key combinations. The shell-side names are in `shell/modules/Shortcuts.qml`.

| surface | open it | move around | close / leave |
| --- | --- | --- | --- |
| Launcher | tap `Super` (`launcher`) | type, `Up` / `Down`, `Enter` | `Escape` |
| Dashboard | `dashboard` shortcut (`Super + Alt + D` in the reference config) | `Left` / `Right`, `Tab` | `Escape` |
| Taskbar | `taskbar` shortcut, or `Tab` out of an open panel | `Tab` / `Shift + Tab`, `Up` / `Down` on workspaces, `Enter` / `Space` on an item | `Escape` |
| Settings | `nexus` shortcut | `Tab`, `Up` / `Down` in the page list, `Enter` / `Space` | `Escape` closes a sub-page first, then the window |
| Extension tab | the extension's shortcut, or the dashboard tab strip | `Tab`, arrows for lists and sliders, `Enter` / `Space` | `Escape` |

`taskbar` puts keyboard focus on the bar without opening a panel. The shell
asks the compositor for keyboard focus only while the launcher, dashboard,
settings, sidebar or taskbar focus mode is active. Ordinary application
windows keep the keyboard the rest of the time.

Focus order follows the visual order: launcher search, launcher results,
dashboard tabs, dashboard content, taskbar entries; settings uses the page list
and then the page controls. Controls draw a two-pixel `m3primary` ring when
they hold keyboard focus. Focus is not moved by hover.

`Enter` and `Space` activate buttons, switches, radio buttons, menu items and
list rows. Text fields keep their normal editing keys; `Escape` closes the
launcher, dashboard, popout or settings sub-page without saving. Sliders accept
the arrow keys, `Home`, `End`, `Page Up` and `Page Down`.

## Screen-reader checklist

Run this on an empty workspace with Orca (or another AT-SPI screen reader). The
shell's Qt accessibility tree is intentionally conservative: decorative art,
separators and status glyphs are names, not controls.

- [ ] Start Orca, then open the launcher. The search field is announced as an
      editable search field with the placeholder text as its name.
- [ ] Type an application name. `Up` / `Down` announce each result name; the
      selected result says "selected"; `Enter` opens it.
- [ ] Open the dashboard. The tab strip announces each tab as a page tab and
      says which one is selected. `Left` / `Right` change tabs.
- [ ] In Settings, the page list announces the page label plus its description.
      `Enter` opens the page and `Escape` returns to the previous one.
- [ ] On the taskbar, the logo, clock, media item, workspaces, tray, settings
      and session buttons announce a name and their action. Status glyphs
      announce the state (for example "Battery 72%" or "Audio muted") without
      claiming to be buttons.
- [ ] A focused icon-only button announces its action, not the Material icon
      ligature. If a glyph is announced literally (for example `settings`),
      record the surface and treat it as a bug.
- [ ] Errors are announced as text and are not conveyed by red alone.

## Keyboard-only checklist

- [ ] Open and close the launcher with the keyboard; `Escape` returns focus to
      the application, not to a dead surface.
- [ ] Open the dashboard with its shortcut. `Left` / `Right` move between tabs,
      `Tab` reaches the tab content and `Escape` closes it.
- [ ] Press the `taskbar` shortcut. `Tab` moves through bar entries; `Enter` or
      `Space` opens the focused popout or settings; `Escape` closes the popout,
      then leaves taskbar focus.
- [ ] Open Settings. Navigate the page list with `Up` / `Down`, open a page
      with `Enter`, change a switch with `Space`, change a slider with the
      arrow keys, and leave a sub-page with `Escape`.
- [ ] Open every enabled extension tab. Every interactive control is reachable
      with `Tab` and activates with `Enter` or `Space`. The calculator keypad,
      Files list/dialog, Maps zoom controls, Translator pickers and Pomodoro
      duration controls are the important cases.
- [ ] Use only the keyboard for a full pass: launcher -> dashboard -> settings
      -> taskbar -> extension. No step requires a pointer.

## Font scaling and clipping

`appearance.font.scale` scales every `Tokens.font.*` builder. Labels use elide
or word wrap instead of fixed line counts, and the launcher rows, bar width and
settings rows grow with the scaled font rather than clipping.

- [ ] Set `appearance.font.scale = 1.5` (and then `2.0`) in
      `~/.config/padilha/local.lua`, run `padilha-config compile`, and reload
      the shell deliberately.
- [ ] Dashboard tab labels elide; they never overlap the tab indicator.
- [ ] Launcher result names and descriptions stay inside the row; long labels
      elide with their full text still available to the screen reader.
- [ ] Settings row labels and descriptions elide or wrap; the switch, slider
      and text field stay inside the card.
- [ ] Bar text and icons are not cut off at the top or bottom, and clock digits
      still fit the bar width.
- [ ] Buttons have room for two lines of the scaled label or elide it with a
      tooltip/accessible name.

## Contrast

The palette is generated from the wallpaper in `lib/scheme.lua`; components do
not carry their own light/dark overrides. `tests/accessibility/contrast.py`
checks body text, muted text, focus and error pairs for every seed, light/dark
mode and palette variant in `tests/fixtures/contrast.json`. The light `outline`
role is tone 40 rather than Material's 50 so small secondary text that uses
`m3outline` clears 4.5:1; `m3outlineVariant` remains a separator colour and is
not used for body text.

- [ ] Body text is at least 4.5:1 on its surface in both light and dark mode.
- [ ] Muted text is at least 4.5:1, including on the highest surface.
- [ ] Each focus ring is at least 3:1 against the surface behind it.
- [ ] Error text is at least 4.5:1, and errors also carry text or an icon, not
      just colour.
- [ ] Toasts, popouts and extension cards inherit the same palette roles.

## Reduced motion

Set `PADILHA_REDUCED_MOTION=1` in the session environment (for example in the
dotfiles' `hypr/hyprland/env.lua` or the systemd user unit) before starting the
shell. `0`, unset, or any other value leaves motion on. The mode:

- sets every `Anim`, `AnchorAnim` and `CAnim` duration to zero, including
  focus-ring, panel and state-layer transitions;
- disables the decorative animated logo and looping background motion;
- keeps state changes and progress updates visible without tweening.

`PADILHA_VERBOSE_STATE=1` is also available for components that can prefer a
text state (for example "Muted") over a glyph. It is optional; the names and
descriptions on the accessibility tree are always present.

- [ ] Start the shell with `PADILHA_REDUCED_MOTION=1`; opening the launcher,
      dashboard, settings and a popout does not animate position or opacity.
- [ ] Focus rings still appear immediately when tabbing.
- [ ] Progress, battery, volume and timer values still update; only the
      transitions are removed.
- [ ] Turn the variable off and confirm motion returns after a restart.

## Automated coverage

```sh
python3 tests/accessibility/contrast.py .   # palette contrast fixture
python3 tests/accessibility/check.py .      # static keyboard/name contract
bash tests/accessibility/run.sh             # both, plus the QML load harness
bash tests/all.sh
```

`tests/accessibility/load.qml` instantiates the shared focus ring, buttons,
search field, switch and radio button offscreen, checks their accessible names
and reduces-motion result, and runs with a minimal palette stub so it does not
need the live desktop. The extension suite already loads every extension tab.

## Known limits

- The shell cannot promise a native screen-reader experience for every custom
  canvas, map tile or animated illustration. Decorative content is exposed as
  static text or ignored; if a useful value is missing, report the surface.
- The lock screen and hyprlock are separate surfaces and are only covered by
  their own keyboard/Escape paths here.
- Hyprland owns the actual key combinations. If a shortcut name is not bound in
  your dotfiles, the shell-side behaviour exists but no key reaches it.
