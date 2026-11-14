#!/usr/bin/env bash
# Translator layout contract: static checks for the preserved interactions and
# provider, then a real Quickshell load at 480x280, a short full dashboard and a
# roomy dashboard size.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "layout and interaction contract"

if /usr/bin/python3 "$root/tests/translator/check.py" "$root"; then
    ok "translator contract checker"
else
    bad "translator contract checker"
fi

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "$root/extensions/translator/Tab.qml" "$root/extensions/translator/Widget.qml"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the translator tab and widget"
    else
        bad "qmllint accepts the translator tab and widget" "${lint_failed[0]}: $(tail -4 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "loads and sizes"

qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "Quickshell or the Caelestia plugin is not installed"
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
    export PADILHA_TRANSLATOR_TAB="$root/extensions/translator/Tab.qml"
    if timeout 120 "$qs_bin" -p "$root/tests/translator/size.qml" > "$tmp/size.log" 2>&1; then
        ok "translator loads and fits at 480x280, 1000x320 and 1000x600"
    else
        bad "translator loads and fits at 480x280, 1000x320 and 1000x600" "$(tail -30 "$tmp/size.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
