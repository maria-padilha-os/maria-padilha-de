# AGENTS.md — lilith-de (GitHub `lilith`)

Read `/home/machine/Códigos/lilith/AGENTS.md` first; this is the repo-specific
summary. The checkout is `lilith-de` and the GitHub remote is `lilith`; the commands,
package, session entry, and user paths use the Lilith name. The old `padilha-*` commands remain as temporary compatibility aliases.

Scope: Quickshell shell (`shell/`), session entry, theme engine (`lib/`,
`share/`), commands (`bin/`), installer (`install.sh`), package
(`packaging/`), docs (`docs/`), and tests (`tests/`).

## Safety

- Deployment is on hold: no Pages, package install, promo timer, or donation
  publication. `tools/release.sh` may build a package; do not install it.
- The live shell is under a watchdog; do not run `lilith-reload` without a
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
`lilith-session`; a fresh clone needs `.scratch/gem` for the local docs preview
only.

## Style

- POSIX `sh` for `bin/`, Bash for tests; `set -eu` and quoted paths.
- Lua 5.5; require modules through `package.path` set by the command wrapper.
- QML uses the existing `Colours` singleton and `Quickshell` services; no
  hard-coded palettes except in generated state.
- Docs are one Jekyll site with `baseurl: /lilith`.
