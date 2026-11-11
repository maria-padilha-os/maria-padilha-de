#!/usr/bin/env bash
# Throwaway microphone-capture spike for ADR 0002.
#
# This is not installed, not imported by the shell, and not wired to a keybind.
# It records only after an explicit --i-understand flag *and* an Enter press.
# Audio stays in a temporary directory, is analysed locally, and is deleted on
# exit. There is no upload path, no background listener, and no audio sample in
# the checkout.

set -euo pipefail
umask 077

max_allowed=30
duration=10
target=
understood=false

usage() {
    cat <<'EOF'
Usage: voice-capture-spike.sh --i-understand-this-records-audio [options]

Options:
  --i-understand-this-records-audio
                       Required. Confirms that you know this opens the
                       microphone. Without it the script refuses to record.
  --duration SECONDS   Hard maximum, 1-30 seconds (default: 10).
  --target NAME        Optional PipeWire source node name or serial.
  -h, --help           Show this help and exit.

Flow: press Enter to start, speak, press Enter again to stop. The recording
also stops at --duration. The temporary raw file is deleted before exit.

This script never uploads audio and never writes outside its temporary
directory. It refuses to run when PipeWire is not reachable.
EOF
}

die() {
    printf 'voice-capture-spike: %s\n' "$*" >&2
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --i-understand-this-records-audio)
            understood=true
            shift
            ;;
        --duration)
            [ $# -ge 2 ] || die "--duration needs a value"
            duration=$2
            shift 2
            ;;
        --target)
            [ $# -ge 2 ] || die "--target needs a value"
            target=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1 (try --help)"
            ;;
    esac
done

if [ "$understood" != true ]; then
    cat >&2 <<'EOF'
voice-capture-spike: refusing to open the microphone.

This is an opt-in capture test. Re-run with:

  tools/voice-capture-spike.sh --i-understand-this-records-audio

It records only after you press Enter, keeps the audio in a temporary file,
analyses it locally, and deletes it on exit. Nothing is uploaded.
EOF
    exit 2
fi

case "$duration" in
    ''|*[!0-9]*) die "--duration must be a whole number of seconds" ;;
esac
if [ "$duration" -lt 1 ] || [ "$duration" -gt "$max_allowed" ]; then
    die "--duration must be between 1 and $max_allowed seconds"
fi

command -v pw-record >/dev/null 2>&1 || die "pw-record is not installed"
command -v pw-cli >/dev/null 2>&1 || die "pw-cli is not installed (PipeWire tools)"
command -v python3 >/dev/null 2>&1 || die "python3 is not installed"

# Connect before recording. A stale or absent session should fail closed.
if ! timeout 5 pw-cli info 0 >/dev/null 2>&1; then
    cat >&2 <<'EOF'
voice-capture-spike: PipeWire is not reachable; refusing to record.

Start a PipeWire session and check that `pw-cli info 0` succeeds, then retry.
No microphone was opened.
EOF
    exit 2
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/padilha-voice-spike.XXXXXX")
chmod 700 "$tmp"
raw="$tmp/capture.s16"
rec_pid=

cleanup() {
    trap - EXIT INT TERM
    if [ -n "$rec_pid" ] && kill -0 "$rec_pid" 2>/dev/null; then
        kill -INT "$rec_pid" 2>/dev/null || true
        wait "$rec_pid" 2>/dev/null || true
    fi
    rm -rf -- "$tmp"
}

on_signal() {
    cleanup
    exit 130
}

trap cleanup EXIT
trap on_signal INT TERM

cat <<EOF
Offline voice capture spike (temporary)
  max duration: ${duration}s
  audio file:   $raw (deleted on exit)
  uploads:      none
  background:   none; the recorder runs only after Enter below

Press Enter to start. Ctrl-C cancels without recording.
EOF
if ! read -r _; then
    die "no start confirmation; nothing was recorded"
fi

samples=$((duration * 16000))
args=(--raw --rate 16000 --channels 1 --format s16 --sample-count "$samples")
if [ -n "$target" ]; then
    args+=(--target "$target")
fi

printf 'Recording. Press Enter to stop; it also stops after %ss.\n' "$duration"
pw-record "${args[@]}" "$raw" &
rec_pid=$!

# Wait for Enter or the recorder's own sample-count exit. A read timeout is
# expected; EOF (for example when stdin is a pipe) stops the capture too.
while kill -0 "$rec_pid" 2>/dev/null; do
    if read -r -t 0.2 _; then
        printf 'Stopping.\n'
        kill -INT "$rec_pid" 2>/dev/null || true
        break
    else
        read_status=$?
        if [ "$read_status" -le 128 ]; then
            kill -INT "$rec_pid" 2>/dev/null || true
            break
        fi
    fi
done
wait "$rec_pid" 2>/dev/null || true
rec_pid=

if [ ! -s "$raw" ]; then
    die "capture produced no audio; check the microphone source and try --target"
fi

python3 - "$raw" <<'PY'
import array
import math
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    data = handle.read()

count = len(data) // 2
if count == 0:
    print("captured 0 samples", file=sys.stderr)
    raise SystemExit(3)

samples = array.array("h")
samples.frombytes(data[: count * 2])
if sys.byteorder != "little":
    samples.byteswap()

peak = max(abs(value) for value in samples) / 32768.0
rms = math.sqrt(sum(value * value for value in samples) / count) / 32768.0


def dbfs(value):
    return -999.0 if value <= 0 else 20.0 * math.log10(value)


print(f"captured {count / 16000:.2f}s at 16 kHz mono")
print(f"peak {dbfs(peak):.1f} dBFS, rms {dbfs(rms):.1f} dBFS")
if peak <= 0:
    print("warning: every sample is zero; check the selected source", file=sys.stderr)
PY

rm -f -- "$raw"
printf 'audio deleted; no sample leaves %s\n' "$tmp"
