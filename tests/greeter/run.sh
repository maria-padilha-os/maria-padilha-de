#!/usr/bin/env bash
# Authenticate against a fake greetd socket and launch a dummy session.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'kill "${server_pid:-}" 2>/dev/null; rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

if ! command -v qs >/dev/null 2>&1; then
    printf '  skip %s\n' "Quickshell is not installed"
    exit 0
fi

python3 "$root/tests/greeter/fake-greetd.py" "$tmp/greetd.sock" "$tmp/transcript.jsonl" >"$tmp/server.log" 2>&1 &
server_pid=$!
for _ in $(seq 1 50); do
    [ -S "$tmp/greetd.sock" ] && break
    sleep 0.1
done
if [ ! -S "$tmp/greetd.sock" ]; then
    bad "fake greetd started" "$(cat "$tmp/server.log")"
    printf '\n%d passed, %d failed\n' "$pass" "$fail"
    exit 1
fi
ok "fake greetd started"

GREETD_SOCK="$tmp/greetd.sock" QT_QPA_PLATFORM=offscreen timeout 10 \
    qs -p "$root/tests/greeter/flow.qml" --no-color >"$tmp/qs.log" 2>&1
status=$?
if [ "$status" -eq 0 ] && grep -q 'TEST_LAUNCHED' "$tmp/qs.log"; then
    ok "greetd authentication and launch complete"
else
    bad "greetd authentication and launch complete" "exit $status: $(tail -5 "$tmp/qs.log")"
fi

if grep -q '"type": "create_session"' "$tmp/transcript.jsonl" &&
    grep -q '"type": "start_session"' "$tmp/transcript.jsonl"; then
    ok "greetd saw create_session and start_session"
else
    bad "greetd saw create_session and start_session" "$(cat "$tmp/transcript.jsonl")"
fi

# The production config must load even when greetd is not running.
QT_QPA_PLATFORM=offscreen timeout 3 qs -p "$root/share/greeter" --no-color >"$tmp/ui.log" 2>&1
if grep -q "Configuration Loaded" "$tmp/ui.log" && ! grep -q "ERROR:" "$tmp/ui.log"; then
    ok "greeter UI loads offscreen"
else
    bad "greeter UI loads offscreen" "$(tail -5 "$tmp/ui.log")"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
