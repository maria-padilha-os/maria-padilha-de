# Session

How Padilha starts, and how much of it a user can own without root.

`padilha-session` is the entry point: it compiles `init.lua` into the shell's
JSON, paints the current wallpaper's palette, and execs Quickshell. Today
Hyprland's `execs.lua` calls it; the systemd units here are the path to
letting the user manager own the lifetime instead.

## Units

| unit | what |
| --- | --- |
| `padilha-session.target` | the session's root; wants the two services below |
| `padilha-shell.service` | compile config, paint colours, run `qs -c caelestia -n` |
| `padilha-daylight.service` | the two-wallpaper clock, restarted on failure |

They are installed to `/usr/lib/systemd/user` by the package. Enabling them is
a user operation, no root:

```sh
systemctl --user daemon-reload
systemctl --user enable --now padilha-session.target
```

The units hook into `graphical-session.target`, which is what `uwsm` (or
Hyprland's own systemd integration) brings up. Without either, `lightdm` starts
Hyprland directly and `execs.lua` remains the thing that starts the shell.

## Restore

`restore.sh` snapshots the *classes* of open windows and their workspaces, and
reopens them on the next login from a fixed allowlist of commands. It never
stores or runs arbitrary command lines, caps the number of windows
(`PADILHA_RESTORE_MAX`, default 8), skips special workspaces, and waits
`PADILHA_RESTORE_WAIT` seconds for the session to settle.

```sh
session/restore.sh snapshot        # save now
session/restore.sh restore         # reopen the last snapshot
session/restore.sh restore --dry-run
session/restore.sh watch           # snapshot every minute
```

## What still needs root

The greeter and display-manager configuration: `/etc/lightdm`, the session
`.desktop` file under `/usr/share/wayland-sessions`, and installing the units
system-wide. Those belong to the package, not to the user session.
