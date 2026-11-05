#!/usr/bin/env bash
# Contract tests for bin/lilith-reload: the restart path must not leave the
# desktop without a shell because the old instance's runtime directory is
# still around.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
reload="$root/bin/lilith-reload"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "usage"

if sh -n "$reload"; then ok "the script parses"; else bad "the script parses"; fi

if "$reload" -h >/dev/null 2>&1; then ok "-h exits 0"; else bad "-h exits 0"; fi

if "$reload" --nope >/dev/null 2>&1; then bad "unknown options are refused"; else
    [ $? -eq 2 ] && ok "unknown options are refused" || bad "unknown options exit 2"
fi

echo "restart"

mkdir -p "$tmp/bin" "$tmp/runtime/quickshell/by-id/stale"
chmod 700 "$tmp/runtime"
touch "$tmp/runtime/quickshell/by-id/stale/marker" "$tmp/alive"
cat >"$tmp/bin/qs" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$QS_LOG"
case "$*" in
"-c caelestia kill")
    rm -f "$QS_ALIVE"
    exit 0
    ;;
"-c caelestia ipc show")
    [ -f "$QS_ALIVE" ] && exit 0
    exit 255
    ;;
"-c caelestia -n -d")
    if [ -e "$XDG_RUNTIME_DIR/quickshell" ]; then
        echo "runtime still present" >> "$QS_LOG"
        exit 1
    fi
    touch "$QS_STARTED"
    exit 0
    ;;
esac
exit 0
SH
chmod +x "$tmp/bin/qs"

export PATH="$tmp/bin:$PATH"
export XDG_RUNTIME_DIR="$tmp/runtime"
export QS_LOG="$tmp/qs.log"
export QS_ALIVE="$tmp/alive"
export QS_STARTED="$tmp/started"

if "$reload" >/dev/null 2>&1; then ok "reload exits 0"; else bad "reload exits 0"; fi
if [ -f "$QS_STARTED" ]; then ok "the new shell is started"; else bad "the new shell is started"; fi
if [ ! -e "$tmp/runtime/quickshell" ]; then ok "the stale runtime directory is cleared"; else bad "the stale runtime directory is cleared"; fi
if grep -qx -- '-c caelestia -n -d' "$QS_LOG"; then ok "the duplicate guard is used"; else bad "the duplicate guard is used" "$(cat "$QS_LOG" 2>/dev/null)"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
