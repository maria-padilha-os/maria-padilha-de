#!/usr/bin/env bash
# Extension contract tests: parse the manifests, lint and instantiate every
# tab, verify shortcut names are unique, and audit the extensions that keep
# local state so they only write under ~/.local/share/padilha.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "manifests, shortcuts and state"

if /usr/bin/python3 "$root/tests/extensions/check.py" "$root"; then
    ok "extension contract checker"
else
    bad "extension contract checker"
fi

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
    if "$qmllint" -I /usr/lib/qt6/qml "${qml_files[@]}" > "$tmp/qmllint.log" 2>&1; then
        ok "qmllint accepts every extension file"
    else
        bad "qmllint accepts every extension file" "$(tail -8 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

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
elif [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ]; then
    printf '  skip %s\n' "Quickshell is not installed"
else
    mkdir -p "$tmp/runtime" "$tmp/data"
    chmod 700 "$tmp/runtime"
    export QT_QPA_PLATFORM=offscreen
    export XDG_RUNTIME_DIR="$tmp/runtime"
    export XDG_DATA_HOME="$tmp/data"
    export PADILHA_EXTENSION_TABS
    PADILHA_EXTENSION_TABS=$(printf '%s\n' "${tabs[@]}")
    if timeout 120 "$qs_bin" -p "$root/tests/extensions/load_tabs.qml" > "$tmp/qmltest.log" 2>&1; then
        ok "instantiated ${#tabs[@]} extension tabs"
    else
        bad "instantiated ${#tabs[@]} extension tabs" "$(tail -20 "$tmp/qmltest.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
