# AGENTS.md — maria-padilha-de (GitHub `maria-padilha-os/maria-padilha-de`)

Read the workspace-root `AGENTS.md` first; this is the repo-specific summary.
The checkout is `maria-padilha-de` and the GitHub remote is
`maria-padilha-os/maria-padilha-de`; the commands, package, session entry, and
user paths use the Maria Padilha name. Commands are `padilha-*` (plain
`padilha`); the old `lilith-*` commands remain as compatibility aliases.
Config lives in `~/.config/padilha` and state in `~/.local/state/padilha`;
during the transition `~/.config/lilith` and `~/.local/state/lilith` are
read-only fallbacks. `PADILHA_CONFIG` is primary and `LILITH_CONFIG` remains
the fallback.

Scope: Quickshell shell (`shell/`), session entry, theme engine (`lib/`,
`share/`), commands (`bin/`), installer (`install.sh`), package
(`packaging/`), docs (`docs/`), and tests (`tests/`).

## Safety

- Deployment is on hold: no Pages, package install, or donation
  publication. `tools/release.sh` may build a package; do not install it.
- The live shell is under a watchdog; do not run `padilha-reload` without a
  reason. Edit the checkout, test, and reload deliberately.
- Do not commit secrets. `hypr/hyprland/env.local.lua` is in the dotfiles repo
  and must never be copied here.
- Screenshots/GIFs: never capture the DSH terminal, Firefox, or private windows;
  use a dedicated empty workspace, verify it before capturing, and inspect
  frames before publishing. Do not full-screen record the live session.

## Commands

```sh
bash tests/all.sh
make lint
make docs
make package
./install.sh --dry-run --full
```

Keep `install.sh`'s `commands=(...)` and `packaging/PKGBUILD`'s symlink loop in
sync when adding a `bin/` command. The shell JSON is compiled by
`padilha-session`; a fresh clone needs `.scratch/gem` for the local docs preview
only.

## Style

- POSIX `sh` for `bin/`, Bash for tests; `set -eu` and quoted paths.
- Lua 5.5; require modules through `package.path` set by the command wrapper.
- QML uses the existing `Colours` singleton and `Quickshell` services; no
  hard-coded palettes except in generated state.
- Docs are one Jekyll site with `baseurl: /maria-padilha-de`.
