# Upstream

Everything we sit on, pinned in `upstream.json`. "Aware" means: we know what
changed and why it matters to us, before it breaks a build.

| project | pin | role here | what to watch |
| --- | --- | --- | --- |
| [caelestia-shell](https://github.com/caelestia-dots/shell) | v2.5.0 | the base of `shell/` | every QML/C++ change is a merge into our tree; config schema additions are C++ |
| [caelestia-cli](https://github.com/caelestia-dots/cli) | v1.1.3 | reference for the theme engine we are replacing | palette maths, template set, `scheme.json` shape |
| [quickshell](https://github.com/quickshell-mirror/quickshell) | v0.3.2 | the QML runtime under the whole shell | API breaks, new modules, scene-graph changes |
| [Hyprland](https://github.com/hyprwm/Hyprland) | v0.56.2 | compositor, IPC, Lua config | dispatcher renames, config semantics, IPC surface |

## Checking

```sh
tools/upstream-watch.sh            # table: pin vs latest tag
tools/upstream-watch.sh --log      # commits between pin and latest, for shell/
tools/upstream-watch.sh --exit-code  # non-zero if anything moved, for CI
```

## Absorbing

1. Read the log, not the release notes — the notes describe upstream's intent,
   the log describes what actually happened to files we own.
2. Cherry-pick into `shell/` as ordinary commits, with the upstream hash in the
   message. Never re-introduce a `.patch` file.
3. If a change touches the config schema, update the C++ definition and the
   default in `upstream.json`'s project version in the same commit.
4. Rebuild, run, and keep it for a day before pinning. The watch tool only
   tells you that something moved; the desktop tells you whether it matters.

## The patches that will disappear

Three local patches exist today, applied to the `caelestia-shell` package:
`quicksettings.patch`, `bar-black.patch`, `lock-compose.patch`. They are the
reason this project exists — a patch stack over a package-owned tree that
already drifted once. When `shell/` builds and runs, each becomes a commit in
the tree and the patch files are deleted.
