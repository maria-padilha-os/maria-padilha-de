#!/usr/bin/env bash
# Media widget contract: pure metadata/transport tests, layout and palette
# checks, QML syntax, then a real Quickshell run against tests/media/fake_mpris.py
# on a private session bus. No audio, player process or network is used.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "metadata, artwork and transport helpers"

if /usr/bin/python3 "$root/tests/media/check.py" "$root"; then
    ok "media widget contract checker"
else
    bad "media widget contract checker"
fi

node_bin=$(command -v node || true)
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/media/MediaInfo.test.js" > "$tmp/media-info.log" 2>&1; then
    ok "MediaInfo.js fake-player unit tests"
else
    bad "MediaInfo.js fake-player unit tests" "$(tail -30 "$tmp/media-info.log")"
fi

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
media_qml=(
    "$root/shell/services/Players.qml"
    "$root/shell/components/widgets/MediaArtwork.qml"
    "$root/shell/modules/bar/components/Media.qml"
    "$root/shell/modules/bar/popouts/Media.qml"
    "$root/shell/modules/bar/Bar.qml"
    "$root/shell/modules/bar/popouts/Content.qml"
    "$root/shell/modules/dashboard/media/Details.qml"
    "$root/shell/modules/lock/Media.qml"
)
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "${media_qml[@]}"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the media service and widgets"
    else
        bad "qmllint accepts the media service and widgets" "${lint_failed[0]}: $(tail -8 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "fake MPRIS service"

qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -e /usr/lib/qt6/qml/Quickshell/Services/Mpris/quickshell-service-mpris.qmltypes ]; then
    printf '  skip %s\n' "Quickshell or its MPRIS module is not installed"
elif ! command -v dbus-run-session > /dev/null || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "a private D-Bus session or the Caelestia plugin is not available"
elif ! /usr/bin/python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio' > /dev/null 2>&1; then
    printf '  skip %s\n' "Python Gio bindings are not installed"
else
    mkdir -p "$tmp/home" "$tmp/config" "$tmp/data" "$tmp/state" "$tmp/cache" "$tmp/runtime"
    chmod 700 "$tmp/runtime"
    export HOME="$tmp/home"
    export XDG_CONFIG_HOME="$tmp/config"
    export XDG_DATA_HOME="$tmp/data"
    export XDG_STATE_HOME="$tmp/state"
    export XDG_CACHE_HOME="$tmp/cache"
    export XDG_RUNTIME_DIR="$tmp/runtime"
    export QT_QPA_PLATFORM=offscreen
    export PADILHA_MEDIA_TEST_ROOT="$root"
    export PADILHA_MEDIA_TEST_TMP="$tmp"
    export PADILHA_MEDIA_TEST_QS="$qs_bin"
    if dbus-run-session -- bash -c '
        set -uo pipefail
        python3 "$PADILHA_MEDIA_TEST_ROOT/tests/media/fake_mpris.py" \
            --state-file "$PADILHA_MEDIA_TEST_TMP/mpris-state.json" \
            --ready-file "$PADILHA_MEDIA_TEST_TMP/mpris-ready" \
            > "$PADILHA_MEDIA_TEST_TMP/mpris-service.log" 2>&1 &
        service=$!
        trap "kill $service 2>/dev/null || true" EXIT

        for _ in $(seq 1 100); do
            [ -f "$PADILHA_MEDIA_TEST_TMP/mpris-ready" ] && break
            sleep 0.05
        done
        if [ ! -f "$PADILHA_MEDIA_TEST_TMP/mpris-ready" ]; then
            echo "fake service did not start" >&2
            cat "$PADILHA_MEDIA_TEST_TMP/mpris-service.log" >&2
            exit 1
        fi

        timeout 40 "$PADILHA_MEDIA_TEST_QS" -p "$PADILHA_MEDIA_TEST_ROOT/tests/media/fake_service.qml" \
            > "$PADILHA_MEDIA_TEST_TMP/mpris-shell.log" 2>&1
    '; then
        if /usr/bin/python3 - "$tmp/mpris-state.json" <<'PY'
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
calls = state.get("calls", [])
required = (
    "org.mpris.MediaPlayer2.Player.Play",
    "org.mpris.MediaPlayer2.Player.Next",
    "org.mpris.MediaPlayer2.Player.Previous",
    "org.mpris.MediaPlayer2.Player.Seek",
    "org.mpris.MediaPlayer2.Player.Set.Volume",
    "org.mpris.MediaPlayer2.Player.Pause",
)
missing = [name for name in required if name not in calls]
assert not missing, f"missing calls: {missing} (got {calls})"
assert state["playbackStatus"] == "Paused", state["playbackStatus"]
assert state["title"] == "Fake Track 1", state["title"]
assert state["volume"] == 0.25, state["volume"]
PY
        then
            ok "Quickshell controls the fake MPRIS service without autoplay"
        else
            bad "Quickshell controls the fake MPRIS service without autoplay" "$(tail -20 "$tmp/mpris-shell.log")"
        fi
    else
        bad "Quickshell controls the fake MPRIS service without autoplay" "$(tail -20 "$tmp/mpris-shell.log" 2>/dev/null)"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
