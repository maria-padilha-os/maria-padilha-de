#!/usr/bin/env bash
# Contract tests for the throwaway voice-capture spike (ADR 0002).
#
# No real microphone is opened. A stub pw-cli/pw-record pair exercises the
# start/stop path, the temp-file cleanup, and the opt-in gate. The suite also
# asserts that the test itself never leaves audio in the checkout.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script="$root/tools/voice-capture-spike.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

if [ ! -x "$script" ]; then
    bad "capture spike is executable"
    printf '\n%d passed, %d failed\n' "$pass" "$fail"
    exit 1
fi
ok "capture spike is executable"

if bash -n "$script" 2>"$tmp/syntax.err"; then
    ok "capture spike parses"
else
    bad "capture spike parses" "$(cat "$tmp/syntax.err")"
fi

help=$("$script" --help 2>&1)
if printf '%s' "$help" | grep -q -- '--i-understand-this-records-audio' &&
    printf '%s' "$help" | grep -qi 'never upload'; then
    ok "help names the opt-in and the no-upload rule"
else
    bad "help names the opt-in and the no-upload rule" "$help"
fi

if printf '%s' "$help" | grep -qiE 'http://|https://|curl|wget'; then
    bad "help makes no network promise it cannot keep" "$help"
else
    ok "help has no network endpoint"
fi

# The capture code itself must not contain an upload path.
if grep -nE '\b(curl|wget|nc|ncat|socat|ssh|scp|rsync)\b|https?://' "$script" >"$tmp/network.txt"; then
    bad "capture spike has no upload command" "$(cat "$tmp/network.txt")"
else
    ok "capture spike has no upload command"
fi

# Refusing without the explicit opt-in is the most important guarantee.
mkdir -p "$tmp/bin" "$tmp/capture-tmp"
cat >"$tmp/bin/pw-cli" <<'SH'
#!/bin/sh
exit "${PW_CLI_STATUS:-0}"
SH
cat >"$tmp/bin/pw-record" <<'SH'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >>"${PW_RECORD_LOG:-/dev/null}"
out=
samples=0
while [ $# -gt 0 ]; do
    case "$1" in
        --sample-count)
            samples=$2
            shift 2
            ;;
        --target|--rate|--channels|--format)
            shift 2
            ;;
        --raw)
            shift
            ;;
        -*)
            shift
            ;;
        *)
            out=$1
            shift
            ;;
    esac
done
[ -n "$out" ] || exit 2
[ "$samples" -gt 0 ] || samples=16000
python3 - "$out" "$samples" <<'PY'
import math
import struct
import sys

path, count = sys.argv[1], int(sys.argv[2])
with open(path, "wb") as handle:
    for index in range(count):
        value = int(8000 * math.sin(2 * math.pi * 440 * index / 16000))
        handle.write(struct.pack("<h", value))
PY
SH
chmod +x "$tmp/bin/pw-cli" "$tmp/bin/pw-record"

export PATH="$tmp/bin:$PATH"
export TMPDIR="$tmp/capture-tmp"

record_log="$tmp/record.log"
: >"$record_log"
export PW_RECORD_LOG="$record_log"

out=$(timeout 10 "$script" 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qi 'refusing to open'; then
    ok "refuses to record without explicit consent"
else
    bad "refuses to record without explicit consent" "exit $status: $out"
fi
if [ -s "$record_log" ]; then
    bad "no recorder runs without consent" "$(cat "$record_log")"
else
    ok "no recorder runs without consent"
fi

out=$(printf '\n' | timeout 10 "$script" --i-understand-this-records-audio --duration 0 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qi 'between 1 and'; then
    ok "rejects an out-of-range duration"
else
    bad "rejects an out-of-range duration" "exit $status: $out"
fi

# A reachable PipeWire is required. The stub makes it unreachable.
: >"$record_log"
out=$(printf '\n' | PW_CLI_STATUS=1 timeout 10 "$script" --i-understand-this-records-audio 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qi 'not reachable'; then
    ok "fails closed when PipeWire is unreachable"
else
    bad "fails closed when PipeWire is unreachable" "exit $status: $out"
fi
if [ -s "$record_log" ]; then
    bad "does not open the recorder when PipeWire is unreachable" "$(cat "$record_log")"
else
    ok "does not open the recorder when PipeWire is unreachable"
fi

# Full start/stop path with a stubbed PipeWire capture.
: >"$record_log"
out=$(set +o pipefail; { printf '\n'; sleep 0.3; printf '\n'; } | timeout 10 "$script" --i-understand-this-records-audio --duration 1 2>&1)
status=$?
if [ "$status" -eq 0 ] &&
    printf '%s' "$out" | grep -q 'captured ' &&
    printf '%s' "$out" | grep -q 'audio deleted'; then
    ok "captures, reports levels, and deletes the temp audio"
else
    bad "captures, reports levels, and deletes the temp audio" "exit $status: $out"
fi
if [ -s "$record_log" ] && grep -q -- '--raw' "$record_log" && grep -q -- '--sample-count 16000' "$record_log"; then
    ok "capture uses PipeWire raw 16 kHz mono with a hard sample cap"
else
    bad "capture uses PipeWire raw 16 kHz mono with a hard sample cap" "$(cat "$record_log")"
fi
if find "$tmp/capture-tmp" -type f -print -quit | grep -q .; then
    bad "temporary audio is removed after the run" "$(find "$tmp/capture-tmp" -type f -print)"
else
    ok "temporary audio is removed after the run"
fi

# The repository must not carry an audio sample, and the test must not add one.
if git -C "$root" ls-files | grep -Ei '\.(wav|flac|ogg|opus|mp3|m4a|aac|raw)$' >"$tmp/tracked-audio.txt"; then
    bad "no audio samples are tracked" "$(cat "$tmp/tracked-audio.txt")"
else
    ok "no audio samples are tracked"
fi
if git -C "$root" status --porcelain | grep -Ei '\.(wav|flac|ogg|opus|mp3|m4a|aac|raw)$' >"$tmp/untracked-audio.txt"; then
    bad "the test leaves no untracked audio" "$(cat "$tmp/untracked-audio.txt")"
else
    ok "the test leaves no untracked audio"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
