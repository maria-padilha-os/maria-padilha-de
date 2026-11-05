---
layout: default
title: Dotfiles
---

# The rice

`lilith-dotfiles` is the standalone rice: the Hyprland, Neovim, and WezTerm
configs, linked into `~/.config` by `bin/lilith-dots`.

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
./bin/lilith-dots             # hypr, nvim, wezterm
./bin/lilith-dots hypr        # only Hyprland
```

`lilith-dots` refuses to replace a real directory. Move an existing config
aside once, then rerun it.

## What is in the rice

- Hyprland: keybinds, rules, animations, workspace and special-workspace setup.
- Neovim: NvChad base, a separate `caelestia` colorscheme that follows the
  wallpaper, and the ayu themes left intact.
- WezTerm: the terminal palette, 0.85 background opacity, and no close prompt
  when the compositor closes the window.

Local-only files (`env.local.lua`, `*.bak`, `Session.vim`, `nvim.log`) are
ignored by git; `env.local.lua` is where machine secrets belong.
