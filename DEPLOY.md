# Release and deployment readiness

**Status: not deployed.** The project is being prepared; nothing in this file
has been executed against a clean machine, a public repository, a display
manager, or the promo scheduler.

## Current hold

Do not, until this checklist is signed off:

- run `install.sh` for real (only `--dry-run` is allowed);
- enable GitHub Pages or make the repositories public;
- install/enable the promo-agent system timer;
- build and publish a release package or tag a release;
- enroll or publish donation links.

The `known-good-2026-11-04` tags in `maria-padilha-de` and `maria-padilha-dotfiles` are
rollback points, not releases.

## Preflight

Run from `maria-padilha-de` unless stated otherwise.

- [ ] `git status` is clean in both repositories.
- [x] `bash tests/all.sh` passes.
- [x] GitHub Actions is green for `maria-padilha-de`; the dotfiles repo has no CI.
- [x] `./install.sh --dry-run --full` and `--rice` print a sane plan.
- [x] `./install.sh --dry-run --full --no-dotfiles` leaves `~/.config` alone.
- [x] `tools/promo-agents --config tools/promo-agents.example.toml --dry-run`
      and `--status` behave; `tests/cli/promo-agents.sh` passes.
- [x] No secret is tracked: `git grep -nE 'sk-[A-Za-z0-9]{20,}'` must be empty;
      `dotfiles/hypr/hyprland/env.local.lua` is ignored.
- [x] `dotfiles` is not present in `maria-padilha-de`; the installer can fetch the
      sibling `maria-padilha-dotfiles`.
- [x] The release package builds with `tools/release.sh`; it was not installed
      on the live system. A disposable `pacman --root` install verified the
      `/usr/bin` links, `padilha-shell-watch`, session entry, and user units.
- [x] `docs/` builds with Jekyll 4.4.1 + minima (`jekyll build --source docs`),
      warnings only; Pages is still disabled. One docs site, not per-project
      Pages.
- [x] The current release version and changelog are decided
      (`packaging/PKGBUILD` 0.1.1, `CHANGELOG.md`).
- [ ] A clean VM or spare user account is available for the first real install.
      The disposable root checks layout only, not a login/session.
- [x] Suspend is still known-broken; do not include it in a demo.

## Build and package (later)

```sh
tools/release.sh                 # tests, export, makepkg
sudo pacman -U packaging/maria-padilha-<version>-1-x86_64.pkg.tar.zst
```

The direct installer path is separate; it is not tracked by pacman. Pick one
deployment path and document it for users.

## First real install (later)

1. Back up the target `~/.config/{hypr,nvim,wezterm}` and any existing session.
2. Run `./install.sh --full` (or `--rice`) from the checkout.
3. Reboot/log out; confirm the Maria Padilha session, bar, launcher, lock, and a fresh
   terminal.
4. Test the dotfiles: Hyprland reload, WezTerm config, Neovim theme, MC skin.
5. Test the failure paths: shell watchdog restart, display-manager fallback,
   TTY access.
6. Record what changed and where the backups are.

## Docs and funding (later)

- Enable Pages only after the repository visibility decision is made. Private
  repositories may need a paid plan; the fallback is a public docs mirror.
- Enroll in GitHub Sponsors or add Ko-fi/Liberapay/Pix to
  `.github/FUNDING.yml` before advertising a support button.
- Keep the GPL-3.0-only terms and the “donations do not unlock features” rule.

## Promo scheduler (later)

The scheduler is not enabled. Before it is:

- [ ] Verify the actual DeepSeek discount windows and timezone.
- [ ] Set a token/cost ceiling and a model choice.
- [ ] Write queue tasks; confirm maintenance rounds cannot churn.
- [ ] Run a dry-run and one supervised window with `push = false`.
- [ ] Review the worktrees/branches manually before enabling pushes or PRs.

## Rollback

- Code: check out `known-good-2026-11-04` in the affected repository.
- Configs: the installer backs up real directories as
  `~/.config/<name>.pre-padilha-<timestamp>`.
- Package: `sudo pacman -Rns maria-padilha`.
- Direct install: remove `/usr/lib/maria-padilha`, the `/usr/bin/padilha*` links, the
  session entry, and the optional systemd units.
- Pages: disable Pages in repository settings; no user data is involved.
- Promo timer: `sudo systemctl disable --now padilha-agents.timer`.

## Open deployment decisions

- repository visibility and the GitHub Pages plan;
- donation platform/handle;
- package versioning and release cadence;
- `maria-padilha-os` timing (after `maria-padilha-de` and `maria-padilha-dotfiles` have tagged
  releases);
- whether the direct installer or the package is the primary user path.
