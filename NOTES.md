# Padilha development notes

Snapshot: 2026-11-04, after the dotfiles split and the first repo-owner agents
were started. This is the internal working record; user-facing docs are in
`README.md`, `INSTALL.md`, `docs/`, and `KEYBINDS.md`.

## Repositories

| path | remote | role | owner |
| --- | --- | --- | --- |
| `~/Códigos/padilha/padilha-de` | `Mateus-M-Reis/padilha` | shell, session, theme engine, installer, package | agent `3a98b400…` |
| `~/Códigos/padilha/padilha-dotfiles` | `Mateus-M-Reis/padilha-dotfiles` | Hyprland, nvim, wezterm configs (the rice) | agent `2aec77cd…` |
| `~/Códigos/padilha` | not a git repo | org root, `README.md`, `bootstrap.sh` | coordinator |
| `padilha-os` | not created | archiso/Calamares image | future |

Both repositories are private at the moment. The org root is intentional: it
is not a repository and does not use submodules. `bootstrap.sh` clones the
siblings; the desktop installer fetches `padilha-dotfiles` next to itself when
it is missing.

## Decisions made

- **One documentation site, not one Pages site per repository.** The Jekyll
  source is `padilha-de/docs/`; it has sections for desktop, dotfiles, and
  (later) OS. `baseurl` is `/padilha`. Per-project Pages would duplicate
  navigation and split search.
- **Two install profiles.** `./install.sh --full` installs the desktop session
  and all dotfiles; `--rice` installs the shell, commands, and Hyprland config
  only. Existing real config directories are backed up as
  `~/.config/<name>.pre-padilha-<timestamp>`.
- **Dotfiles are a separate repository.** `padilha-de` no longer carries the
  configs; it fetches `padilha-dotfiles` next to itself or uses
  `PADILHA_DOTFILES`.
- **The old `bin/padilha-dots` moved** to `padilha-dotfiles/bin/padilha-dots`.
- **Donations, not paywalls or ads.** Padilha stays GPL-3.0-only. The GitHub
  Sponsor button is configured through `.github/FUNDING.yml`; Ko-fi,
  Liberapay, Open Collective, or Pix can be added to the same file. GitHub
  Sponsors enrollment is still pending.
- **DeepSeek promo work is opt-in and scheduled**, never an always-on loop at
  full price. See the design below.
- **Deployment is on hold.** Nothing is published or installed on a clean
  machine; the release checklist lives in `DEPLOY.md`. Preparation work, tests,
  dry-runs, and local live fixes continue, but no Pages, no release package, no
  promo timer, and no donation publication until that checklist is signed off.

## Current state

- Shell, session, installer, theme engine, and package build and tests pass.
- Vim-style keymap and `KEYBINDS.md` are in place.
- Brightness follows a day/night curve with a four-hour manual hold; zram is
  active; `hypridle` only powers the panel down after five minutes. Auto-lock is
  disabled until the shell lock is fixed.
- Neovim has an opt-in `caelestia` colorscheme (ayu-like light/dark, tinted by
  the wallpaper). The base46 ayu themes remain intact.
- WezTerm owns its `0.85` surface opacity. Hyprland's WezTerm-specific rule is
  now `1.0 override`, so the compositor adds no second dimming layer; the
  global `0.95` rule still applies to other windows.
- Hyprland focus border is 2px opaque `scheme.primary` (`#904b3e` on the light
  surface, 6.13:1 contrast); the area picker overlay uses `m3primary`. The
  audit recommended keeping `primary` as the wallpaper-derived accent.
- The stale, unused `hypr/scheme/current.conf` was removed; Hyprland loads
  `scheme.current` only.
- Suspend is **broken** on this AMD Mendocino laptop: s2idle hangs, so lid
  close is configured to lock, not suspend. Do not test suspend without warning.
- Docs/funding scaffold committed as `a627fff`: `docs/`, `SUPPORT.md`,
  `FUNDING.yml`, and README links.
- Dotfiles split committed as `5fc741b`; the dotfiles repository is pushed.
- MC skin surfaces now emit MC's `default` background, so the live skin was
  regenerated from the current scheme without recomputing the palette. Semantic
  blocks (selection, error, diff, focus accents) stay opaque for contrast.
  Restart MC to load it.
- Promo-window scheduler prototype at `tools/promo-agents`: config-driven
  windows, one headless `dsh` per repo, git worktrees, stop margin, tests,
  branch handoff, `--dry-run`/`--status`/`--stop`; system timer documented.
  Not enabled.
- Scheduler maintenance pass (2026-11-04): `--once` is a real flag (the timer
  unit was calling a flag argparse rejected); `--stop`/`--daemon` crashed
  because `datetime.time` shadowed the `time` module; a PID from an earlier
  boot is finalized but never signalled; `killpg(0)` is impossible; SIGTERM is
  followed by a configurable grace and SIGKILL; a failed launch does not consume
  a maintenance round; dry runs write nothing; branch/worktree names no longer
  collide within the same second. New `tests/cli/promo-agents.sh` (23 checks)
  is part of `tests/all.sh`.
- The black desktop was the stale wallpaper path left by the org move; it is
  repaired to `padilha-de/share/wallpapers/day.jpg`. NvimTree had no
  `NvimTree*` groups in the caelestia colorscheme, so its window stayed on
  base46's dark group; it now follows the light surface and will follow
  `Normal` at night.

## Open work

1. **Deployment readiness, on hold.** `DEPLOY.md` is the preflight: tests, dry
   runs, package build, docs preview, clean-VM install, rollback. Do not execute
   the deployment steps yet.
