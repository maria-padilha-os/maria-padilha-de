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

## Current state

- Shell, session, installer, theme engine, and package build and tests pass.
- Vim-style keymap and `KEYBINDS.md` are in place.
- Brightness follows a day/night curve with a four-hour manual hold; zram is
  active; `hypridle` locks after five minutes and toggles DPMS.
- Neovim has an opt-in `caelestia` colorscheme (ayu-like light/dark, tinted by
  the wallpaper). The base46 ayu themes remain intact.
- WezTerm opacity is `0.85`; Hyprland has a WezTerm-specific `0.85 override`
  rule so the global `0.95` rule does not flatten it.
- Hyprland focus border was made 2px and opaque `scheme.primary`; the area
  picker overlay now uses `m3primary` instead of the pale secondary container.
- Suspend is **broken** on this AMD Mendocino laptop: s2idle hangs, so lid
  close is configured to lock, not suspend. Do not test suspend without warning.
- Docs/funding scaffold committed as `a627fff`: `docs/`, `SUPPORT.md`,
  `FUNDING.yml`, and README links.
- Dotfiles split committed as `5fc741b`; the dotfiles repository is pushed.
- MC skin surfaces now emit MC's `default` background, so the live skin was
  regenerated from the current scheme without recomputing the palette. Semantic
  blocks (selection, error, diff, focus accents) stay opaque for contrast.
  Restart MC to load it.

## Open work

1. **WezTerm/terminal audit.** Agent `2aec77cd…` is checking the opacity pair,
   the focus border contrast, and the stale `hypr/scheme/current.conf` (it still
   looks like a dark/teal palette while `current.lua` is light/red).
2. **GitHub Pages activation.** `docs/README.md` documents Settings → Pages →
   main `/docs`. Private repositories may need a paid plan or a public docs
   mirror. The site is one site, not per project.
3. **Funding links.** GitHub Sponsors handle is wired; enrollment is a user
   action. Add Ko-fi/Liberapay/Pix to `.github/FUNDING.yml` when chosen.
4. **`padilha-os`.** Not started; it should be an archiso/Calamares repository
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
- `hypr/scheme/current.conf` appears stale (dark/teal) relative to
  `current.lua` (light/red); audit pending.
- GitHub Pages is not enabled, and both repos are private.
- GitHub Sponsors enrollment and non-GitHub donation links are pending.
- The MC skin's selection/error backgrounds may remain opaque by design; review
  whether "fully transparent" should override contrast for those too.
- The promo service is only a design; no scheduler/timer exists yet.

## Next actions

1. Review the MC and dotfiles agent results; apply the skin and any border/scheme
   fixes.
2. Commit the agents' scoped changes and run both repos' tests.
3. Enable GitHub Pages (or decide on the public docs mirror) and enroll/finish
   the funding links.
4. Build the promo-window scheduler as a separate, tested tool; start with one
   repo and a dry-run mode before enabling more.
5. Create `padilha-os` only after the desktop/dotfiles packages have tagged
   releases.
