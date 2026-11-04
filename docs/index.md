---
layout: default
title: Home
---

# Padilha

A Wayland desktop built on [Hyprland](https://hyprland.org) and
[Quickshell](https://quickshell.org), with a wallpaper-driven colour system and
a small Lua configuration layer.

<p>
  <a href="{{ '/install.html' | relative_url }}"
     style="display:inline-block;padding:0.6em 1em;background:#904b3e;color:#fff;border-radius:6px;text-decoration:none;">
    Install Padilha
  </a>
  <a href="{{ '/support.html' | relative_url }}"
     style="display:inline-block;padding:0.6em 1em;border:1px solid #904b3e;color:#904b3e;border-radius:6px;text-decoration:none;">
    Support the project
  </a>
</p>

Padilha is early software (`0.1.x`). There are two ways in:

- **[The desktop]({{ '/install.html' | relative_url }})** — shell, session,
  theme engine, installer, and the full set of configs.
- **[The rice]({{ '/dotfiles.html' | relative_url }})** — keep your existing
  Hyprland session and take only the shell, theme, and Hyprland config.

The projects live in separate repositories: `padilha-de` for the desktop,
`padilha-dotfiles` for the rice, and a future `padilha-os` for the image. This
site is the shared documentation for all of them.

## What it looks like

- A bar, launcher, notifications, OSD, dashboard, and lock screen.
- One wallpaper palette applied to Hyprland, GTK, Qt/Kvantum, terminals, btop,
  cava, fuzzel, Neovim, Discord, and Midnight Commander.
- A light wallpaper by day and a dark one at night, with the palette reapplied
  when the period changes.
- Vim-style navigation: `Super + h/j/k/l` for focus, `Super + Alt + h/l` for
  workspaces, `Super + Alt + j/k` for monitors.

See the [desktop page]({{ '/desktop.html' | relative_url }}) for the tour.
