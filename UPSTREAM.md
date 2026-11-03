# Upstream

Everything we sit on, pinned in `upstream.json`. "Aware" means: we know what
changed and why it matters to us, before it breaks a build.

| project | pin | role here | what to watch |
| --- | --- | --- | --- |
| [caelestia-shell](https://github.com/caelestia-dots/shell) | v2.5.0 | the base of `shell/` | every QML/C++ change is a merge into our tree; config schema additions are C++ |
| [caelestia-cli](https://github.com/caelestia-dots/cli) | v1.1.3 | replaced: no code path executes it now | the `scheme.json` role names, which the shell still reads |
| [quickshell](https://github.com/quickshell-mirror/quickshell) | v0.3.2 | the QML runtime under the whole shell | API breaks, new modules, scene-graph changes |
| [Hyprland](https://github.com/hyprwm/Hyprland) | v0.56.2 | compositor, IPC, Lua config | dispatcher renames, config semantics, IPC surface |

## Checking

```sh
tools/upstream-watch.sh            # table: pin vs latest tag
tools/upstream-watch.sh --log      # commits between pin and latest, for shell/
tools/upstream-watch.sh --exit-code  # non-zero if anything moved, for CI
tools/upstream-diff.sh             # what moved in the files this tree touched
tools/upstream-diff.sh main --patch  # those hunks, per file
```

## Absorbing

1. Start with `tools/upstream-diff.sh`. It limits the review to the files this
   tree actually changed; upstream churn elsewhere is not our merge.
2. Read the log, not the release notes — the notes describe upstream's intent,
   the log describes what actually happened to files we own.
3. Cherry-pick into `shell/` as ordinary commits, with the upstream hash in the
   message. Never re-introduce a `.patch` file.
4. If a change touches the config schema, update the C++ definition and the
   default in `upstream.json`'s project version in the same commit.
5. Rebuild, run, and keep it for a day before pinning. The watch tool only
   tells you that something moved; the desktop tells you whether it matters.

## The patches that will disappear

The patch stack that motivated this project — `quicksettings.patch`,
`bar-black.patch`, `lock-compose.patch` over the `caelestia-shell` package —
is folded. Each is now an ordinary commit in `shell/`, plus a fourth change
(`settings.watchFiles`) that had only ever existed in the deployed copy. The
files in `~/.config/caelestia/` stay until the dotfiles repo stops being the
session's source; nothing reads them anymore.
