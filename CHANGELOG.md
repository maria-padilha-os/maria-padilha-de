# Changelog

## Unreleased

- The generated GTK 3/4 and Qt themes now share the same selection, disabled,
  menu, tooltip, focus and border roles. GTK gained the standard and libadwaita
  names it was missing, the Qt light/dark schemes stopped blending disabled
  text below contrast, and the KDE titlebar blend fields are generated instead
  of frozen RGB values. `tests/theme/check-gtk-qt-contrast.py` exercises the
  contrast fixture for both modes, and `docs/gtk-qt-visual-checklist.md` records
  the manual pass and the Flatpak/portal caveats.
- The shell now handles multiple monitors and hotplug through a stable screen
  model instead of array indices or `ShellScreen` object identity. Adding,
  removing, rotating or scaling an output rebuilds only that output's bar,
  launcher, dashboard, notifications and wallpaper; duplicate connector entries
  are collapsed and the last output removal falls back to a detached state
  rather than crashing. Popup notifications are routed to one output and move
  to the new primary if theirs disappears. Per-output panel anchors are kept in
  `~/.local/state/padilha/panel-layout.json`; the file contains geometry and
  panel metadata only, never screenshots or other screen contents. See
  `docs/multi-monitor.md` for the nested Hyprland/headless test matrix and
  `tests/screens/` for the model, removal and privacy contracts.
- The shell now has a recorded performance budget. Media position updates use
  one timer in the `Players` service instead of one per surface, night light
  schedules the next hour instead of polling every minute, weather/uptime,
  clipboard-watch and notification-age timers are slower, and looping
  animations stop under `PADILHA_REDUCED_MOTION=1`. `tests/performance/run.sh`
  measures offscreen startup, idle CPU, RSS and QML warning classes against
  `tests/performance/baseline.json` and is part of `tests/all.sh`; the method
  and reference numbers are in `docs/performance.md`.
- The Updates page is now an explicit, safe package manager instead of a
  read-only version list. It shows each pending pacman upgrade with both
  versions and its download and installed size, requires a separate
  confirmation before applying anything, and never updates or reboots on its
  own. Failures stay on screen with the log tail and a copyable path under
  `~/.local/state/padilha/updates`; low battery and large updates while on
  battery get a warning. `padilha update check|apply|log` and
  `padilha-update` expose the same flow from a terminal. pacman remains the
  package manager and the existing policy agent (pkexec) performs the single
  privileged step, so there is no second privileged helper.
- New screenshots and recording panel in the utilities drawer. It captures the
  focused monitor, focused window or a slurp region with `grim`, records with
  `wf-recorder`, has explicit Start/Stop, a configurable countdown, an in-panel
  REC badge and a pulsing bar indicator. Files are saved locally with
  timestamps under configurable folders, screenshots are copied only on
  request, and nothing is uploaded or recorded by opening the panel. It warns
  when Hyprland's active workspace is not the dedicated capture workspace.
  `padilha-record` now uses `wf-recorder` (the `gpu-screen-recorder` dependency
  is gone), and `padilha-capture` is the shared command behind both wrappers.
- Weather now uses an explicit saved location instead of an IP lookup. The
  settings page has a user-triggered city/place search, the weather panel shows
  the last update time, responses are cached with a bounded TTL and stale data
  is labelled rather than silently replaced. Provider URL/key, geocoding URL,
  language, units and refresh interval are configurable; the private key lives
  in `~/.config/padilha/weather.conf` and is never committed or cached.
- The extension manager now shows each extension as a card with its
  description, version, permissions, enabled state, tab/shortcut behaviour and
  dependency state. It has search and All/Enabled/Disabled/Needs attention
  filters, an explanatory empty state, and no install or network-fetch path.
  Invalid manifests, missing tab files, duplicate ids and duplicate shortcuts
  stay visible with actionable messages; broken manifests can no longer
  disappear silently. Toggling still updates `dashboard.extensionTabs`
  immediately and survives reloads. Manifest validation and duplicate rules
  are covered by `tests/extensions/manifest.test.js`; the real config
  save/reload path is covered by `tests/extensions/persistence.qml`.
- New opt-in clipboard history palette, disabled by default. It keeps a
  bounded store under `~/.local/state/padilha/clipboard`, supports search,
  keyboard selection and copy-back, pause and clear-all, and gives
  password-manager classes, password-like titles, private-window cooldowns and
  password-manager MIME hints a hard no. A bar dot shows when recording, and
  `padilha-clipboard` still keeps the original fuzzel/cliphist picker.
- The Maps tab now follows the wallpaper palette with CARTO's light/dark raster
  styles, keeps OpenStreetMap as a clearly labelled offline/keyless fallback,
  and shows loading, failure and retry states. A CARTO key is read at runtime
  from `PADILHA_MAPS_CARTO_KEY` or `~/.config/padilha/maps.conf` and is never
  committed; cache keys include the style and omit the key.
- Thunderbird is now a first-class optional app instead of a base dependency.
  It is in the package's `optdepends`, the installer's Office/Mail group
  (`--with-office-mail`), and `packaging/apps.list`. A new `padilha-mail`
  command and `padilha-mail.desktop` entry provide the `Mail` launcher and
  `mailto:` handler, with a clean notice when Thunderbird is absent. Account
  credentials stay in Thunderbird's profile; the handler never reads or logs
  them.
- New permissioned home-folder broker `padilha-ai` (ADR 0001). It exposes only
  explicitly approved roots, reads UTF-8 text by default, refuses the built-in
  credential/browser/agent deny list and symlink escapes, redacts secrets before
  content leaves the process, and writes metadata-only audit records. Writes
  need a separate one-use confirmation; commands are never executed. Grants and
  revocations are managed with `padilha-ai roots`.
