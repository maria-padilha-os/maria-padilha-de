#!/usr/bin/env bash
# Contract tests for padilha-shot and padilha-record. Neither needs a live
# session: --dry-run prints the exact commands they would execute.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
shot="$root/bin/padilha-shot"
record="$root/bin/padilha-record"

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
contains() { # name output needle
    if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1" "$2"; fi
}

echo "syntax and usage"

for f in "$shot" "$record"; do
    if sh -n "$f"; then ok "sh -n $(basename "$f")"; else bad "sh -n $(basename "$f")"; fi
    if "$f" -h > /dev/null 2>&1; then ok "$(basename "$f") -h exits 0"; else bad "$(basename "$f") -h exits 0"; fi
    if "$f" --nonsense > /dev/null 2>&1; then bad "$(basename "$f") refuses unknown flags"; else
        [ $? -eq 2 ] && ok "$(basename "$f") refuses unknown flags" || bad "$(basename "$f") exits 2"
    fi
done

echo "screenshot"

out=$("$shot" --dry-run 2>&1)
contains "full shot uses grim" "$out" "grim"
contains "full shot copies to the clipboard" "$out" "wl-copy"
contains "full shot saves a file" "$out" ".png"

out=$("$shot" -r --dry-run 2>&1)
contains "region shot goes through the picker" "$out" "ipc call picker open"

echo "recording"

out=$("$record" --dry-run 2>&1)
contains "record starts gpu-screen-recorder" "$out" "gpu-screen-recorder"
contains "record writes the state path" "$out" "caelestia/record/recording.mp4"

out=$("$record" -r --dry-run 2>&1)
contains "region recording asks slurp" "$out" "slurp"
contains "region recording passes -region" "$out" "-region"

out=$("$record" -s --dry-run 2>&1)
contains "sound recording adds the output" "$out" "-a default_output"

out=$("$record" -p --dry-run 2>&1)
contains "pause signals the recorder" "$out" "pkill -USR2"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
