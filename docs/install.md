---
layout: default
title: Install
---

# Install Maria Padilha

Maria Padilha is packaged for Arch Linux and Arch-based distributions (Manjaro is the
tested one). It must run on a machine where Hyprland already works.

## Full desktop

```sh
mkdir -p ~/Códigos
git clone https://github.com/maria-padilha-os/maria-padilha-de.git \
    ~/Códigos/maria-padilha-de
cd ~/Códigos/maria-padilha-de

./install.sh --dry-run --full
./install.sh --full
```

Then reboot or log out and choose **Maria Padilha** in the display manager's session
menu.

## Rice only

Same clone, then:

```sh
./install.sh --rice
```

This installs the shell, commands, and Hyprland config, but not the session
entry or systemd units. Log back into your existing Hyprland session.

## What the installer changes

- Installs its runtime dependency list with `pacman -S --needed` (kept in
  sync with `packaging/PKGBUILD`).
- Builds the shell with CMake and Ninja.
- Installs the shell and commands under `/usr`, and (for `--full`) the session
  entry under `/usr/share/wayland-sessions`.
- Fetches the dotfiles repository as `maria-padilha-dotfiles` next to the desktop
  checkout if needed, then links
  `~/.config/hypr` (both profiles) and `~/.config/nvim`, `~/.config/wezterm`
  (full). Existing real directories are backed up as
  `~/.config/<name>.pre-padilha-<timestamp>`.

Use `--no-dotfiles` to leave `~/.config` alone, or `--dry-run` to see every
command first.

## Email (optional)

Thunderbird is not in the base package. Install it separately, or make the
installer add its Office/Mail group:

```sh
sudo pacman -S --needed thunderbird
./install.sh --full --with-office-mail
```

The `Mail` launcher (`padilha-mail`) and the `mailto:` handler are installed
either way. They exit cleanly with a short notice if Thunderbird is absent.
Account credentials stay in Thunderbird's own profile; `padilha-mail` only
forwards the URI and never reads or logs account data. See
[INSTALL.md](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/INSTALL.md#email-optional)
for removal and the handler details.

The complete guide, including uninstall and troubleshooting, is
[INSTALL.md](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/INSTALL.md).
