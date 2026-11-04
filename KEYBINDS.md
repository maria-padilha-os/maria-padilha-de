# Keyboard shortcuts

Padilha uses **Super** as its main modifier (the Windows/Command key). Tap
Super alone to open the launcher.

The live definitions are `~/.config/hypr/hyprland/keybinds.lua` and
`~/.config/hypr/variables.lua`. This page mirrors them: when a binding changes,
change this file in the same commit.

## Vim navigation

| keys | action |
| --- | --- |
| `Super + h/j/k/l` | focus window left / down / up / right |
| `Super + Shift + h/j/k/l` | move window left / down / up / right |
| `Super + Ctrl + h/j/k/l` | resize: `h`/`l` width, `k`/`j` height |
| `Super + Alt + h/l` | previous / next workspace |
| `Super + Alt + k/j` | previous / next monitor |
| `Super + Alt + Shift + h/l` | move window to previous / next workspace |
| `Super + Alt + Shift + k/j` | move window to previous / next monitor |
| `Super + Alt + S` | move window to the special workspace |
| `Super + Ctrl + Shift + k/j` | move window to / from the special workspace |

`Ctrl + Super + Shift + h/l` also moves a window between workspaces.

## Workspaces

| keys | action |
| --- | --- |
| `Super + 1…0` | switch to workspace 1…10 |
| `Super + Alt + 1…0` | move window to workspace 1…10 |
| `Super + Shift + 1…0` | move window silently (stay on this workspace) |
| `Ctrl + Super + 1…0` | focus workspace group 1…10 |
| `Ctrl + Super + Alt + 1…0` | move window to workspace group 1…10 |
| `Super + Alt + h/l` | previous / next workspace |
| `Super + Page Up/Down` | previous / next workspace |
| `Super + scroll up/down` | previous / next workspace |
| `Super + Alt + Page Up/Down` | move window to previous / next workspace |
| `Super + Alt + scroll up/down` | move window to previous / next workspace |
| `Ctrl + Super + scroll up/down` | previous / next workspace group |
| `Super + S` | toggle the special workspace |
| `Super + M` / `D` / `R` | music / communication / todo workspace |
| `Ctrl + Shift + Escape` | system-monitor workspace |

## Monitors

| keys | action |
| --- | --- |
| `Super + Alt + k/j` | previous / next monitor |
| `Super + Alt + Shift + k/j` | move window to previous / next monitor |

Monitor order follows Hyprland's monitor IDs.

## Windows

| keys | action |
| --- | --- |
| `Super + Q` | close window |
| `Super + F` | fullscreen |
| `Super + Alt + F` | bordered fullscreen |
| `Super + Alt + Space` | toggle floating |
| `Ctrl + Super + Backslash` | centre window |
| `Ctrl + Super + Alt + Backslash` | normalise window (55% × 70%, centred) |
| `Super + Alt + Backslash` | picture-in-picture (float, pin, move) |
| `Super + P` | pin window |
| `Super + Minus` / `Equal` | shrink / grow width |
| `Super + Shift + Minus` / `Equal` | shrink / grow height |
| `Super + Z` + drag | move window |
| `Super + X` + drag | resize window |
| `Alt + Tab` / `Shift + Alt + Tab` | cycle windows |
| `Ctrl + Alt + Tab` / `Ctrl + Shift + Alt + Tab` | cycle window groups |
| `Super + Comma` | toggle window group |
| `Super + Shift + Comma` | lock the active group |
| `Super + U` | ungroup |

## Shell

| keys | action |
| --- | --- |
| tap `Super` | launcher |
| `Super + N` | sidebar |
| `Super + Shift + P` | show all panels |
| `Super + Alt + D` / `M` / `P` / `W` | dashboard: dash / media / performance / weather |
| `Ctrl + Alt + C` | clear notifications |
| `Ctrl + Alt + Delete` | session menu |
| `Super + Escape` | lock |
| `Super + Alt + Escape` | restore lock (restart shell, then lock) |
| `Super + Shift + Escape` | sleep-disabled notice (suspend/hibernate are broken here) |
| `Ctrl + Alt + V` | audio settings (`pwvucontrol`) |

## Applications

| keys | action |
| --- | --- |
| `Super + T` / `Super + Return` | terminal (`wezterm`) |
| `Super + W` / `Super + B` | browser (`firefox`) |
| `Super + C` | editor (`nvim` in a terminal) |
| `Super + E` | file explorer (`thunar`) |
| `XF86Calculator` | calculator (`galculator`; or `>calc 2+2` in the launcher) |
| `XF86Search` | launcher |

## Screenshots, recording, colour

| keys | action |
| --- | --- |
| `Print` | full screenshot |
| `Super + Shift + S` | freeze-frame screenshot |
| `Super + Shift + Alt + S` / `Super + Shift + 4` | region screenshot |
| `Ctrl + Alt + R` | record screen |
| `Super + Alt + R` | record with sound |
| `Super + Shift + Alt + R` | record a region |
| `Super + Shift + C` | colour picker |
| `Super + Shift + R` | reload Hyprland |
| `Ctrl + Super + Shift + R` | stop the shell |
| `Ctrl + Super + Alt + R` | restart the shell (`padilha-reload`) |

## Media, volume, brightness

| keys | action |
| --- | --- |
| `Ctrl + Super + Space` | play / pause |
| `Ctrl + Super + Equal` / `Minus` | next / previous track |
| `Ctrl + Super + Backspace` | stop |
| `Super + Shift + M` | mute |
| `XF86AudioRaiseVolume` / `LowerVolume` | volume |
| `XF86AudioMute` / `XF86AudioMicMute` | mute output / microphone |
| `XF86MonBrightnessUp` / `Down` | brightness |

## Clipboard and emoji

| keys | action |
| --- | --- |
| `Super + V` | clipboard history |
| `Super + Alt + V` | clipboard history in delete mode |
| `Ctrl + Shift + Alt + V` | paste the latest clipboard entry |
| `Super + Period` | emoji and glyph picker |

## Mouse

| keys | action |
| --- | --- |
| `Super + Z` + drag | move the window |
| `Super + X` + drag | resize the window |
| `Super + scroll up/down` | previous / next workspace |
| `Super + Alt + scroll up/down` | move window to previous / next workspace |

The Hyprland configuration is user-owned and is not installed by the package;
this page is the reference, not the source. See `session/README.md` for how the
session starts.
