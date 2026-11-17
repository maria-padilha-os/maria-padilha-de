#!/usr/bin/env bash
# Contract tests for padilha-shot, padilha-record and padilha-capture.
#
# No screen is captured and no recorder is started: the tests either use
# --dry-run or stub grim/wf-recorder/slurp/hyprctl with scripts that only log
# their arguments. That keeps CI headless while still checking the real
# argument construction, the timestamped filenames and the safety rules.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
shot="$root/bin/padilha-shot"
record="$root/bin/padilha-record"
capture="$root/bin/padilha-capture"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
contains() { # name output needle
    if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1" "$2"; fi
}
absent() { # name output needle
    if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1" "$2"; else ok "$1"; fi
}
matches() { # name output regex
    if printf '%s' "$2" | grep -qE -- "$3"; then ok "$1"; else bad "$1" "$2"; fi
}
status_is() { # name expected actual
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected $2, got $3"; fi
}

mkdir -p "$tmp/bin"
cat >"$tmp/bin/hyprctl" <<'SH'
#!/bin/sh
case "$*" in
    *monitors*)
        printf '%s\n' '[{"name":"eDP-1","focused":true,"refreshRate":60.0}]'
        ;;
    *activeworkspace*)
        printf '{"id":%s,"name":"%s"}\n' "${FAKE_WS_ID:-1}" "${FAKE_WS:-capture}"
        ;;
    *activewindow*)
        if [ -n "${FAKE_WINDOW:-}" ]; then
            printf '%s\n' "$FAKE_WINDOW"
        else
            printf '%s\n' '{}'
        fi
        ;;
esac
SH
cat >"$tmp/bin/grim" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"${GRIM_LOG:-/dev/null}"
for last; do :; done
printf 'stub png\n' >"$last"
SH
cat >"$tmp/bin/wf-recorder" <<'PY'
#!/usr/bin/env python3
import os
import signal
import sys
import time

log = os.environ.get("WF_LOG", "/dev/null")
out = ""
previous = ""
for arg in sys.argv[1:]:
    if previous == "-f":
        out = arg
    previous = arg
with open(log, "a") as handle:
    handle.write(" ".join(sys.argv[1:]) + "\n")

def stop(*_):
    if out:
        with open(out, "w") as handle:
            handle.write("stub recording\n")
    sys.exit(0)

signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
while True:
    time.sleep(0.2)
PY
cat >"$tmp/bin/slurp" <<'SH'
#!/bin/sh
if [ -n "${SLURP_GEOMETRY:-}" ]; then
    printf '%s\n' "$SLURP_GEOMETRY"
else
    exit 1
fi
SH
chmod +x "$tmp/bin/hyprctl" "$tmp/bin/grim" "$tmp/bin/wf-recorder" "$tmp/bin/slurp"
fake_path="$tmp/bin:$PATH"
now=20260101-010203
mkdir -p "$tmp/config-default" "$tmp/state"
export XDG_CONFIG_HOME="$tmp/config-default"
export XDG_STATE_HOME="$tmp/state"
unset PADILHA_SCREENSHOT_DIR PADILHA_RECORDINGS_DIR PADILHA_RECORD_DIR PADILHA_CAPTURE_DIR PADILHA_CAPTURE_NOW

run_shot() { PATH="$fake_path" PADILHA_CAPTURE_NOW="$now" "$shot" "$@"; }
run_record() { PATH="$fake_path" PADILHA_CAPTURE_NOW="$now" "$record" "$@"; }

echo "syntax and usage"

for f in "$shot" "$record" "$capture"; do
    if sh -n "$f"; then ok "sh -n $(basename "$f")"; else bad "sh -n $(basename "$f")"; fi
done
for f in "$shot" "$record"; do
    if "$f" -h >/dev/null 2>&1; then ok "$(basename "$f") -h exits 0"; else bad "$(basename "$f") -h exits 0"; fi
    "$f" --nonsense >/dev/null 2>&1
    status=$?
    status_is "$(basename "$f") refuses unknown flags" 2 "$status"
done
"$capture" >/dev/null 2>&1
status_is "padilha-capture without a command exits 2" 2 "$?"

shot_help=$("$shot" --help 2>&1)
record_help=$("$record" --help 2>&1)
contains "shot help names full screen" "$shot_help" "full"
contains "shot help names focused window" "$shot_help" "window"
contains "shot help names region" "$shot_help" "region"
contains "shot help says copy is opt-in" "$shot_help" "Nothing is copied unless --copy"
contains "shot help names grim" "$shot_help" "grim"
contains "record help names wf-recorder" "$record_help" "wf-recorder"
contains "record help has explicit start" "$record_help" "--start"
contains "record help has explicit stop" "$record_help" "--stop"
contains "record help has countdown" "$record_help" "--countdown"

