# Session

How Maria Padilha starts, and how much of it a user can own without root.

`padilha-session` is the entry point used by the Hyprland configuration: it
compiles `init.lua` into the shell's JSON, paints the current wallpaper's
palette, and execs Quickshell. The systemd units in `systemd/user/` are the
path to letting the user manager own that lifetime instead.

## Units

| unit | what |
| --- | --- |
| `padilha-session.target` | the session's root; wants the two services below |
| `padilha-shell.service` | compile config, paint colours, run `qs -c caelestia -n` |
| `padilha-daylight.service` | the two-wallpaper clock, restarted on failure |

They are installed by the package and are inert until something starts
`graphical-session.target`. That something is `uwsm`, and it is the honest
limit of this layer today:

- `uwsm` is not installed here, and LightDM's `hyprland.desktop` starts
  Hyprland directly, without a user manager. `systemctl --user` does not even
  answer in that setup (checked: "Failed to connect to user scope bus"), so
  enabling these units would do nothing.
- What actually starts the desktop is `hypr/hyprland/execs.lua` calling
  `padilha-session`, and that path is Python-free and tested.

Switching to the units, once `uwsm` is installed:

```sh
# log out, pick "Hyprland (uwsm-managed)" at the greeter, log in, then:
systemctl --user daemon-reload
systemctl --user enable --now padilha-session.target
# and remove the padilha-session line from hypr/hyprland/execs.lua
```

The units call the commands installed in `/usr/bin`; the package installs them
verbatim, and `systemd-analyze --user verify` passes once the package is
installed. A checkout that has not been packaged still starts through
`execs.lua`, which calls its own `bin/`.

## Restore

`restore.sh` snapshots the *classes* of open windows and their workspaces, and
reopens them on the next login from a fixed allowlist of commands. It never
stores or runs arbitrary command lines, caps the number of windows
(`PADILHA_RESTORE_MAX`, default 8; the old `LILITH_RESTORE_MAX` is still
accepted), skips special workspaces, and waits `PADILHA_RESTORE_WAIT` seconds
for the session to settle (`LILITH_RESTORE_WAIT` is the fallback). Snapshot
state is under `~/.local/state/padilha` (or the old
`~/.local/state/lilith` while that is the one that exists).

Restore is opt-in: nothing calls it at login yet, because reopening windows
behind someone's back is worse than a fresh session.

```sh
session/restore.sh snapshot        # save now
session/restore.sh restore         # reopen the last snapshot
session/restore.sh restore --dry-run
session/restore.sh watch           # snapshot every minute
```

## The session entry

The package installs `/usr/share/wayland-sessions/maria-padilha.desktop`:

```ini
[Desktop Entry]
Name=Maria Padilha
Comment=Desktop Maria Padilha
Exec=hyprland
Type=Application
DesktopNames=Hyprland
```

Choosing "Maria Padilha" at the greeter therefore starts Hyprland with the
same user configuration as any other Hyprland entry. The configuration's
`execs.lua` starts `padilha-session`; the desktop file does not start the shell
by itself, which keeps a custom Hyprland configuration usable. `DesktopNames`
is kept so portals and toolkits see a Hyprland session.

## What still needs root

The greeter and display-manager configuration: `/etc/lightdm`, the session
`.desktop` file under `/usr/share/wayland-sessions`, and installing the units
system-wide. Those belong to the package, not to the user session.
