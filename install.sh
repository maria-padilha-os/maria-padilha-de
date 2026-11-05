#!/usr/bin/env bash
# Lilith installer.
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
dotfiles_dir="${LILITH_DOTFILES:-${PADILHA_DOTFILES:-$root/../lilith-dotfiles}}"

usage() {
    cat <<'EOF'
usage: ./install.sh [--full|--rice] [--dry-run] [--no-dotfiles]

  --full         install the desktop session, shell, commands and configs
  --rice         install Hyprland + Quickshell + theme, keep the current session
  --dry-run      print what would happen, change nothing
  --no-dotfiles  do not link ~/.config/{hypr,nvim,wezterm}

LILITH_DOTFILES=DIR points at an existing dotfiles checkout
(default: ../lilith-dotfiles next to this repository). The old
PADILHA_DOTFILES name is still accepted.

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
    die "pacman not found; Lilith is packaged for Arch and Manjaro"
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
# Skip anything already present: some dependencies (libcava, quickshell) come
# from the AUR, so `pacman -S` would abort with "target not found" even though
# the package is installed and the build works.
missing_deps=()
for pkg in "${build_deps[@]}" "${runtime_deps[@]}"; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing_deps+=("$pkg")
done
if [ ${#missing_deps[@]} -gt 0 ]; then
    run_sudo pacman -S --needed "${missing_deps[@]}"
else
    log "All build and runtime dependencies are already installed"
fi

log "Building the shell"
run "$root/tools/build.sh"

log "Installing the shell and commands under /usr"
run_sudo cmake --install "$root/build" --prefix /usr
run_sudo install -d /usr/lib/lilith/bin /usr/lib/lilith/lib /usr/lib/lilith/share
run_sudo cp -R --preserve=mode,timestamps "$root/bin/." /usr/lib/lilith/bin/
run_sudo cp -R --preserve=mode,timestamps "$root/lib/." /usr/lib/lilith/lib/
run_sudo cp -R --preserve=mode,timestamps "$root/share/." /usr/lib/lilith/share/
run_sudo install -Dm644 "$root/KEYBINDS.md" /usr/lib/lilith/share/KEYBINDS.md
run_sudo chmod 755 /usr/lib/lilith/bin/*

commands=(
    lilith
    lilith-brightness
    lilith-config
    lilith-session
    lilith-shell-watch
    lilith-theme
    lilith-daylight
    lilith-reload
    lilith-shot
    lilith-record
    lilith-clipboard
    lilith-emoji
)
for cmd in "${commands[@]}"; do
    run_sudo ln -sfn "/usr/lib/lilith/bin/$cmd" "/usr/bin/$cmd"
done

if [ "$mode" = full ]; then
    log "Installing the session entry and systemd user units"
    run_sudo install -Dm644 "$root/session/lilith.desktop" \
        /usr/share/wayland-sessions/lilith.desktop
    run_sudo install -d /usr/lib/systemd/user
    run_sudo install -m644 "$root"/session/systemd/user/* /usr/lib/systemd/user/
fi

link_dotfiles() {
    (($#)) || return 0
    local config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local name dst backup file
    for name in "$@"; do
        dst="$config/$name"
        if [ "$name" = mc ]; then
            # MC shares ~/.config/mc with panels, hotlist and history. Link
            # only the static files and back each one up individually.
            run mkdir -p "$dst"
            for file in ini mc.keymap mc.ext.ini; do
                if [ -e "$dst/$file" ] && [ ! -L "$dst/$file" ]; then
                    backup="$dst/$file.pre-lilith-$(date +%Y%m%d-%H%M%S)"
                    warn "backing up $dst/$file -> $backup"
                    run mv "$dst/$file" "$backup"
                fi
            done
            continue
        fi
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            backup="$dst.pre-lilith-$(date +%Y%m%d-%H%M%S)"
            warn "backing up $dst -> $backup"
            run mv "$dst" "$backup"
        fi
    done
    run "$dotfiles_dir/bin/lilith-dots" "$@"
}

if (( with_dotfiles )); then
    if [ ! -x "$dotfiles_dir/bin/lilith-dots" ]; then
        if [ -e "$dotfiles_dir" ]; then
            die "$dotfiles_dir exists but has no bin/lilith-dots"
        fi
        log "Fetching lilith-dotfiles"
        run git clone https://github.com/Mateus-M-Reis/lilith-dotfiles.git "$dotfiles_dir"
    fi

    if [ "$mode" = full ]; then
        link_dotfiles hypr nvim wezterm mc
    else
        link_dotfiles hypr
    fi
fi

if [ "$mode" = full ]; then
    cat <<'EOF'

Installed the full desktop.
1. Reboot (or log out) and choose "Lilith" at the display manager.
2. If the greeter still lists plain Hyprland, pick Lilith from the session menu.
3. Super+Escape locks; Super+Shift+Escape explains that sleep is disabled
   (s2idle/hibernate are broken on some laptops), Super+/ opens the cheat sheet
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
2. `lilith-session` starts the shell; the Hyprland config calls it at login.
3. If you kept your own Hyprland config (--no-dotfiles), start Quickshell with
   `qs -c caelestia` after setting the QML import path from the build.

To uninstall the files installed by this script, see INSTALL.md.
EOF
fi
