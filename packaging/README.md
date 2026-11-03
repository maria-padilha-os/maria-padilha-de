# Packaging

`makepkg -f` here builds `padilha`, from the checkout this file sits in (no
release tarball yet). The recipe runs the same CMake build as
`tools/build.sh`, then installs:

| path | what |
| --- | --- |
| `/usr/lib/qt6/qml/Caelestia/` | the shell's QML modules (CMake install rules) |
| `/etc/xdg/quickshell/caelestia/` | the shell tree; `qs -c caelestia` finds it |
| `/usr/lib/padilha/{bin,lib,share}` | the commands and the data they read next to themselves |
| `/usr/bin/padilha*` | symlinks into that tree |
| `/usr/lib/systemd/user/` | the optional session units |

The commands resolve their own path through `readlink -f`, which is why the
real files live under `/usr/lib/padilha` and `/usr/bin` only carries links.

Not packaged, on purpose: the Hyprland configuration, GTK/Qt CSS, and every
other generated theme file. They live in the user's `~/.config` and are written
by `padilha-theme`; the package ships the templates, not the output.

Known gap: the display-manager side (a Padilha session entry, greeter config)
is still the distribution's. See `session/README.md`.