echo "screenshot arguments"

out=$(run_shot --dry-run 2>&1)
contains "full shot targets the focused monitor" "$out" "grim -o eDP-1"
matches "full shot saves a timestamped PNG" "$out" 'screenshot-[0-9]{8}-[0-9]{6}\.png'
absent "full shot does not copy by default" "$out" "wl-copy"
contains "full shot uses the Pictures folder" "$out" "Pictures/Screenshots"

out=$(run_shot --copy --dry-run 2>&1)
contains "an explicit copy uses wl-copy" "$out" "wl-copy --type image/png"

out=$(FAKE_WINDOW='{"at":[10,20],"size":[640,480]}' run_shot --mode window --dry-run 2>&1)
contains "window shot uses the focused window geometry" "$out" "grim -g 640x480+10+20"

out=$(run_shot --region --dry-run 2>&1)
contains "region shot asks slurp" "$out" "slurp -f"
contains "region shot uses grim -g" "$out" "grim -g"
absent "region shot does not copy by default" "$out" "wl-copy"

out=$(run_shot --countdown 3 --dry-run 2>&1)
contains "shot countdown waits first" "$out" "sleep 3"
out=$(run_shot --countdown nope --dry-run 2>&1)
status=$?
status_is "shot rejects a non-numeric countdown" 2 "$status"
contains "shot explains a bad countdown" "$out" "whole number"

out=$(PADILHA_SCREENSHOT_DIR="$tmp/shots with space" run_shot --dry-run 2>&1)
contains "shot honours the configured folder" "$out" "$tmp/shots with space/screenshot-"

mkdir -p "$tmp/config/padilha"
printf '{"utilities":{"capture":{"screenshotDir":"%s"}}}\n' "$tmp/from-config" >"$tmp/config/padilha/shell.json"
out=$(env -u PADILHA_SCREENSHOT_DIR XDG_CONFIG_HOME="$tmp/config" PATH="$fake_path" PADILHA_CAPTURE_NOW="$now" "$shot" --dry-run 2>&1)
contains "shot reads the configured screenshot directory" "$out" "$tmp/from-config/screenshot-"

echo "recording arguments"

out=$(run_record --start --dry-run 2>&1)
contains "recording starts wf-recorder" "$out" "wf-recorder"
absent "recording never uses gpu-screen-recorder" "$out" "gpu-screen-recorder"
contains "recording targets the focused monitor" "$out" "-o eDP-1"
matches "recording saves a timestamped MP4" "$out" 'recording-[0-9]{8}-[0-9]{6}\.mp4'
contains "recording uses the Videos folder" "$out" "Videos/Recordings"
absent "recording has no clipboard work" "$out" "wl-copy"

out=$(run_record start --region --dry-run 2>&1)
contains "region recording asks slurp" "$out" "slurp"
contains "region recording passes wf-recorder -g" "$out" "-g REGION"

out=$(FAKE_WINDOW='{"at":[10,20],"size":[640,480]}' run_record start --mode window --dry-run 2>&1)
contains "window recording uses the focused window geometry" "$out" "10,20 640x480"

out=$(run_record start --sound --dry-run 2>&1)
contains "sound recording includes the audio source" "$out" " -a "

out=$(run_record --stop --dry-run 2>&1)
contains "explicit stop interrupts the recorder" "$out" "kill -INT"
out=$(run_record --pause --dry-run 2>&1)
contains "pause stops the recorder process" "$out" "kill -STOP"

out=$(run_record --status 2>&1)
status=$?
status_is "status is available without capture" 0 "$status"
contains "status reports a state" "$out" "idle"

out=$(PADILHA_RECORDINGS_DIR="$tmp/videos with space" run_record --start --dry-run 2>&1)
contains "recording honours the configured folder" "$out" "$tmp/videos with space/recording-"

# A stub recorder exercises the explicit start/stop state machine without
# touching a real screen: it only writes its output file when it gets SIGINT.
mkdir -p "$tmp/records"
record_dir=$tmp/records
out=$(PADILHA_RECORDINGS_DIR="$record_dir" WF_LOG="$tmp/wf.log" run_record --start --mode full 2>&1)
status=$?
status_is "explicit start returns success" 0 "$status"
out=$(PADILHA_RECORDINGS_DIR="$record_dir" run_record --status 2>&1)
contains "status sees the running stub recorder" "$out" "recording"
out=$(PADILHA_RECORDINGS_DIR="$record_dir" run_record --stop 2>&1)
status=$?
status_is "explicit stop returns success" 0 "$status"
contains "stop reports the saved file" "$out" "Saved"
if find "$record_dir" -type f -name 'recording-*.mp4' -print -quit | grep -q .; then
    ok "the stub recorder wrote the timestamped file"
