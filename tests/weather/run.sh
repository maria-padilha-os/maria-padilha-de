#!/usr/bin/env bash
# Weather contract: parse fixture responses, bound the cache and refresh, keep
# provider keys out of the checkout/cache, and lint the QML. No network is used.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "fixture parsing and cache bounds"

node_bin=$(command -v node || true)
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/weather/WeatherData.test.js" > "$tmp/weather.log" 2>&1; then
    ok "WeatherData.js fixture, URL and cache tests"
else
    bad "WeatherData.js fixture, URL and cache tests" "$(tail -30 "$tmp/weather.log")"
fi

echo "privacy"

if grep -Eqi "ip-api|ipapi|ipApiRequest|ipApiBlocked" "$root/shell/services/Weather.qml"; then
    bad "Weather.qml has no implicit IP lookup"
else
    ok "Weather.qml has no implicit IP lookup"
fi

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
weather_qml=(
    "$root/shell/services/Weather.qml"
    "$root/shell/modules/dashboard/WeatherTab.qml"
    "$root/shell/modules/dashboard/dash/SmallWeather.qml"
    "$root/shell/modules/nexus/pages/LanguageAndRegion.qml"
)
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "${weather_qml[@]}"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the weather service, panels and settings page"
    else
        bad "qmllint accepts the weather service, panels and settings page" "${lint_failed[0]}: $(tail -8 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
