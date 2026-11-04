# Dotfiles

These are the configs Padilha owns. They live in the checkout so changes are
versioned, and are linked into `~/.config`:

| checkout | link |
| --- | --- |
| `dotfiles/hypr` | `~/.config/hypr` |
| `dotfiles/nvim` | `~/.config/nvim` |
| `dotfiles/wezterm` | `~/.config/wezterm` |

`bin/padilha-dots` creates the links. It refuses to replace a real directory,
so on a fresh machine move the existing config aside once and run it.

Local-only files are ignored rather than committed:

- `dotfiles/hypr/hyprland/env.local.lua` — machine secrets (API keys);
- `*.bak` — timestamped backups from config edits;
- `dotfiles/nvim/Session.vim` and `nvim.log` — Neovim runtime artifacts.

Everything else in those three trees is the source of truth for this desktop.
