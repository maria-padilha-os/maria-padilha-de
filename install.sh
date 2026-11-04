#!/usr/bin/env bash
# Padilha installer.
#
#   ./install.sh --full        the full desktop session (default)
#   ./install.sh --rice        Hyprland + Quickshell, keeping the current session
#   ./install.sh --dry-run     print every action, change nothing
#   ./install.sh --no-dotfiles do not link the configs into ~/.config
#
# Arch Linux and Arch-based distributions (Manjaro) only. The script installs
# packages with pacman, builds shell/, installs the shell and commands under
# /usr, and (for --full) drops the session entry and systemd user units.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=full
dry_run=0
with_dotfiles=1
dotfiles_dir="${PADILHA_DOTFILES:-$root/../padilha-dotfiles}"

usage() {
    cat <<'EOF'
usage: ./install.sh [--full|--rice] [--dry-run] [--no-dotfiles]

  --full         install the desktop session, shell, commands and configs
  --rice         install Hyprland + Quickshell + theme, keep the current session
  --dry-run      print what would happen, change nothing
  --no-dotfiles  do not link ~/.config/{hypr,nvim,wezterm}

PADILHA_DOTFILES=DIR points at an existing padilha-dotfiles checkout
(default: ../padilha-dotfiles next to this repository).

The rice profile still needs root for the shell and commands under /usr. It
does not install a session entry or systemd user units.
EOF
}

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }

run() {
    if (( dry_run )); then
        printf '+ '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

run_sudo() {
    if (( EUID == 0 )); then
        run "$@"
    else
        run sudo "$@"
    fi
}

while (( $# )); do
    case "$1" in
    --full)
        mode=full
        ;;
    --rice)
        mode=rice
        ;;
    --dry-run)
        dry_run=1
        ;;
    --no-dotfiles)
        with_dotfiles=0
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
    esac
    shift
done

if ! command -v pacman >/dev/null 2>&1; then
    die "pacman not found; Padilha is packaged for Arch and Manjaro"
fi

if (( dry_run == 0 )); then
    if [ ! -f /etc/arch-release ] &&
        ! grep -qiE '^(ID|ID_LIKE)=.*(arch|manjaro)' /etc/os-release 2>/dev/null; then
        die "unsupported distribution; expected Arch Linux or Manjaro"
    fi
    command -v sudo >/dev/null 2>&1 || die "sudo is required"
fi

build_deps=(
    base-devel
    cmake
    ninja
    git
    python
)

runtime_deps=(
    hyprland
    quickshell
    qt6-base
    qt6-declarative
    libpipewire
    aubio
    libcava
    libqalculate
    lm_sensors
    brightnessctl
    python
    lua
    imagemagick
)

log "Installing build and runtime dependencies"
run_sudo pacman -S --needed "${build_deps[@]}" "${runtime_deps[@]}"

log "Building the shell"
run "$root/tools/build.sh"

log "Installing the shell and commands under /usr"
run_sudo cmake --install "$root/build" --prefix /usr
run_sudo install -d /usr/lib/padilha/bin /usr/lib/padilha/lib /usr/lib/padilha/share
run_sudo cp -R --preserve=mode,timestamps "$root/bin/." /usr/lib/padilha/bin/
run_sudo cp -R --preserve=mode,timestamps "$root/lib/." /usr/lib/padilha/lib/
run_sudo cp -R --preserve=mode,timestamps "$root/share/." /usr/lib/padilha/share/
run_sudo chmod 755 /usr/lib/padilha/bin/*

commands=(
    padilha
    padilha-brightness
    padilha-config
    padilha-session
    padilha-shell-watch
    padilha-theme
    padilha-daylight
    padilha-reload
    padilha-shot
    padilha-record
    padilha-clipboard
    padilha-emoji
)
for cmd in "${commands[@]}"; do
    run_sudo ln -sfn "/usr/lib/padilha/bin/$cmd" "/usr/bin/$cmd"
done

if [ "$mode" = full ]; then
    log "Installing the session entry and systemd user units"
    run_sudo install -Dm644 "$root/session/padilha.desktop" \
        /usr/share/wayland-sessions/padilha.desktop
    run_sudo install -d /usr/lib/systemd/user
    run_sudo install -m644 "$root"/session/systemd/user/* /usr/lib/systemd/user/
fi

link_dotfiles() {
    (($#)) || return 0
    local config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local name dst backup
    for name in "$@"; do
        dst="$config/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            backup="$dst.pre-padilha-$(date +%Y%m%d-%H%M%S)"
            warn "backing up $dst -> $backup"
            run mv "$dst" "$backup"
        fi
    done
    run "$dotfiles_dir/bin/padilha-dots" "$@"
}

if (( with_dotfiles )); then
    if [ ! -x "$dotfiles_dir/bin/padilha-dots" ]; then
        if [ -e "$dotfiles_dir" ]; then
            die "$dotfiles_dir exists but has no bin/padilha-dots"
        fi
        log "Fetching padilha-dotfiles"
        run git clone https://github.com/Mateus-M-Reis/padilha-dotfiles.git "$dotfiles_dir"
    fi

    if [ "$mode" = full ]; then
        link_dotfiles hypr nvim wezterm
    else
        link_dotfiles hypr
    fi
fi

if [ "$mode" = full ]; then
    cat <<'EOF'

Installed the full desktop.
1. Reboot (or log out) and choose "Padilha" at the display manager.
2. If the greeter still lists plain Hyprland, pick Padilha from the session menu.
3. Super+Escape locks; Super+Shift+Escape sleeps; Super+/ opens the cheat sheet
   if your build has it.

If the session does not start, check `hyprctl configerrors` from a TTY and the
Quickshell log under ~/.local/state or /run/user/$UID/quickshell.
EOF
else
    cat <<'EOF'

Installed the rice profile: shell, commands and Hyprland config.
The current display manager and session entry are untouched.

1. Log out and back into your existing Hyprland session, or run `hyprctl reload`
   for the config changes.
2. `padilha-session` starts the shell; the Hyprland config calls it at login.
3. If you kept your own Hyprland config (--no-dotfiles), start Quickshell with
   `qs -c caelestia` after setting the QML import path from the build.

To uninstall the files installed by this script, see INSTALL.md.
EOF
fi
