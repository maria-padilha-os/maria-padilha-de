# Changelog

## 0.1.1 — unreleased; deployment on hold

This is the preparation state described in `DEPLOY.md`. No package, Pages site,
or promo timer has been published.

### Added

- Two install profiles: `--full` for the desktop session and `--rice` for an
  existing Hyprland session.
- The dotfiles split: `padilha-de` fetches or links `padilha-dotfiles` instead
  of carrying the configs.
- Vim-style focus, movement, resize, workspace, and monitor keys.
- The day/night brightness daemon with a four-hour manual hold.
- The shell watchdog (`padilha-shell-watch`) and its restart log.
- Terminal-transparent Midnight Commander skin surfaces.
- The promo-window agent scheduler prototype, including maintenance rounds,
  dry-run, status, stop, worktrees, and tests.
- A single GitHub Pages source under `docs/`, with the support page.
- GitHub Sponsor metadata in both repositories.

### Fixed

- WezTerm now owns its `0.85` opacity; the Hyprland class rule no longer
  multiplies it down to roughly `0.72`.
- The Hyprland focus border is 2px opaque `primary` (6.13:1 on the light
  surface), and the area picker uses the wallpaper accent.
- NvimTree follows the light `Normal` surface instead of staying on base46's
  dark group.
- The wallpaper state path uses the `padilha-de` checkout again after the
  organization move; the black desktop is gone.
- The unused `hypr/scheme/current.conf` was removed.

### Known issues

- s2idle suspend hangs on this AMD Mendocino laptop; lid close is configured to
  lock, not suspend.
- The shell lock screen crashed Quickshell once; automatic idle locking is
  disabled and only DPMS runs. Manual `Super+Escape` is still a risk.
- GitHub Pages is not enabled and the repositories are private.
- GitHub Sponsors enrollment and non-GitHub donation links are pending.
- The promo scheduler is not enabled; its window schedule is a placeholder.
