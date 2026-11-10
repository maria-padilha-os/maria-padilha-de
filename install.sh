#!/usr/bin/env bash
# Maria Padilha installer.
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
editor=micro
dry_run=0
with_dotfiles=1
with_office_mail=0
dotfiles_dir="${PADILHA_DOTFILES:-${LILITH_DOTFILES:-}}"
if [ -z "$dotfiles_dir" ]; then
    dotfiles_dir=$root/../maria-padilha-dotfiles
    if [ ! -d "$dotfiles_dir" ] && [ -d "$root/../lilith-dotfiles" ]; then
        dotfiles_dir=$root/../lilith-dotfiles
    fi
fi

usage() {
    cat <<'EOF'
usage: ./install.sh [--full|--rice] [--dry-run] [--no-dotfiles] [--editor micro|nvim]
                    [--with-office-mail]

  --full         install the desktop session, shell, commands and configs
  --rice         install Hyprland + Quickshell + theme, keep the current session
  --dry-run      print what would happen, change nothing
  --no-dotfiles  do not link ~/.config/{hypr,nvim,wezterm,mc,firefox,micro}
  --editor EDITOR  default text editor: micro (default) or nvim
  --with-office-mail
                 also install the optional Office/Mail group (Thunderbird).
                 The base desktop does not install or depend on it.

PADILHA_DOTFILES=DIR points at an existing dotfiles checkout
(default: ../maria-padilha-dotfiles next to this repository, or the old
../lilith-dotfiles while that is the one that exists). The old
LILITH_DOTFILES name is still accepted.

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
    --with-office-mail | --office-mail)
        with_office_mail=1
        ;;
    --editor)
        (( $# >= 2 )) || die "--editor needs micro or nvim"
        editor=$2
        case "$editor" in
        micro) ;;
        nvim | neovim) editor=nvim ;;
        *) die "--editor must be micro or nvim" ;;
        esac
        shift
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
    die "pacman not found; Maria Padilha is packaged for Arch and Manjaro"
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

# Optional application groups. The base profiles never install these; the
# Office/Mail group is selected with --with-office-mail. Keep it in sync with
# packaging/apps.list and the package's optdepends.
office_mail_pkgs=(thunderbird)
optional_pkgs=()
if (( with_office_mail )); then
    optional_pkgs+=("${office_mail_pkgs[@]}")
fi

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
    micro
    xdg-utils
    jq
    hypridle
    hyprsunset
    trash-cli
    gnome-keyring
    polkit-gnome
    bluez-utils
    wl-clipboard
    cliphist
    fuzzel
    hyprlock
)

if [ "$editor" = nvim ]; then
    runtime_deps+=(neovim)
