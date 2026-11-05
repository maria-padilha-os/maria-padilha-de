---
layout: default
title: Dotfiles
---

# The rice

`lilith-dotfiles` is the standalone rice: the Hyprland, Neovim, and WezTerm
configs plus the static Midnight Commander files, linked into `~/.config` by
`bin/lilith-dots`. The same repository carries the tracked Firefox
configuration, which is installed into Firefox's profile instead of
`~/.config`.

```sh
git clone https://github.com/Mateus-M-Reis/lilith-dotfiles.git \
    ~/Códigos/lilith/lilith-dotfiles
```

The Hyprland config starts the shell through `lilith-session`, which comes
from the desktop package. Install that first with `./install.sh --rice`, or put
the desktop's `bin/` on `PATH` for a checkout.

## Link the configs

```sh
cd ~/Códigos/lilith/lilith-dotfiles
./bin/lilith-dots             # hypr, nvim, wezterm, mc, firefox
./bin/lilith-dots hypr        # only Hyprland
```

`lilith-dots` refuses to replace a real directory. Move an existing config
aside once, then rerun it.

Firefox has no profile until it has been launched once. On a fresh machine,
launch it once and quit it, then run `./bin/lilith-dots firefox`. See
`firefox/README.md` in the dotfiles repository for the full sequence and for
the palette step (`lilith-theme` writes `chrome/lilith.css`).

## What is in the rice

- Hyprland: keybinds, rules, animations, workspace and special-workspace setup.
- Neovim: NvChad base, a separate `caelestia` colorscheme that follows the
  wallpaper, and the ayu themes left intact.
- WezTerm: the terminal palette, 0.85 background opacity, and no close prompt
  when the compositor closes the window.
- Firefox: `firefox/user.js` plus `userChrome.css` and `userContent.css`, which
  consume the palette written to the profile's `chrome/lilith.css`.

Local-only files (`env.local.lua`, `*.bak`, `Session.vim`, `nvim.log`) are
ignored by git; `env.local.lua` is where machine secrets belong.
