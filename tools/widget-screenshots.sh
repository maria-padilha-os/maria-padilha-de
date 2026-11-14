#!/usr/bin/env bash
# Render the widget tabs used by the design checklist to PNG without touching
# the live session. Quickshell runs offscreen against a throwaway HOME; the
# extensions are inactive, so no clipboard, network, audio, or shell process is
# started. Pass a checkout root to capture the baseline or the current tree.
#
#   tools/widget-screenshots.sh --root . --out /tmp/widgets-after
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
out=
tree=$root
minimum=0
while [ $# -gt 0 ]; do
    case "$1" in
        --out) out=${2:?--out needs a directory}; shift 2 ;;
        --root) tree=$(CDPATH='' cd -- "${2:?--root needs a directory}" && pwd); shift 2 ;;
        --min) minimum=1; shift ;;
        -h|--help) printf 'usage: %s [--root CHECKOUT] [--out DIR] [--min]\n' "$0"; exit 0 ;;
        *) printf '%s: unknown option %s\n' "$0" "$1" >&2; exit 2 ;;
    esac
done

qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ]; then
    printf '%s: qs is not installed\n' "$0" >&2
    exit 1
fi

out=${out:-"$root/.scratch/widget-screenshots"}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out" "$tmp/home/.config/gtk-3.0" "$tmp/home/.config/gtk-4.0" "$tmp/config" "$tmp/data" "$tmp/state" "$tmp/cache" "$tmp/runtime"
chmod 700 "$tmp/runtime"
printf '[Settings]\ngtk-icon-theme-name=Papirus-Dark\n' > "$tmp/home/.config/gtk-3.0/settings.ini"
printf '[Settings]\ngtk-icon-theme-name=Papirus-Dark\n' > "$tmp/home/.config/gtk-4.0/settings.ini"

widgets=()
for id in calculator filemanager maps stopwatch translator tuner; do
    tab=$tree/extensions/$id/Tab.qml
    [ -f "$tab" ] || { printf '%s: missing %s\n' "$0" "$tab" >&2; exit 1; }
    widgets+=("$id|$tab")
done

export HOME=$tmp/home
export XDG_CONFIG_HOME=$tmp/config
export XDG_DATA_HOME=$tmp/data
export XDG_STATE_HOME=$tmp/state
export XDG_CACHE_HOME=$tmp/cache
export XDG_RUNTIME_DIR=$tmp/runtime
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
export QT_QPA_PLATFORM=offscreen
export QS_ICON_THEME=${QS_ICON_THEME:-Papirus-Dark}
export PADILHA_SCREENSHOT_DIR=$out
export PADILHA_SCREENSHOT_HOME=$tmp/home
export PADILHA_SCREENSHOT_MIN=$minimum
PADILHA_SCREENSHOT_WIDGETS=$(printf '%s\n' "${widgets[@]}")
export PADILHA_SCREENSHOT_WIDGETS

timeout 120 "$qs_bin" -p "$root/tests/screenshots/render.qml" > "$tmp/render.log" 2>&1 || {
    tail -20 "$tmp/render.log" >&2
    exit 1
}

for id in calculator filemanager maps stopwatch translator tuner; do
    [ -f "$out/$id.png" ] || { printf '%s: did not render %s\n' "$0" "$id" >&2; exit 1; }
done
printf 'wrote %s widget captures to %s\n' 6 "$out"
