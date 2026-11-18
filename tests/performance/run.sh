#!/usr/bin/env bash
# Performance budget: static contracts plus a short offscreen full-shell run.
# The runtime half is skipped when Quickshell or its Caelestia plugin is absent.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "static performance contract"
if /usr/bin/python3 "$root/tests/performance/check.py" "$root"; then
    ok "static performance contract"
else
    bad "static performance contract"
fi

echo "offscreen performance budget"
qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "Quickshell or the Caelestia plugin is not installed"
else
    if /usr/bin/python3 "$root/tests/performance/measure.py" \
        --root "$root" \
        --baseline "$root/tests/performance/baseline.json" \
        --repetitions "${PADILHA_PERF_REPETITIONS:-2}"; then
        ok "startup, idle CPU, memory and QML warning classes are within budget"
    else
        bad "startup, idle CPU, memory and QML warning classes are within budget"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
