#!/usr/bin/env bash
# Update manager contract: pure parsing/warning tests, static confirmation
# promises, packaging and QML syntax. No pacman or policy agent is started.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

echo "parsing, summaries and confirmation"

lua_bin=$(command -v lua || true)
if [ -z "$lua_bin" ]; then
    printf '  skip %s\n' "Lua is not installed"
elif PADILHA_ROOT="$root" "$lua_bin" "$root/tests/updates/updates.test.lua" > "$tmp/updates.log" 2>&1; then
    ok "lib/updates.lua parses query/info output and refuses unconfirmed apply"
else
    bad "lib/updates.lua parses query/info output and refuses unconfirmed apply" "$(tail -40 "$tmp/updates.log")"
fi

echo "explicit UI contract"

page="$root/shell/modules/nexus/pages/UpdatesPage.qml"
service="$root/shell/services/Updates.qml"
check "the page shows versions and both sizes" "grep -q 'oldVersion' '$page' && grep -q 'sizeText' '$page'"
check "the page has a separate confirmation action" "grep -q 'Review and apply' '$page' && grep -q 'Confirm update' '$page'"
check "the page cancels without applying" "grep -q 'function cancelApply' '$page' && grep -q 'root.cancelApply()' '$page'"
check "the service only applies when called with true" "grep -q 'function apply(confirmed: bool)' '$service' && grep -q 'confirmed !== true' '$service'"
check "the service passes --yes only after UI confirmation" "grep -q 'apply\", \"--yes\", \"--json\"' '$service'"
check "the page shows failures and copies the log path" "grep -q 'Update failed' '$page' && grep -q 'Copy log path' '$page' && grep -q 'Quickshell.clipboardText' '$page'"
check "the page warns about low battery and battery-powered large updates" "grep -q 'battery-low' '$page' && grep -q 'not-on-ac-large' '$page'"
check "the page says updates and reboots are never automatic" "grep -q 'never updates or reboots on its own' '$page'"
check "there is no update timer or automatic apply in the service" "! grep -qE '(^|[^A-Za-z])Timer[[:space:]]*\\{' '$service' && ! grep -q 'apply(true)' '$service'"

echo "packaging"

check "the update command is installed" "grep -q 'padilha-update' '$root/install.sh'"
check "the update command is packaged" "grep -q 'padilha-update' '$root/packaging/PKGBUILD'"
check "the compatibility alias is present" "[ -L '$root/bin/lilith-update' ] && [ \"\$(readlink '$root/bin/lilith-update')\" = 'padilha-update' ]"

echo "QML syntax"

qmllint=/usr/lib/qt6/bin/qmllint
if [ ! -x "$qmllint" ]; then
    qmllint=$(command -v qmllint || true)
fi
if [ -n "$qmllint" ] && [ -x "$qmllint" ]; then
    lint_failed=()
    for file in "$service" "$page"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml -I "$root/shell" "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the update service and page"
    else
        bad "qmllint accepts the update service and page" "${lint_failed[0]}: $(tail -8 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
