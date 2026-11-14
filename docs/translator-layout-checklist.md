---
layout: default
title: Translator layout checklist
---

# Translator layout checklist

Use this when changing the translator tab. The translation provider is
MyMemory and must stay unchanged by layout work; the contract is enforced by
`tests/translator/check.py`.

## Layout

- [ ] The widget fills the dashboard tab inside `Tokens.padding.*`; it does not
      shrink to a fixed centred card.
- [ ] At `480×280` the compact layout keeps the language labels (`From` /
      `To`), both panel labels (`Source` / `Result`), the character count, the
      status line, Copy and Translate inside the tab.
- [ ] At the full dashboard size the source and result panels grow with the
      tab instead of staying at the compact height.
- [ ] The source panel has a readable minimum height
      (`minimumSourceHeight`) before the result panel takes the remaining
      space.
- [ ] The language row is its own row. The swap button lives there; Translate
      and Copy live in the footer, so neither collides with a picker.
- [ ] The result panel is a clipped `ScrollView`; long translations scroll
      instead of pushing the footer out of the tab.
- [ ] The status text elides or wraps at the narrow width; it never clips the
      buttons.

## States and interaction

- [ ] Opening the tab with an empty source prefills clipboard text (truncated
      to 500 characters) and focuses the source editor.
- [ ] Copy is only visible when there is a result and copies the result text.
- [ ] Both language pickers open, choose, swap and collapse without leaving the
      tab.
- [ ] `Ctrl+Enter` translates from either text area.
- [ ] While busy the pickers, Swap and Translate are disabled, the Translate
      label says `Translating…`, and the status line explains what is
      happening.
- [ ] A network, quota, length or empty-result error stays in the status line
      and uses `m3error`.
- [ ] Tab, Return and Space reach and activate the pickers, Swap, Copy and
      Translate; focused buttons and text fields have a visible focus ring.

## Palette and spacing

- [ ] Colours come from `api.colours.palette` (`m3onSurface`,
      `m3surfaceContainerHigh`, `m3primary`, `m3error`, …); no hex values or CSS
      colour names are added.
- [ ] Hover and focus states are derived from palette roles, not
      `Qt.lighter`/`Qt.darker`.
- [ ] Spacing, padding, rounding and fonts use `Tokens.*`; no one-off pixel
      padding or font sizes are added.

## Verify

```sh
bash tests/translator/run.sh
bash tests/all.sh
make lint
```

The QML test loads the real translator tab offscreen with `active: false` at
`480×280`, a short `1000×320` dashboard and a roomy `1000×600` dashboard. It
checks the compact switch, source/result minimums,
full padded width, non-overlapping rows, visible labels/status, scrollable
result and keyboard reachability. It does not read the clipboard, make a
network request or open a window on the live desktop.

For a manual visual pass, use an empty workspace and a throwaway offscreen
render. Do not capture a terminal, browser, private window or live
notification.
