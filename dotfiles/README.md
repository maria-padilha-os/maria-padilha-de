# Padilha dotfiles

These are the configs Padilha owns, in their own repository. They are linked
into `~/.config`:

| checkout | link |
| --- | --- |
| `hypr` | `~/.config/hypr` |
| `nvim` | `~/.config/nvim` |
| `wezterm` | `~/.config/wezterm` |

`bin/padilha-dots` creates the links. It refuses to replace a real directory,
so on a fresh machine move the existing config aside once and run it.

Local-only files are ignored rather than committed:

- `hypr/hyprland/env.local.lua` — machine secrets (API keys);
- `*.bak` — timestamped backups from config edits;
- `nvim/Session.vim` and `nvim/nvim.log` — Neovim runtime artifacts.

The Hyprland config calls `padilha-session` from the separate `padilha-de`
checkout (installed in `/usr/bin`, or a sibling `../padilha-de/bin`).

