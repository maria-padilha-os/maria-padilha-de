#!/usr/bin/env bash
# Multi-monitor and hotplug contract: pure screen-model updates, metadata-only
# panel layout, QML syntax and an offscreen load of the same modules.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "static wiring"
if /usr/bin/python3 "$root/tests/screens/check.py" "$root"; then
    ok "multi-monitor static contract"
else
    bad "multi-monitor static contract"
fi

echo "screen-model updates"
node_bin=$(command -v node || true)
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/screens/model.test.js" > "$tmp/model.log" 2>&1; then
    ok "add, remove, rotate, scale and last-output removal"
else
    bad "add, remove, rotate, scale and last-output removal" "$(tail -30 "$tmp/model.log")"
fi

echo "QML syntax"
qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    qml_files=(
        "$root/shell/services/ScreenModel.js"
        "$root/shell/services/OutputLayout.js"
        "$root/shell/services/Screens.qml"
        "$root/shell/services/PanelLayout.qml"
        "$root/shell/services/ShellState.qml"
        "$root/shell/services/Notifs.qml"
        "$root/shell/services/NotifData.qml"
        "$root/shell/components/ScreenState.qml"
        "$root/shell/modules/bar/BarWrapper.qml"
        "$root/shell/modules/drawers/Drawers.qml"
        "$root/shell/modules/drawers/Panels.qml"
        "$root/shell/modules/drawers/ContentWindow.qml"
        "$root/shell/modules/launcher/Wrapper.qml"
        "$root/shell/modules/dashboard/Wrapper.qml"
        "$root/shell/modules/notifications/Wrapper.qml"
        "$root/shell/modules/notifications/Content.qml"
        "$root/shell/modules/background/Background.qml"
        "$root/shell/modules/background/Wallpaper.qml"
    )
    lint_failed=()
    for file in "${qml_files[@]}"; do
        case "$file" in
        *.js)
            if [ -n "$node_bin" ] && ! "$node_bin" --check "$file" > "$tmp/node-check.log" 2>&1; then
                lint_failed+=("$file: $(tail -4 "$tmp/node-check.log")")
            fi
            ;;
        *)
            if ! "$qmllint" -I /usr/lib/qt6/qml -I "$root/shell" "$file" > "$tmp/qmllint.log" 2>&1; then
                lint_failed+=("$file: $(tail -4 "$tmp/qmllint.log")")
            fi
            ;;
        esac
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint and node --check accept the screen files"
    else
        bad "qmllint and node --check accept the screen files" "${lint_failed[0]}"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "QML-engine load"
qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ]; then
    printf '  skip %s\n' "Quickshell is not installed"
else
    mkdir -p "$tmp/home" "$tmp/config" "$tmp/data" "$tmp/state" "$tmp/cache" "$tmp/runtime"
    chmod 700 "$tmp/runtime"
    export HOME="$tmp/home"
    export XDG_CONFIG_HOME="$tmp/config"
    export XDG_DATA_HOME="$tmp/data"
    export XDG_STATE_HOME="$tmp/state"
    export XDG_CACHE_HOME="$tmp/cache"
    export XDG_RUNTIME_DIR="$tmp/runtime"
    export QT_QPA_PLATFORM=offscreen
    export PADILHA_PANEL_LAYOUT="$tmp/state/panel-layout.json"
    mkdir -p "$tmp/load"
    cp "$root/tests/screens/load.qml" "$root/shell/services/ScreenModel.js" "$root/shell/services/OutputLayout.js" "$tmp/load/"
    if timeout 60 "$qs_bin" -p "$tmp/load/load.qml" > "$tmp/load.log" 2>&1; then
        ok "screen model and layout load in Quickshell's QML engine"
    else
        bad "screen model and layout load in Quickshell's QML engine" "$(tail -30 "$tmp/load.log")"
    fi

    mkdir -p "$tmp/import/qs/services"
    cp "$root/shell/services/PanelLayout.qml" "$root/shell/services/ScreenModel.js" "$root/shell/services/OutputLayout.js" "$tmp/import/qs/services/"
    printf 'module qs.services\nsingleton PanelLayout 1.0 PanelLayout.qml\n' > "$tmp/import/qs/services/qmldir"
    cp "$root/tests/screens/panel-layout.qml" "$tmp/load/"
    if QML2_IMPORT_PATH="$tmp/import" timeout 60 "$qs_bin" -p "$tmp/load/panel-layout.qml" > "$tmp/panel-layout.log" 2>&1; then
        ok "PanelLayout survives add, remove, rotate and reconnect"
    else
        bad "PanelLayout survives add, remove, rotate and reconnect" "$(tail -30 "$tmp/panel-layout.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
