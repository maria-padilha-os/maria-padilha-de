#!/usr/bin/env bash
# Contract tests for bin/lilith, the small command surface the shell and the
# keybinds call.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
lilith="$root/bin/lilith"
wall="$root/share/wallpapers/night.jpg"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "usage"

if "$lilith" > /dev/null 2>&1; then bad "no command prints usage and exits 2"; else
    [ $? -eq 2 ] && ok "no command prints usage and exits 2" || bad "no command exits 2"
fi

if "$lilith" scheme set --variant nope > /dev/null 2>&1; then
    bad "an unknown variant is refused"
else
    err=$("$lilith" scheme set --variant nope 2>&1)
    if printf '%s' "$err" | grep -q "is not a variant"; then ok "an unknown variant is refused"; else bad "an unknown variant is refused" "$err"; fi
fi

echo "scheme"

variant=$("$lilith" scheme get 2>/dev/null)
if [ -n "$variant" ]; then ok "scheme get names a variant"; else bad "scheme get names a variant"; fi

"$lilith" scheme list > "$tmp/list.json" 2>/dev/null
if /usr/bin/python3 - "$tmp/list.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert len(d) >= 8, d.keys()
for name, entry in d.items():
    assert "colours" in entry, name
    assert len(entry["colours"]) >= 120, (name, len(entry["colours"]))
PY
then
    ok "scheme list has every variant and its colours"
else
    bad "scheme list has every variant and its colours"
fi

echo "wallpaper"

"$lilith" wallpaper -p "$wall" > "$tmp/scheme.json" 2>/dev/null
if /usr/bin/python3 - "$tmp/scheme.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["mode"] in ("light", "dark")
assert len(d["colours"]) >= 120
assert d["colours"]["surface"]
PY
then
    ok "wallpaper -p prints a full palette"
else
    bad "wallpaper -p prints a full palette"
fi

if [ -e "$HOME/.local/state/caelestia/wallpaper/path.txt" ]; then
    before=$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt")
fi
"$lilith" wallpaper -p "$wall" > /dev/null 2>&1
after=$(cat "$HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)
if [ "${before:-}" = "${after:-}" ]; then ok "wallpaper -p writes nothing"; else bad "wallpaper -p writes nothing"; fi

echo "doctor"

doc=$("$lilith" doctor 2>&1)
if printf '%s' "$doc" | grep -q "state directory" && printf '%s' "$doc" | grep -q "Hyprland"; then
    ok "doctor reports the pieces it checks"
else
    bad "doctor reports the pieces it checks" "$doc"
fi
if printf '%s' "$doc" | grep -qE "^(ok|warn|FAIL) "; then
    ok "doctor lines carry a status"
else
    bad "doctor lines carry a status" "$doc"
fi
if [ -n "$($lilith doctor 2>&1)" ]; then ok "doctor always says something"; else bad "doctor always says something"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