- New dashboard extensions: **Notes** (plain-text files under
  `~/.local/share/padilha/notes`), **Calendar** (local month view and
  `events.json` under `~/.local/share/padilha/calendar`), and **Unit converter**
  (offline length, mass, temperature, data and time). They are in
  `share/extensions/`, use `Super + Alt + N` / `A` / `U`, and have no network
  access.

- New dashboard extensions: **System monitor** (CPU and memory from the shell
  services, load average from `/proc/loadavg`), **Pomodoro** (configurable
  focus/break timer with desktop notifications) and **Disk usage** (read-only
  mounted filesystem usage from the `Storage` service). They use the existing
  extension contract and the `Super + Alt + I` / `B` / `Shift + U` shortcuts.
- `padilha-brightness` reads the backlight through sysfs and only calls
  `brightnessctl` when it needs to change the value, instead of spawning two
  helpers every two seconds.

## 0.2.0 — Maria Padilha (2026-11-06)

- Rebranded the product from Lilith back to **Maria Padilha**. Commands are
  `padilha-*` (plain `padilha`; `lilith-*` remains as a compatibility alias),
  the package is `maria-padilha`, the install tree is `/usr/lib/maria-padilha`,
  the session entry is **Maria Padilha**, and user config/state live in
  `~/.config/padilha` and `~/.local/state/padilha`. `PADILHA_CONFIG` is the
  primary environment variable; `LILITH_CONFIG` remains the fallback.
- Repositories are now `maria-padilha-os/maria-padilha-de` and
  `maria-padilha-os/maria-padilha-dotfiles`; the docs site uses
  `baseurl: /maria-padilha-de`. The Quickshell id and
  `~/.local/state/caelestia` are unchanged.
- Screen locking moved out of Quickshell to `padilha-lock` + `hyprlock`, so a
  locker or PAM failure cannot take the shell and session down. The in-shell
  lock remains opt-in with `PADILHA_ALLOW_SHELL_LOCK=1`; `hyprlock.conf` is
  generated from the wallpaper palette.
- Fixed the direct installer: it built the shell with a relative
  `INSTALL_QSCONFDIR`, so `cmake --install --prefix /usr` wrote
  `/usr/etc/xdg/quickshell/caelestia` instead of
  `/etc/xdg/quickshell/caelestia`. The build now receives the absolute path,
  and `tests/cli/installer.sh` checks the plan.
- Theme settings in `~/.config/padilha/theme.lua` are now read by every apply
  (daylight and wallpaper changes included); `padilha-theme` validates `--mode`,
  `--variant` and `--seed` instead of raising a Lua traceback, and a matching
  `daylight.period` no longer hides a missing `scheme.json` at login.
- A fresh `--full` install now pulls the session daemons that `execs.lua`
  starts: `hypridle`, `hyprsunset`, `trash-cli`, `gnome-keyring`,
  `polkit-gnome`, `bluez-utils`, `wl-clipboard`, `cliphist`, and `fuzzel`.
  The PKGBUILD also declares `cmake`/`ninja` as makedepends and `hyprlock` as
  a recommended optdepend.
- `padilha-record` and `padilha-shot` now find the focused monitor correctly;
  `jq` is a declared dependency.
- The CI workflow runs the lint suite in addition to the contract tests.

## 0.1.1 — historical snapshot; that release used the Lilith name

This is the preparation state described in `DEPLOY.md`. No package, Pages site,
or promo timer has been published. The naming in this section is historical:
the 0.2.0 section above reverses it.

### Added

- Two install profiles: `--full` for the desktop session and `--rice` for an
  existing Hyprland session.
- The dotfiles split: `padilha-de` fetches or links `padilha-dotfiles` instead
  of carrying the configs. The static Midnight Commander files
  (`ini`, `mc.keymap`, `mc.ext.ini`) now live in the dotfiles repo; the
  caelestia MC skin remains generated by the theme engine.
- Vim-style focus, movement, resize, workspace, and monitor keys.
- The day/night brightness daemon with a four-hour manual hold.
- The shell watchdog (`lilith-shell-watch`) and its restart log.
- Terminal-transparent Midnight Commander skin surfaces.
- The promo-window agent scheduler prototype, including maintenance rounds,
  dry-run, status, stop, worktrees, and tests. It runs one repository at a time
  in round-robin order instead of launching every repository at once.
- A single GitHub Pages source under `docs/`, with the support page.
- GitHub Sponsor metadata in both repositories.

### Changed

- Renamed the product from Padilha to Lilith (reversed in 0.2.0). Commands
  were `lilith-*` (plain `lilith`; the old `padilha-*` names remained as
  temporary compatibility aliases), the package was `lilith`, the install tree
  was `/usr/lib/lilith`, the session entry was **Lilith**, and user
  config/state lived in `~/.config/lilith` and `~/.local/state/lilith`.
  `LILITH_DOTFILES` replaced `PADILHA_DOTFILES`, which was still accepted
  during the transition.
- The workspace checkouts are now `~/Códigos/lilith/lilith-de` and
  `.../lilith-dotfiles`, and the installer expects the dotfiles checkout as
  `../lilith-dotfiles`. The GitHub repositories and the Quickshell id
  (`caelestia`) keep their names.

### Fixed

- WezTerm now owns its `0.85` opacity; the Hyprland class rule no longer
  multiplies it down to roughly `0.72`.
- The Hyprland focus border is 2px opaque `primary` (6.13:1 on the light
  surface), and the area picker uses the wallpaper accent.
- NvimTree follows the light `Normal` surface instead of staying on base46's
  dark group.
- The wallpaper state path uses the `lilith-de` checkout again after the
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
