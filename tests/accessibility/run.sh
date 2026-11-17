#!/usr/bin/env bash
# Accessibility contract: static focus/name checks, the generated palette
# contrast fixture, and an offscreen load of the shared controls.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "static keyboard and name contract"

if /usr/bin/python3 "$root/tests/accessibility/check.py" "$root"; then
    ok "static accessibility contract"
else
    bad "static accessibility contract"
fi

echo "contrast fixture"

if /usr/bin/python3 "$root/tests/accessibility/contrast.py" "$root"; then
    ok "light and dark palette contrast"
else
    bad "light and dark palette contrast"
fi

echo "QML loading"

qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "Quickshell or the Caelestia plugin is not installed"
else
    config="$tmp/config"
    mkdir -p "$config/components/controls" "$config/services" \
        "$tmp/home" "$tmp/cache" "$tmp/runtime"
    chmod 700 "$tmp/runtime"

    for file in StyledRect.qml CAnim.qml Anim.qml MaterialIcon.qml StateLayer.qml FocusRing.qml StyledText.qml; do
        cp "$root/shell/components/$file" "$config/components/$file"
    done
    for file in IconButton.qml ButtonBase.qml SearchBar.qml TextFieldBase.qml StyledSwitch.qml StyledRadioButton.qml; do
        cp "$root/shell/components/controls/$file" "$config/components/controls/$file"
    done
    cp "$root/shell/services/Accessibility.qml" "$config/services/Accessibility.qml"
    cp "$root/tests/accessibility/Colours.qml" "$config/services/Colours.qml"
    cp "$root/tests/accessibility/load.qml" "$config/shell.qml"

    export HOME="$tmp/home"
    export XDG_CONFIG_HOME="$tmp/config-home"
    export XDG_DATA_HOME="$tmp/data"
    export XDG_STATE_HOME="$tmp/state"
    export XDG_CACHE_HOME="$tmp/cache"
    export XDG_RUNTIME_DIR="$tmp/runtime"
    export QT_QPA_PLATFORM=offscreen

    if PADILHA_REDUCED_MOTION=0 PADILHA_A11Y_EXPECT_REDUCED=0 \
        timeout 60 "$qs_bin" -p "$config" > "$tmp/load.log" 2>&1; then
        ok "shared controls load with accessible names"
    else
        bad "shared controls load with accessible names" "$(tail -20 "$tmp/load.log")"
    fi

    if PADILHA_REDUCED_MOTION=1 PADILHA_A11Y_EXPECT_REDUCED=1 \
        timeout 60 "$qs_bin" -p "$config" > "$tmp/reduced.log" 2>&1; then
        ok "reduced-motion mode loads and reports zero duration"
    else
        bad "reduced-motion mode loads and reports zero duration" "$(tail -20 "$tmp/reduced.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