2. **Configure and enable the promo scheduler.** Copy
   `tools/promo-agents.example.toml` to `~/.config/padilha/agents.toml`, fill in
   the verified DeepSeek windows/timezone and cost cap, create queue tasks, and
   install the timer. The schedule in the example is a placeholder; do not
   enable this before deployment readiness either.
3. **GitHub Pages activation.** `docs/README.md` documents Settings → Pages →
   main `/docs`. Private repositories may need a paid plan or a public docs
   mirror. The site is one site, not per project.
4. **Funding links.** GitHub Sponsors handle is wired; enrollment is a user
   action. Add Ko-fi/Liberapay/Pix to `.github/FUNDING.yml` when chosen.
5. **`padilha-os`.** Not started; it should be an archiso/Calamares repository
   that consumes the tagged `padilha-de`/`padilha-dotfiles` packages.

## Agent ownership and coordination

The intended shape is one long-lived owner per repository:

- `padilha-de` owner: shell, session, theme engine, installer, package, docs;
- `padilha-dotfiles` owner: Hyprland, nvim, wezterm;
- `padilha-os` owner: image/installer, once the repository exists;
- docs are currently part of `padilha-de`; if they grow, split `padilha-docs`;
- coordinator (main session): cross-repo decisions, version pins, reviews,
  merges, funding, and scheduling.

Rules for repo owners:

- work only in the assigned checkout;
- do not commit or push; the coordinator reviews and commits;
- run the repo's tests before reporting;
- report files changed, exact diff summary, tests, and any live command;
- never write secrets or touch `env.local.lua`-style local files;
- stop and report if a change needs a path outside the repository.

## Safety while developing live

- `bin/padilha-shell-watch` is running and is autostarted from `execs.lua`. It
  checks Quickshell every 10 seconds, restarts it after a crash with a bounded
  backoff, and logs to `~/.local/state/padilha/shell-watch.log`. A
  `padilha-reload` marker keeps it from racing a deliberate reload.
- The idle lock is disabled: `hypridle` now only powers the panel down after
  five minutes. The shell lock screen crashed Quickshell on 2026-11-04 (PAM
  subprocess exited and the shell process disappeared), so do not restore
  `qs ... lock` to hypridle until that path is fixed. Manual `Super+Escape` still
  requests the shell lock; the watchdog will recover the shell if it crashes.
- Before changing a live QML/config file: commit it, keep a backup, and prefer
  editing the repository through the symlink. If the UI disappears, run
  `bin/padilha-session` from a TTY or ask Hyprland to execute it; the watchdog
  should already be doing this.
- Keep a known-good tag in both repositories before risky changes:
  `git tag known-good-<date>` (the current one is `known-good-2026-11-04`).
- Agents work in worktrees/branches only; the promo scheduler is not enabled
  during normal desktop work. Do not let an agent edit the live checkout.
- Suspend is still broken on this laptop (s2idle). Lid close locks; do not test
  suspend casually.

## Promo-window agent service (design)

Goal: a local scheduler that starts repo agents only during DeepSeek discount
windows, stops them before the window closes, and resumes the next window.

`dsh headless "task"` already runs one task and exits, which is the primitive
the service can drive. A prototype should not hardcode DeepSeek's schedule;
pricing and windows change.

Components:

1. **Window config** (`~/.config/padilha/agents.toml`, local, not committed):
   - timezone and discount windows (start/end);
   - stop margin (20–30 minutes);
   - repositories and their queue directories;
   - max agents, max turns/cost, model, test command.
2. **Task queue** per repository (`.agents/queue/*.md` or GitHub issues with a
   label). Each task names the repo, branch, acceptance checks, and a stop
   condition. A task is not a vague "improve things" prompt.
3. **Scheduler** (systemd user timer every 5 minutes, or a small daemon):
   - if now is inside a window minus the stop margin, ensure one `dsh headless`
     process per repo with queued work;
   - if outside, do not start new work; signal current agents to checkpoint;
   - log window, task, process, result, and token/cost usage to local state.
4. **Isolation**: one git worktree/branch per agent and task
   (`agent/<date>-<slug>`), never the main checkout. One agent per repo avoids
   two agents writing the same files.
5. **Stop and handoff**: before the window end, send `SIGTERM`, let the agent
   finish its current step, run tests, commit WIP to its branch, and push. The
   coordinator opens PRs; no agent pushes `main`.
6. **Safety**: API key in a root-readable env file or systemd credential, not
   in the repo; cap turns/cost; refuse to run when the working tree is dirty;
   require tests and a human merge.
7. **Window detection**: start from a config file. Optionally probe DeepSeek's
   pricing page/API, but only to *update the config*, not to decide spend on a
   scraped string. The service must fail closed when the schedule is unknown.

Minimum viable version: a shell/Python script plus a systemd timer, a queue of
Markdown tasks, worktrees, `timeout` around `dsh headless`, and PR creation.
Only after that should the coordinator agent auto-review/merge.

## Known issues

- s2idle suspend hangs; lid-close is `lock`. Do not suspend casually.
- GitHub Pages is not enabled, and both repos are private.
- GitHub Sponsors enrollment and non-GitHub donation links are pending.
- The MC skin's selection/error backgrounds may remain opaque by design; review
  whether "fully transparent" should override contrast for those too.
- The promo scheduler is tested but not enabled: the window schedule,
  cost cap, and timer installation are user decisions.

## Next actions

1. Review the MC and dotfiles agent results; apply the skin and any border/scheme
   fixes.
2. Commit the agents' scoped changes and run both repos' tests.
3. Enable GitHub Pages (or decide on the public docs mirror) and enroll/finish
   the funding links.
4. Enable the promo scheduler on one repository with a verified window and a
   cost cap; keep `max_rounds_per_window` bounded for the first windows.
5. Create `padilha-os` only after the desktop/dotfiles packages have tagged
   releases.
