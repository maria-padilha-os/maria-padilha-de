#!/usr/bin/env bash
# Scenario test for the Lua brightness daemon, with fake sysfs and a fake
# brightnessctl so nothing touches the real backlight.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
daemon="$root/spikes/lua-brightness/daemon.lua"
tmp=$(mktemp -d)
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

mkdir -p "$tmp/backlight/card0" "$tmp/state" "$tmp/bin"
printf '100\n' >"$tmp/backlight/card0/max_brightness"
printf '50\n' >"$tmp/backlight/card0/brightness"
cat >"$tmp/bin/brightnessctl" <<'SH'
#!/bin/sh
dir="${PADILHA_BACKLIGHT_DIR:?}/card0"
case "${1:-}" in
  s)
    value=$(printf '%s' "${2:-}" | tr -d '%')
    max=$(cat "$dir/max_brightness")
    echo $((value * max / 100)) >"$dir/brightness"
    ;;
  g) cat "$dir/brightness" ;;
  m) cat "$dir/max_brightness" ;;
esac
SH
chmod +x "$tmp/bin/brightnessctl"

export PATH="$tmp/bin:$PATH"
export PADILHA_BACKLIGHT_DIR="$tmp/backlight"
export XDG_STATE_HOME="$tmp/state"
export PADILHA_BRIGHTNESS_POLL=0.2

state="$tmp/state/padilha/brightness.state"
log="$tmp/log.csv"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

target=$(lua "$daemon" --target "$(date +%s)")
[ -n "$target" ] || fail "no target"
# Start at the curve value so the first run does not need to change anything.
printf '%s\n' "$target" >"$tmp/backlight/card0/brightness"
lua "$daemon" --write --poll 0.2 --cycles 3 --log "$log" || fail "initial run"
[ -f "$state" ] || fail "no state file"
applied=$(sed -n 's/^last_applied=//p' "$state")
[ -n "$applied" ] || fail "no last_applied"
[ "$applied" = "$target" ] || fail "initial last_applied=$applied want=$target"

# A manual change while the daemon runs must hold the user's value.
lua "$daemon" --write --poll 0.2 --cycles 40 --log "$log" &
pid=$!
sleep 0.8
printf '30\n' >"$tmp/backlight/card0/brightness"
wait "$pid" || true
rm -rf "$state.lock.d"
override=$(sed -n 's/^override_until=//p' "$state")
applied=$(sed -n 's/^last_applied=//p' "$state")
now=$(date +%s)
[ "$applied" = "30" ] || fail "manual last_applied=$applied want=30"
[ "${override:-0}" -gt "$now" ] || fail "manual override_until=$override is not in the future"

# Expire the hold: the daemon must follow the curve again.
sed -i 's/^override_until=.*/override_until=0/' "$state"
lua "$daemon" --write --poll 0.2 --cycles 3 --log "$log" || fail "expired run"
final=$(sed -n 's/^last_applied=//p' "$state")
[ "$final" != "30" ] || fail "expired last_applied is still the manual value"

printf 'scenario ok: initial=%s manual=30 final=%s\n' "$target" "$final"
