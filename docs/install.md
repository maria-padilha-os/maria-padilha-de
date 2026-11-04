---
layout: default
title: Install
---

# Install Padilha

Padilha is packaged for Arch Linux and Arch-based distributions (Manjaro is the
tested one). It must run on a machine where Hyprland already works.

## Full desktop

```sh
mkdir -p ~/Códigos/lilith
git clone https://github.com/Mateus-M-Reis/padilha.git \
    ~/Códigos/lilith/lilith-de
cd ~/Códigos/lilith/lilith-de

./install.sh --dry-run --full
./install.sh --full
```

Then reboot or log out and choose **Padilha** in the display manager's session
menu.

## Rice only

Same clone, then:

```sh
./install.sh --rice
```

This installs the shell, commands, and Hyprland config, but not the session
entry or systemd units. Log back into your existing Hyprland session.

## What the installer changes

- Installs the Arch packages listed in the PKGBUILD with `pacman -S --needed`.
- Builds the shell with CMake and Ninja.
- Installs the shell and commands under `/usr`, and (for `--full`) the session
  entry under `/usr/share/wayland-sessions`.
- Fetches the dotfiles repository as `lilith-dotfiles` next to the desktop
  checkout if needed, then links
  `~/.config/hypr` (both profiles) and `~/.config/nvim`, `~/.config/wezterm`
  (full). Existing real directories are backed up as
  `~/.config/<name>.pre-padilha-<timestamp>`.

Use `--no-dotfiles` to leave `~/.config` alone, or `--dry-run` to see every
command first.

The complete guide, including uninstall and troubleshooting, is
[INSTALL.md](https://github.com/Mateus-M-Reis/padilha/blob/main/INSTALL.md).
