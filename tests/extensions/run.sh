#!/usr/bin/env bash
# Extension contract tests: parse the manifests, check ids/shortcuts/tab URLs,
# wire up the settings text, audit light/dark palette usage, lint every tab and
# instantiate them when the Quickshell runtime is available.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "manifests, shortcuts and colours"

if /usr/bin/python3 "$root/tests/extensions/check.py" "$root"; then
    ok "extension contract checker"
else
    bad "extension contract checker"
fi

echo "QML syntax"

qml_files=()
while IFS= read -r -d '' file; do
    qml_files+=("$file")
done < <(find "$root/extensions" "$root/share/extensions" -type f -name '*.qml' -print0 2>/dev/null | sort -z)

if [ ${#qml_files[@]} -eq 0 ]; then
    bad "found extension QML files"
else
    ok "found ${#qml_files[@]} extension QML files"
fi

qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "${qml_files[@]}"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts every extension file"
    else
        bad "qmllint accepts every extension file" "${lint_failed[0]}: $(tail -4 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "tabs load"

tabs=()
while IFS= read -r tab; do
    [ -n "$tab" ] && tabs+=("$tab")
done < <(/usr/bin/python3 - "$root" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
for base in (root / "extensions", root / "share" / "extensions"):
    if not base.is_dir():
        continue
    for manifest in sorted(base.glob("*/extension.json")):
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
        tab = data.get("tab") if isinstance(data, dict) else None
        if isinstance(tab, str) and tab:
            print(manifest.parent / tab)
PY
)

qs_bin=$(command -v qs || true)
if [ ${#tabs[@]} -eq 0 ]; then
    bad "found a tab for every extension"
elif [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
    printf '  skip %s\n' "Quickshell or the Caelestia plugin is not installed"
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
    export PADILHA_EXTENSION_TABS
    PADILHA_EXTENSION_TABS=$(printf '%s\n' "${tabs[@]}")
    if timeout 90 "$qs_bin" -p "$root/tests/extensions/load_tabs.qml" > "$tmp/qmltest.log" 2>&1; then
        ok "instantiated ${#tabs[@]} extension tabs"
    else
        bad "instantiated ${#tabs[@]} extension tabs" "$(tail -20 "$tmp/qmltest.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
