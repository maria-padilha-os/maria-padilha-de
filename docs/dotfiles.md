---
layout: default
title: Dotfiles
---

# The rice

`maria-padilha-dotfiles` is the standalone rice: the Hyprland, Neovim, and WezTerm
configs plus the static Midnight Commander files, linked into `~/.config` by
`bin/padilha-dots`. The same repository carries the tracked Firefox
configuration, which is installed into Firefox's profile instead of
`~/.config`.

```sh
git clone https://github.com/maria-padilha-os/maria-padilha-dotfiles.git \
    ~/Códigos/maria-padilha-dotfiles
```

The Hyprland config starts the shell through `padilha-session`, which comes
from the desktop package. Install that first with `./install.sh --rice`, or put
the desktop's `bin/` on `PATH` for a checkout.

## Link the configs

```sh
cd ~/Códigos/maria-padilha-dotfiles
./bin/padilha-dots             # hypr, nvim, wezterm, mc, firefox
./bin/padilha-dots hypr        # only Hyprland
```

`padilha-dots` refuses to replace a real directory. Move an existing config
aside once, then rerun it.

Firefox has no profile until it has been launched once. On a fresh machine,
launch it once and quit it, then run `./bin/padilha-dots firefox`. See
`firefox/README.md` in the dotfiles repository for the full sequence and for
the palette step (`padilha-theme` writes the generated CSS under `chrome/`).

## What is in the rice

- Hyprland: keybinds, rules, animations, workspace and special-workspace setup.
- Neovim: NvChad base, a separate `caelestia` colorscheme that follows the
  wallpaper, and the ayu themes left intact.
- WezTerm: the terminal palette, 0.85 background opacity, and no close prompt
  when the compositor closes the window.
- Firefox: `firefox/user.js` plus `userChrome.css` and `userContent.css`, which
  consume the palette written to the profile's `chrome/` directory.

Local-only files (`env.local.lua`, `*.bak`, `Session.vim`, `nvim.log`) are
ignored by git; `env.local.lua` is where machine secrets belong.
