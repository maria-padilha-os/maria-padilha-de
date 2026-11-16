#!/usr/bin/env bash
# Files tab keyboard contract: binding table, static QML promises, QML loading
# and the focus hand-off between the list, search and address bar. The runtime
# harness uses the real Tab.qml and an offscreen window; it never opens a file.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "static keyboard contract"

if /usr/bin/python3 "$root/tests/filemanager/check.py" "$root"; then
    ok "Files keyboard contract checker"
else
    bad "Files keyboard contract checker"
fi

echo "binding table"

node_bin=$(command -v node || true)
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/filemanager/keybindings.test.js" > "$tmp/keybindings.log" 2>&1; then
    ok "Vim binding table and destructive-action guard"
else
    bad "Vim binding table and destructive-action guard" "$(tail -30 "$tmp/keybindings.log")"
fi

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "$root/extensions/filemanager/Tab.qml" "$root/extensions/filemanager/Widget.qml"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the Files tab and widget"
    else
        bad "qmllint accepts the Files tab and widget" "${lint_failed[0]}: $(tail -4 "$tmp/qmllint.log")"
    fi

    dialog_failed=()
    for file in \
        "$root/shell/components/filedialog/FileDialog.qml" \
        "$root/shell/components/filedialog/Sidebar.qml" \
        "$root/shell/components/filedialog/HeaderBar.qml" \
        "$root/shell/components/filedialog/FolderContents.qml"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml -I "$root/shell" "$file" > "$tmp/qmllint-dialog.log" 2>&1; then
            dialog_failed+=("$file")
        fi
    done
    if [ ${#dialog_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the file dialog sidebar and address bar"
    else
        bad "qmllint accepts the file dialog sidebar and address bar" "${dialog_failed[0]}: $(tail -4 "$tmp/qmllint-dialog.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "loads and focus switches"

qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "Quickshell or the Caelestia plugin is not installed"
else
    mkdir -p "$tmp/home" "$tmp/config" "$tmp/data" "$tmp/state" "$tmp/cache" "$tmp/runtime"
    chmod 700 "$tmp/runtime"
    for index in $(seq -w 1 30); do
        : > "$tmp/home/alpha-$index.txt"
    done
    mkdir -p "$tmp/home/alpha-folder"
    export HOME="$tmp/home"
    export XDG_CONFIG_HOME="$tmp/config"
    export XDG_DATA_HOME="$tmp/data"
    export XDG_STATE_HOME="$tmp/state"
    export XDG_CACHE_HOME="$tmp/cache"
    export XDG_RUNTIME_DIR="$tmp/runtime"
    export QT_QPA_PLATFORM=offscreen
    export PADILHA_FILEMANAGER_TAB="$root/extensions/filemanager/Tab.qml"
    if timeout 120 "$qs_bin" -p "$root/tests/filemanager/load.qml" > "$tmp/load.log" 2>&1; then
        ok "Files tab loads, moves, searches and restores focus"
    else
        bad "Files tab loads, moves, searches and restores focus" "$(tail -40 "$tmp/load.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
