# Security policy

## Supported versions

The public `0.2.x` release line is supported. Older snapshots and compatibility
aliases (`lilith-*`) are provided as-is for migration only.

## Reporting a vulnerability

Please report security issues privately through this repository's
**Security → Report a vulnerability** page (GitHub private vulnerability
reporting). Do not open a public issue for an exploitable flaw.

Include:

- the affected version (package version or commit);
- the distribution and Hyprland/Quickshell versions;
- a minimal reproduction and the relevant log excerpt;
- whether the issue affects the shell, a command, the installer, or the
  package.

Redact passwords, API keys, clipboard contents, and window titles from logs and
screenshots.

## Scope

In scope:

- the Quickshell shell and its C++ plugin under `shell/`;
- `bin/` commands, the Lua theme/config engine, and templates;
- `install.sh`, `session/`, and `packaging/`;
- authentication, locking, privilege boundaries, and file handling in those
  components.

Out of scope or handled upstream:

- Hyprland, Quickshell, Qt, PAM modules, and other distribution packages —
  report those to their maintainers;
- the private `maria-padilha-agents` repository;
- Thunderbird account storage and credentials. `padilha-mail` only forwards the
  `mailto:` URI and never reads the profile, so account issues go to the
  Thunderbird maintainers;
- cosmetic theme or wallpaper preferences;
- known hardware issues such as the s2idle suspend hang documented in the
  README.

## Handling

Reports are acknowledged as soon as possible. A fix is prepared on a branch,
tested with `bash tests/all.sh` plus the relevant integration check, and
released with credit unless you ask to remain anonymous. There is no bug bounty.
