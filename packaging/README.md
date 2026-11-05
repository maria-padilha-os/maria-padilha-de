# Packaging

Build from the repo, not from here:

```sh
tools/release.sh          # tests, exports packaging/lilith-<ver>.tar.gz, runs makepkg
```

`release.sh` refuses a dirty tree, so the tarball always matches a commit. The
recipe runs the same CMake build as `tools/build.sh`, then installs:

| path | what |
| --- | --- |
| `/usr/lib/qt6/qml/Caelestia/` | the shell's QML modules (CMake install rules) |
| `/etc/xdg/quickshell/caelestia/` | the shell tree; `qs -c caelestia` finds it |
| `/usr/lib/lilith/{bin,lib,share}` | the commands and the data they read next to themselves |
| `/usr/bin/lilith*` | symlinks into that tree |
| `/usr/lib/systemd/user/` | the optional session units |

The commands resolve their own path through `readlink -f`, which is why the
real files live under `/usr/lib/lilith` and `/usr/bin` only carries links.

The recipe declares `conflicts` and `provides` on the old `padilha` package, so
installing `lilith` replaces it instead of leaving two copies in `/usr`.

Not packaged, on purpose: the Hyprland configuration, GTK/Qt CSS, and every
other generated theme file. They live in the user's `~/.config` and are written
by `lilith-theme`; the package ships the templates, not the output.

## Checkout or package?

While working on the code, the session can load the tree directly — this is
how the machine runs today:

- `~/.config/quickshell/caelestia` is a symlink to the checkout's `shell/`
  (user config outranks `/etc/xdg`)
- `hypr/hyprland/env.lua` sets `QML2_IMPORT_PATH` to the checkout's `build/qml`
  and puts its `bin/` first on `PATH`
- `hypr/hyprland/execs.lua` calls `lilith-session` from that `bin/`

Edits then land on the next shell restart.

To run the installed copy, remove the symlink and those two environment
lines, and point `execs.lua` at `/usr/bin`: `qs -c caelestia` then reads
`/etc/xdg/quickshell/caelestia` with modules from `/usr/lib/qt6/qml`, and
every change needs `tools/release.sh` plus `pacman -U`.

Known gap: the display-manager side (choosing the Lilith session and greeter
configuration) is still the distribution's. The session entry itself is
packaged. See `session/README.md`.
