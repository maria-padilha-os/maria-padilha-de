#!/usr/bin/env bash
# Contract test for the standalone Thunderbird palette writer.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
theme="$root/bin/padilha-theme"
writer="$root/bin/padilha-thunderbird-theme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() {
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
}
bad() {
    fail=$((fail + 1))
    printf '  FAIL %s\n' "$1"
}

for mode in light dark; do
    prefix="$tmp/$mode"
    home="$prefix/home/machine"
    profile="$home/.config/thunderbird/solo"
    css="$profile/chrome/padilha.css"

    "$theme" apply --seed ff1a1a --mode "$mode" --prefix "$prefix" --no-signals >/dev/null 2>&1
    mkdir -p "$profile"
    cat >"$home/.config/thunderbird/profiles.ini" <<'INI'
[Profile0]
Name=solo
IsRelative=1
Path=solo
Default=1
INI

    if HOME="$home" XDG_CONFIG_HOME="$home/.config" "$writer" >/dev/null 2>&1; then
        ok "the writer exits 0 ($mode)"
    else
        bad "the writer exits 0 ($mode)"
    fi

    if [ -s "$css" ]; then
        ok "the writer creates chrome/padilha.css ($mode)"
    else
        bad "the writer creates chrome/padilha.css ($mode)"
    fi

    if grep -q "color-scheme: $mode" "$css" 2>/dev/null && grep -q -- '--padilha-primary' "$css"; then
        ok "the stylesheet carries the mode and palette ($mode)"
    else
        bad "the stylesheet carries the mode and palette ($mode)"
    fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
