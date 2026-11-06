#!/usr/bin/env bash
# Contract tests for padilha-lock: it must use hyprlock by default, refuse to
# fall back to the unstable shell lock, and keep that fallback opt-in.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
lock="$root/bin/padilha-lock"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

fake="$tmp/bin"
mkdir -p "$fake"
cat >"$fake/hyprlock" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$PADILHA_TEST_MARKER"
SH
chmod +x "$fake/hyprlock"

marker="$tmp/hyprlock.args"
if PATH="$fake:$PATH" PADILHA_TEST_MARKER="$marker" "$lock"; then
    if [ -f "$marker" ]; then
        ok "the default path runs hyprlock"
    else
        bad "the default path runs hyprlock"
    fi
else
    bad "the default path runs hyprlock"
fi

empty="$tmp/empty"
mkdir -p "$empty"
cat >"$empty/notify-send" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$empty/notify-send"

if PATH="$empty" "$lock" >"$tmp/out" 2>"$tmp/err"; then
    bad "a missing hyprlock is refused"
else
    ok "a missing hyprlock is refused"
fi
if grep -q 'hyprlock is not installed' "$tmp/err"; then
    ok "the refusal explains what is missing"
else
    bad "the refusal explains what is missing" "$(cat "$tmp/err")"
fi

cat >"$fake/qs" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$PADILHA_TEST_MARKER"
SH
chmod +x "$fake/qs"
marker="$tmp/qs.args"
if PATH="$fake:$PATH" PADILHA_TEST_MARKER="$marker" \
    PADILHA_ALLOW_SHELL_LOCK=1 "$lock"; then
    if [ -f "$marker" ] && grep -q 'ipc call lock lock' "$marker"; then
        ok "the shell lock is available only as an explicit fallback"
    else
        bad "the shell lock is available only as an explicit fallback"
    fi
else
    bad "the shell lock is available only as an explicit fallback"
fi

if "$lock" -h >/dev/null 2>&1; then
    ok "-h exits 0"
else
    bad "-h exits 0"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
