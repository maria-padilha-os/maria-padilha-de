#!/usr/bin/env bash
# Contract tests for the paired day/night theme store and its CLI. These do
# not apply a theme; they exercise the state that the scheduler and UI share.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
padilha="$root/bin/padilha"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$HOME"
day="$root/share/wallpapers/day.jpg"
night="$root/share/wallpapers/night.jpg"

out=$(PATH="$root/bin:$PATH" "$padilha" theme add --name 'Test Pair' --day "$day" --night "$night" 2>&1)
status=$?
check "add a paired theme" "[ $status -eq 0 ]" "$out"
check "theme id is slugged" "printf '%s' '$out' | grep -qx 'test-pair'"

json=$(PATH="$root/bin:$PATH" "$padilha" theme list --json 2>/dev/null)
check "list emits JSON" "printf '%s' '$json' | python3 -m json.tool >/dev/null"
check "list keeps both images" "printf '%s' '$json' | python3 -c 'import json,sys;d=json.load(sys.stdin);t=d[\"themes\"][0];assert t[\"day\"] and t[\"night\"]'"
check "list has no active theme" "printf '%s' '$json' | python3 -c 'import json,sys;assert json.load(sys.stdin)[\"active\"]==\"\"'"

PATH="$root/bin:$PATH" "$padilha" theme remove test-pair >/dev/null 2>&1
check "remove the paired theme" "PATH='$root/bin:'\"\$PATH\" '$padilha' theme list --json 2>/dev/null | python3 -c 'import json,sys;assert json.load(sys.stdin)[\"themes\"]==[]'"

# A missing image must fail before writing the theme store.
PATH="$root/bin:$PATH" "$padilha" theme add --name Broken --day /no/such/day.jpg --night "$night" >/dev/null 2>&1
check "missing images are rejected" "[ \$? -ne 0 ]"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
