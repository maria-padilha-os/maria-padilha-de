#!/usr/bin/env bash
# Contract checks for padilha-brightness: sysfs is the read path, and the
# brightnessctl helper is not spawned on every poll.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
brightness="$root/bin/padilha-brightness"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

backlight="$tmp/backlight"
mkdir -p "$backlight/amdgpu_bl1"
printf '500\n' >"$backlight/amdgpu_bl1/brightness"
printf '1000\n' >"$backlight/amdgpu_bl1/max_brightness"

fake="$tmp/bin"
mkdir -p "$fake"
marker="$tmp/brightnessctl.called"
cat >"$fake/brightnessctl" <<SH
#!/bin/sh
touch "$marker"
exit 1
SH
chmod +x "$fake/brightnessctl"

out=$(PATH="$fake:$PATH" PADILHA_BACKLIGHT_DIR="$backlight" "$brightness" --status 2>&1)
if printf '%s' "$out" | grep -q 'current=50%'; then
    ok "sysfs brightness is read correctly"
else
    bad "sysfs brightness is read correctly" "$out"
fi
if [ ! -e "$marker" ]; then
    ok "the polling read does not spawn brightnessctl"
else
    bad "the polling read does not spawn brightnessctl"
fi

target=$(PATH="$fake:$PATH" PADILHA_BACKLIGHT_DIR="$backlight" "$brightness" --target 2>&1)
case "$target" in
    '' | *[!0-9]*) bad "--target prints a percentage" "$target" ;;
    *)
        if [ "$target" -ge 0 ] && [ "$target" -le 100 ]; then
            ok "--target prints a percentage"
        else
            bad "--target prints a percentage" "$target"
        fi
        ;;
esac

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