else
    bad "the stub recorder wrote the timestamped file" "$out"
fi
out=$(PADILHA_RECORDINGS_DIR="$record_dir" run_record --status 2>&1)
contains "status returns to idle after stop" "$out" "idle"

out=$(run_record --mode nonsense --dry-run 2>&1)
status=$?
status_is "recording rejects an unknown mode" 2 "$status"
out=$(run_record --sound --start --dry-run 2>&1)
status=$?
status_is "recording accepts a start action before options" 0 "$status"

echo "missing tools"

mkdir -p "$tmp/empty"
out=$(PATH="$tmp/empty" PADILHA_CAPTURE_NOW="$now" PADILHA_SCREENSHOT_DIR="$tmp/missing" "$shot" 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "grim is not installed"; then
    ok "shot fails clearly when grim is missing"
else
    bad "shot fails clearly when grim is missing" "exit $status: $out"
fi
out=$(PATH="$tmp/empty" PADILHA_CAPTURE_NOW="$now" PADILHA_RECORDINGS_DIR="$tmp/missing" "$record" --start 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "wf-recorder is not installed"; then
    ok "record fails clearly when wf-recorder is missing"
else
    bad "record fails clearly when wf-recorder is missing" "exit $status: $out"
fi

echo "filename safety"

unsafe_dir="$tmp/out dir; touch $tmp/pwned"
out=$(PATH="$fake_path" GRIM_LOG="$tmp/grim.log" PADILHA_CAPTURE_NOW="$now" \
    PADILHA_SCREENSHOT_DIR="$unsafe_dir" "$shot" --mode full 2>&1)
status=$?
status_is "a directory with shell metacharacters still works" 0 "$status"
if [ -s "$unsafe_dir/screenshot-$now.png" ]; then
    ok "the screenshot lands inside the configured directory"
else
    bad "the screenshot lands inside the configured directory" "$out"
fi
if [ -e "$tmp/pwned" ]; then bad "the configured path cannot inject a command"; else ok "the configured path cannot inject a command"; fi

out=$(PATH="$fake_path" GRIM_LOG="$tmp/grim.log" PADILHA_CAPTURE_NOW="$now" \
    PADILHA_SCREENSHOT_DIR="$unsafe_dir" "$shot" 2>&1)
if [ -s "$unsafe_dir/screenshot-$now-2.png" ] && [ -s "$unsafe_dir/screenshot-$now.png" ]; then
    ok "an existing timestamp gets a safe numeric suffix"
else
    bad "an existing timestamp gets a safe numeric suffix" "$out"
fi

out=$(PATH="$fake_path" PADILHA_CAPTURE_NOW='../../escape' PADILHA_SCREENSHOT_DIR="$tmp/shots" "$shot" 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "PADILHA_CAPTURE_NOW"; then
    ok "an unsafe timestamp override is rejected"
else
    bad "an unsafe timestamp override is rejected" "exit $status: $out"
fi
out=$(PATH="$fake_path" PADILHA_CAPTURE_NOW='2026/01/01' PADILHA_SCREENSHOT_DIR="$tmp/shots" "$shot" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then ok "a slash in the timestamp override is rejected"; else bad "a slash in the timestamp override is rejected" "$out"; fi

echo "capture workspace"

out=$(FAKE_WS=3 run_shot --dry-run 2>&1)
contains "an ordinary workspace produces a warning" "$out" "not the dedicated capture workspace"
out=$(FAKE_WS='capture-1' run_shot --dry-run 2>&1)
absent "a capture workspace does not warn" "$out" "not the dedicated capture workspace"
out=$(FAKE_WS=work run_shot --workspace work --dry-run 2>&1)
absent "the configured workspace name does not warn" "$out" "not the dedicated capture workspace"
FAKE_WS=3 run_shot --strict-workspace --dry-run >/dev/null 2>&1
status=$?
status_is "strict workspace mode refuses an ordinary workspace" 3 "$status"

echo "privacy contract"

if grep -nE '\b(curl|wget|nc|ncat|socat|ssh|scp|rsync)\b|https?://' \
    "$root/bin/padilha-capture" "$shot" "$record" >"$tmp/network.txt"; then
    bad "capture commands have no upload path" "$(cat "$tmp/network.txt")"
else
    ok "capture commands have no upload path"
fi
if grep -qF 'gpu-screen-recorder' "$root/bin/padilha-capture"; then
    bad "the recorder is wf-recorder only"
else
    ok "the recorder is wf-recorder only"
fi
if grep -qF 'wf-recorder' "$root/bin/padilha-capture" &&
    grep -qF 'grim' "$root/bin/padilha-capture"; then
    ok "the capture commands use grim and wf-recorder"
else
    bad "the capture commands use grim and wf-recorder"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