fi
if [ ${#optional_pkgs[@]} -gt 0 ]; then
    runtime_deps+=("${optional_pkgs[@]}")
fi

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
# Absolute destination: with --prefix /usr, CMake's relative default would
# install the shell tree under /usr/etc instead of /etc/xdg.
run env PADILHA_QSCONFDIR=/etc/xdg/quickshell/caelestia "$root/tools/build.sh"

log "Installing the shell and commands under /usr"
run_sudo cmake --install "$root/build" --prefix /usr
run_sudo install -d /usr/lib/maria-padilha/bin /usr/lib/maria-padilha/lib /usr/lib/maria-padilha/share
run_sudo cp -R --preserve=mode,timestamps "$root/bin/." /usr/lib/maria-padilha/bin/
run_sudo cp -R --preserve=mode,timestamps "$root/lib/." /usr/lib/maria-padilha/lib/
run_sudo cp -R --preserve=mode,timestamps "$root/share/." /usr/lib/maria-padilha/share/
run_sudo install -Dm644 "$root/KEYBINDS.md" /usr/lib/maria-padilha/share/KEYBINDS.md
run_sudo install -Dm644 "$root/upstream.json" /usr/lib/maria-padilha/upstream.json
if [ -d "$root/extensions" ]; then
    run_sudo install -d /usr/lib/maria-padilha/share/extensions
    run_sudo cp -R --preserve=mode,timestamps "$root/extensions/." /usr/lib/maria-padilha/share/extensions/
fi
run_sudo chmod 755 /usr/lib/maria-padilha/bin/*

commands=(
    padilha
    padilha-brightness
    padilha-config
    padilha-session
    padilha-lock
    padilha-shell-watch
    padilha-theme
    padilha-mc-theme
    padilha-daylight
    padilha-reload
    padilha-shot
    padilha-record
    padilha-clipboard
    padilha-emoji
    padilha-ai
    padilha-mail
)
for cmd in "${commands[@]}"; do
    run_sudo ln -sfn "/usr/lib/maria-padilha/bin/$cmd" "/usr/bin/$cmd"
    # Compatibility: the old command names point at the same files.
    run_sudo ln -sfn "/usr/lib/maria-padilha/bin/$cmd" "/usr/bin/lilith${cmd#padilha}"
done

# The launcher entry is also the mailto: handler. It is installed for both
# profiles and stays useful if Thunderbird is removed later: padilha-mail
# reports the missing optional app instead of failing.
run_sudo install -Dm644 "$root/share/applications/padilha-mail.desktop" \
    /usr/share/applications/padilha-mail.desktop

if [ "$mode" = full ]; then
    log "Installing the session entry and systemd user units"
    run_sudo install -Dm644 "$root/session/maria-padilha.desktop" \
        /usr/share/wayland-sessions/maria-padilha.desktop
    run_sudo install -d /usr/lib/systemd/user
    run_sudo install -m644 "$root"/session/systemd/user/* /usr/lib/systemd/user/
fi

link_dotfiles() {
    (($#)) || return 0
    local config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local name dst backup file dots
    for name in "$@"; do
        if [ "$name" = firefox ]; then
            # Firefox files live in its profile, not ~/.config. padilha-dots
            # detects the profile; no ~/.config/firefox directory is created.
            continue
        fi
        if [ "$name" = micro ]; then
            # micro/install.sh links individual files and never the whole
            # directory: the colourscheme is generated and the plugin dir
            # must stay writable inside ~/.config/micro.
            continue
        fi
        dst="$config/$name"
        if [ "$name" = mc ]; then
            # MC shares ~/.config/mc with panels, hotlist and history. Link
            # only the static files and back each one up individually.
            run mkdir -p "$dst"
            for file in ini mc.keymap mc.ext.ini; do
                if [ -e "$dst/$file" ] && [ ! -L "$dst/$file" ]; then
                    backup="$dst/$file.pre-padilha-$(date +%Y%m%d-%H%M%S)"
                    warn "backing up $dst/$file -> $backup"
                    run mv "$dst/$file" "$backup"
                fi
            done
            continue
        fi
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            backup="$dst.pre-padilha-$(date +%Y%m%d-%H%M%S)"
            warn "backing up $dst -> $backup"
            run mv "$dst" "$backup"
        fi
    done
    dots="$dotfiles_dir/bin/padilha-dots"
    if [ ! -x "$dots" ]; then
        # The old checkout still works until its rename lands.
        dots="$dotfiles_dir/bin/lilith-dots"
    fi
    run "$dots" "$@"
}

if (( with_dotfiles )); then
    if [ ! -x "$dotfiles_dir/bin/padilha-dots" ] && [ ! -x "$dotfiles_dir/bin/lilith-dots" ]; then
        if [ -e "$dotfiles_dir" ]; then
            die "$dotfiles_dir exists but has no bin/padilha-dots"
        fi
        log "Fetching maria-padilha-dotfiles"
        run git clone https://github.com/maria-padilha-os/maria-padilha-dotfiles.git "$dotfiles_dir"
    fi

    if [ "$mode" = full ]; then
        # Firefox can only be installed after its first launch, so padilha-dots
        # skips it cleanly here and installs it when run again later.
        if [ -d "$dotfiles_dir/firefox" ]; then
            link_dotfiles hypr nvim wezterm mc firefox micro
        else
            link_dotfiles hypr nvim wezterm mc micro
        fi
        if [ -x "$dotfiles_dir/micro/install.sh" ]; then
            run "$dotfiles_dir/micro/install.sh"
        fi
    else
        link_dotfiles hypr
    fi
fi

# Default editor: EDITOR/VISUAL for the systemd user session and xdg-mime for
# text/plain (and whatever else the chosen desktop entry advertises).
configure_default_editor() {
    local chosen=$1
    local conf desktop
    conf="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/90-padilha-editor.conf"
    desktop=micro.desktop
    if [ "$chosen" = nvim ]; then
        desktop=nvim.desktop
    fi

    run mkdir -p "$(dirname "$conf")"
    if (( dry_run )); then
        printf '+ EDITOR=%s VISUAL=%s > %q\n' "$chosen" "$chosen" "$conf"
    else
        printf 'EDITOR=%s\nVISUAL=%s\n' "$chosen" "$chosen" >"$conf"
    fi

    if ! command -v xdg-mime >/dev/null 2>&1; then
        warn "xdg-mime not found; set the default text handler to $desktop manually"
        return 0
    fi
    local desktop_file="/usr/share/applications/$desktop"
    if [ ! -r "$desktop_file" ]; then
        warn "$desktop_file not found; set the default text handler manually"
        return 0
    fi
    local -a mimes
    read -r -a mimes <<<"$(sed -n 's/^MimeType=//p' "$desktop_file" | tr ';' ' ')"
    if [ ${#mimes[@]} -gt 0 ]; then
        run xdg-mime default "$desktop" "${mimes[@]}"
    fi
}

configure_default_editor "$editor"

# Register the mailto: handler. Leave an existing mail client alone unless the
# user explicitly selected the Office/Mail group; the handler itself falls
# back cleanly when Thunderbird is missing.
configure_mail_handler() {
    local entry=padilha-mail.desktop
    local current=
    if ! command -v xdg-mime >/dev/null 2>&1; then
        warn "xdg-mime not found; set the mailto: handler to $entry manually"
        return 0
    fi
    current=$(xdg-mime query default x-scheme-handler/mailto 2>/dev/null || true)
    if [ -n "$current" ] && [ "$current" != "$entry" ] && (( with_office_mail == 0 )); then
        log "Keeping the existing mailto: handler ($current)"
        return 0
    fi
    run xdg-mime default "$entry" x-scheme-handler/mailto
}

configure_mail_handler

if [ "$mode" = full ]; then
    cat <<'EOF'

Installed the full desktop.
1. Reboot (or log out) and choose "Maria Padilha" at the display manager.
2. If the greeter still lists plain Hyprland, pick Maria Padilha from the session menu.
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
2. `padilha-session` starts the shell; the Hyprland config calls it at login.
3. If you kept your own Hyprland config (--no-dotfiles), start Quickshell with
   `qs -c caelestia` after setting the QML import path from the build.

To uninstall the files installed by this script, see INSTALL.md.
EOF
fi
