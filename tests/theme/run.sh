#!/usr/bin/env bash
# Contract tests for bin/padilha-theme: the promises the theme engine makes to
# every file it writes.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
theme="$root/bin/padilha-theme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

echo "colour maths"

if /usr/bin/python3 "$root/tests/theme/check-colour.py" > "$tmp/colour.log" 2>&1; then
    ok "matches the Material reference"
else
    bad "matches the Material reference" "$(tail -3 "$tmp/colour.log")"
fi

echo "scheme"

"$theme" scheme --seed ff1a1a --mode dark --print > "$tmp/dark.json" 2>/dev/null
"$theme" scheme --seed ff1a1a --mode light --print > "$tmp/light.json" 2>/dev/null

check "dark scheme is valid JSON" "/usr/bin/python3 -m json.tool < '$tmp/dark.json' > /dev/null 2>&1"
check "light scheme is valid JSON" "/usr/bin/python3 -m json.tool < '$tmp/light.json' > /dev/null 2>&1"

count=$(/usr/bin/python3 -c "import json;print(len(json.load(open('$tmp/dark.json'))['colours']))")
check "carries every colour the shell asks for" "[ $count -ge 120 ]" "only $count colours"

# The default is black and red: dark surfaces, a red primary, and no hue drift
# into the neutrals.
read -r surface primary light_primary <<<"$(/usr/bin/python3 - "$tmp/dark.json" "$tmp/light.json" <<'PY'
import json, sys
dark = json.load(open(sys.argv[1]))['colours']
light = json.load(open(sys.argv[2]))['colours']
print(dark['surface'], dark['primary'], light['primary'])
PY
)"

tone() {
    /usr/bin/python3 - "$1" "$root" <<'PY'
import sys, subprocess
# Use the engine itself as the oracle: hex -> tone.
out = subprocess.run(["lua", sys.argv[2] + "/tests/theme/dump-colour.lua", sys.argv[2]],
                     input="hex " + sys.argv[1], text=True, capture_output=True).stdout.split()
print(round(float(out[2])))
PY
}

check "dark surface is near black" "[ $(tone "$surface") -le 12 ]" "tone $(tone "$surface")"
check "dark primary is light enough to read" "[ $(tone "$primary") -ge 70 ]" "tone $(tone "$primary")"

echo "templates"

"$theme" apply --seed ff1a1a --mode dark --prefix "$tmp/tree" --no-signals > /dev/null 2>&1
written=$(find "$tmp/tree" -type f | wc -l)
check "apply writes the whole set" "[ $written -ge 14 ]" "only $written files"
check "no template placeholders survive" "! grep -rq '{{' '$tmp/tree'"
check "no empty files" "! find '$tmp/tree' -type f -empty | grep -q ."

gtk="$tmp/tree/home/machine/.config/gtk-3.0/gtk.css"
hypr="$tmp/tree/home/machine/.config/hypr/scheme/current.lua"
seq="$tmp/tree/home/machine/.local/state/caelestia/sequences.txt"

check "gtk gets hashed colours" "grep -q 'window_bg_color #' '$gtk'"
check "hypr gets bare colours" "grep -q 'surface = \"' '$hypr'"
check "terminals get OSC 11" "grep -q ']11;rgb:' '$seq'"

echo "modes differ"

"$theme" apply --seed ff1a1a --mode light --prefix "$tmp/light-tree" --no-signals > /dev/null 2>&1
light_surface=$(tone "$(/usr/bin/python3 -c "import json;print(json.load(open('$tmp/light-tree/home/machine/.local/state/caelestia/scheme.json'))['colours']['surface'])")")
check "light mode has a light surface" "[ $light_surface -ge 90 ]" "tone $light_surface"

echo "unknown colours fail loudly"

cat > "$tmp/bad.lua" <<'LUA'
return "{{ $notAColour }}"
LUA
# The renderer is only reachable through a template; use the module directly.
if lua -e "package.path='$root/lib/?.lua;'..package.path; local t=require('template'); t.render('{{ \$nope }}', {})" > /dev/null 2>&1; then
    bad "a missing colour is an error"
else
    ok "a missing colour is an error"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
