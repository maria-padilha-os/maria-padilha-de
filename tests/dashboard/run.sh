#!/usr/bin/env bash
# Built-in dashboard contract: parse every panel and keep the tab strip from
# clipping labels or letting a panel collapse below its own minimum.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "stable layout contract"
if /usr/bin/python3 "$root/tests/dashboard/check.py" "$root"; then
    ok "dashboard layout contract"
else
    bad "dashboard layout contract"
fi

echo "QML syntax"
qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    failed=()
    while IFS= read -r -d '' file; do
        if ! "$qmllint" -I /usr/lib/qt6/qml "$file" > /dev/null 2>&1; then
            failed+=("$file")
        fi
    done < <(find "$root/shell/modules/dashboard" "$root/shell/modules/bar" -type f -name '*.qml' -print0 | sort -z)
    if [ ${#failed[@]} -eq 0 ]; then
        ok "qmllint accepts every dashboard and bar file"
    else
        bad "qmllint accepts every dashboard and bar file" "${failed[0]}"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
