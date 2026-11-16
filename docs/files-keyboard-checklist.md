---
layout: default
title: Files keyboard checklist
---

# Files keyboard checklist

Use this checklist when changing the Files dashboard tab or the file dialog.
The automatic suites cover the binding table and QML loading; this page covers
the parts that need a real keyboard and pointer.

## Files tab: normal mode

- [ ] Open the Files tab with `Super + Alt + E`; the file list has a visible
      focus ring and the first row is selected.
- [ ] `Up` / `Down` move the selection and keep it in view.
- [ ] `Enter` opens the selected folder or file; `Backspace` goes to the
      parent folder.
- [ ] `Ctrl + L` focuses the path/address field with its text selected. Type a
      path, press `Enter`, and the list navigates there. `Esc` cancels.
- [ ] `Ctrl + F` opens search. Typing letters inserts text, not Vim commands.
      `Esc` clears the search and returns focus to the list.
- [ ] `Tab` / `Shift + Tab` reach the toolbar buttons and the Vim toggle with a
      visible focus ring. `Space` / `Enter` activate the focused control.
- [ ] Click a row to select it; double-click a row to open it. The scrollbar
      and mouse wheel still work.

## Files tab: Vim mode

Enable Vim mode with the **Vim** toggle in the tab header. The small mode
indicator reads `NORMAL`.

- [ ] `j` / `k` move down / up.
- [ ] `h` goes to the parent folder; `l` opens the selected entry.
- [ ] `g` then `g` jumps to the first entry; `G` jumps to the last.
- [ ] `Ctrl + d` pages down; `Ctrl + u` pages up.
- [ ] `/` opens search, the indicator reads `SEARCH`, and normal typing stays
      in the search box. `Enter` opens the selected result; `Esc` clears the
      search and returns the indicator to `NORMAL`.
- [ ] `Enter` still opens the selected entry.
- [ ] Focus the search box or the address field, then press `j`, `k`, `h`, `l`,
      `g`, or `G`; they type normally and never move the list.
- [ ] Turn Vim mode off; arrows, `Enter`, `Backspace`, search, the address bar
      and the mouse behave exactly as in normal mode.

## File dialog: sidebar and address bar

- [ ] Open a file dialog (for example from the wallpaper picker).
- [ ] The sidebar places, the breadcrumb/address bar, and the file grid show a
      visible focus ring when focused.
- [ ] `Ctrl + B` focuses the selected sidebar place (or Home). `Enter` or
      `Space` opens it.
- [ ] `Ctrl + L` focuses the last breadcrumb. `Left` / `Right` move between
      crumbs, and `Enter` / `Space` navigate to the focused crumb.
- [ ] `Alt + Up` goes to the parent folder; `F6` focuses the file grid.
- [ ] Typing in any future text field is never intercepted by a single-letter
      shortcut.
- [ ] Single click selects a file; double-click opens a folder or accepts a
      file; `Enter` still accepts the selected file.

## Safety

- [ ] No single key deletes, moves, renames or overwrites a file. There is no
      destructive binding in the Files table.
- [ ] Any future delete or move action asks for explicit confirmation first.

## Automated coverage

```sh
bash tests/filemanager/run.sh
```

The suite checks the binding table, the QML load and focus switch, the absence
of destructive bindings, the sidebar/address-bar focus markers, and this
checklist file.
