# Packaging

Build from the repo, not from here:

```sh
tools/release.sh          # tests, exports packaging/maria-padilha-<ver>.tar.gz, runs makepkg
```

`release.sh` refuses a dirty tree, so the tarball always matches a commit. The
recipe runs the same CMake build as `tools/build.sh`, then installs:

| path | what |
| --- | --- |
| `/usr/lib/qt6/qml/Caelestia/` | the shell's QML modules (CMake install rules) |
| `/etc/xdg/quickshell/caelestia/` | the shell tree; `qs -c caelestia` finds it |
| `/usr/lib/maria-padilha/{bin,lib,share}` | the commands and the data they read next to themselves |
| `/usr/bin/padilha*` | symlinks into that tree |
| `/usr/bin/lilith*` | compatibility symlinks for the old command names |
| `/usr/share/applications/padilha-mail.desktop` | the Mail launcher and `mailto:` handler |
| `/usr/lib/systemd/user/` | the optional session units |

The commands resolve their own path through `readlink -f`, which is why the
real files live under `/usr/lib/maria-padilha` and `/usr/bin` only carries
links.

The recipe declares `conflicts` and `provides` on the old `lilith` package, so
installing `maria-padilha` replaces it instead of leaving two copies in `/usr`.

Not packaged, on purpose: the Hyprland configuration, GTK/Qt CSS, and every
other generated theme file. They live in the user's `~/.config` and are written
by `padilha-theme`; the package ships the templates, not the output.

## Optional applications

`packaging/apps.list` is the catalogue of optional desktop applications. The
base package does not depend on them; each one is an `optdepends` entry and an
installer group. The first group is Office/Mail:

| group | package | launcher | why optional |
| --- | --- | --- | --- |
| `office-mail` | `thunderbird` | `padilha-mail` | email client and `mailto:` handler |

Install it with the package manager, or make the installer add the group:

```sh
sudo pacman -S --needed thunderbird
./install.sh --full --with-office-mail
```

`padilha-mail` exits cleanly with a short notice when Thunderbird is absent, so
the launcher and `mailto:` association do not become a hard dependency. The
handler only forwards the URI. Thunderbird keeps the account credentials in its
own profile; the Maria Padilha package never reads, writes, or logs them.

## Checkout or package?

While working on the code, the session can load the tree directly — this is
how the machine runs today:

- `~/.config/quickshell/caelestia` is a symlink to the checkout's `shell/`
  (user config outranks `/etc/xdg`)
- `hypr/hyprland/env.lua` sets `QML2_IMPORT_PATH` to the checkout's `build/qml`
  and puts its `bin/` first on `PATH`
- `hypr/hyprland/execs.lua` calls `padilha-session` from that `bin/`

Edits then land on the next shell restart.

To run the installed copy, remove the symlink and those two environment
lines, and point `execs.lua` at `/usr/bin`: `qs -c caelestia` then reads
`/etc/xdg/quickshell/caelestia` with modules from `/usr/lib/qt6/qml`, and
every change needs `tools/release.sh` plus `pacman -U`.

Known gap: the display-manager side (choosing the Maria Padilha session and
greeter configuration) is still the distribution's. The session entry itself is
packaged. See `session/README.md`.
