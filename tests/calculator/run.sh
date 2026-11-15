#!/usr/bin/env bash
# Calculator contract: static backend/keypad checks, QML syntax, then a real
# offscreen load at the compact minimum and a full dashboard size. The runtime
# harness feeds the result path directly, so it never starts qalc or a network
# request while exercising keypad, history and error handling.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "keypad, backend and palette contract"

if /usr/bin/python3 "$root/tests/calculator/check.py" "$root"; then
    ok "calculator contract checker"
else
    bad "calculator contract checker"
fi

qalc_bin=$(command -v qalc || true)
if [ -z "$qalc_bin" ]; then
    printf '  skip %s\n' "qalc is not installed"
else
    mkdir -p "$tmp/home" "$tmp/config"
    out=$(HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" timeout 20 "$qalc_bin" -t '6*7' 2>/dev/null)
    if [ "$out" = "42" ]; then
        ok "qalc still evaluates a local expression"
    else
        bad "qalc still evaluates a local expression" "$out"
    fi
fi

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "$root/extensions/calculator/Tab.qml" "$root/extensions/calculator/Widget.qml"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the calculator tab and widget"
    else
        bad "qmllint accepts the calculator tab and widget" "${lint_failed[0]}: $(tail -4 "$tmp/qmllint.log")"
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
    export PADILHA_CALCULATOR_TAB="$root/extensions/calculator/Tab.qml"
    if timeout 120 "$qs_bin" -p "$root/tests/calculator/size.qml" > "$tmp/size.log" 2>&1; then
        ok "calculator loads and fits at 360x460 and 1000x600"
    else
        bad "calculator loads and fits at 360x460 and 1000x600" "$(tail -30 "$tmp/size.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
