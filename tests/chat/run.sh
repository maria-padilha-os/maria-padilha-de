#!/usr/bin/env bash
# Contract tests for the AI chat transcript. Static checks run everywhere; the
# optional live check only opens the drawer when PADILHA_CHAT_LIVE=1.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
contains() { grep -Fq -- "$2" "$1"; }

transcript="$root/shell/modules/assistant/Transcript.qml"
content="$root/shell/modules/assistant/Content.qml"
assistant="$root/shell/services/Assistant.qml"
backend="$root/bin/padilha-dsh"

for file in "$transcript" "$content" "$assistant" "$backend"; do
    [ -f "$file" ] || bad "missing $(basename "$file")"
done

contains "$transcript" 'ListView {' && ok 'transcript is a ListView' || bad 'transcript is a ListView'
contains "$transcript" 'cacheBuffer:' && ok 'transcript uses delegate caching' || bad 'transcript uses delegate caching'
contains "$transcript" 'Loader {' && ok 'rich code is lazy' || bad 'rich code is lazy'
contains "$transcript" 'expandRequested' && ok 'historical code expansion exists' || bad 'historical code expansion exists'
contains "$transcript" 'preserveIndex' && ok 'older-history scroll preservation exists' || bad 'older-history scroll preservation exists'
if contains "$transcript" 'Repeater {' || contains "$transcript" 'contentHeight: column.implicitHeight'; then
    bad 'transcript is not rebuilding every row'
else
    ok 'transcript is not rebuilding every row'
fi

contains "$backend" 'def history_page' && ok 'backend history is paginated' || bad 'backend history is paginated'
contains "$assistant" 'function loadOlder' && ok 'Assistant can request older messages' || bad 'Assistant can request older messages'
contains "$assistant" 'historyOlderLoaded' && ok 'older-load completion signal exists' || bad 'older-load completion signal exists'
contains "$assistant" 'function expandMessage' && ok 'Assistant can expand historical code' || bad 'Assistant can expand historical code'
if contains "$assistant" 'entries.slice(-8)'; then
    bad 'initial history is not truncated to eight rows'
else
    ok 'initial history is not truncated to eight rows'
fi

contains "$backend" 'def history_page' && ok 'backend exposes a history page' || bad 'backend exposes a history page'
contains "$backend" 'historyOlder' && ok 'backend emits older history pages' || bad 'backend emits older history pages'
contains "$backend" 'command == "older"' && ok 'backend accepts older-history requests' || bad 'backend accepts older-history requests'

contains "$content" 'loadOlderMessages' && ok 'Content wires the older-history button' || bad 'Content wires the older-history button'
contains "$content" 'onHistoryOlderLoaded' && ok 'Content restores position after prepending' || bad 'Content restores position after prepending'
contains "$content" 'onExpandRequested' && ok 'Content wires historical code expansion' || bad 'Content wires historical code expansion'

if [ "${PADILHA_CHAT_LIVE:-0}" = 1 ]; then
    if command -v qs >/dev/null 2>&1 && qs -c caelestia ipc show >/dev/null 2>&1; then
        was_open=$(qs -c caelestia ipc call drawers isOpen assistant 2>/dev/null || printf '0')
        start=$(date +%s%N)
        qs -c caelestia ipc call drawers open assistant >/dev/null 2>&1
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        if [ "$elapsed" -lt 1000 ]; then
            ok "drawer opens in ${elapsed}ms"
        else
            bad "drawer opens in ${elapsed}ms" 'expected <1000ms'
        fi
        if [ "$was_open" = "0" ]; then
            qs -c caelestia ipc call drawers close assistant >/dev/null 2>&1
        fi
    else
        ok 'live check skipped (qs unavailable)'
    fi
fi

printf '\n%d checks, %d failed\n' "$((pass + fail))" "$fail"
[ "$fail" -eq 0 ]
