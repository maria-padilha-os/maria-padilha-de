#!/usr/bin/env bash
# Nexus search and keyboard navigation contract: ranking, focus index
# transitions, static QML promises, QML loading and linting.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

echo "static search and focus contract"
if /usr/bin/python3 "$root/tests/nexus/check.py" "$root"; then
    ok "Nexus search and focus checker"
else
    bad "Nexus search and focus checker"
fi

echo "result ranking"
node_bin=$(command -v node || true)
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/nexus/ranking.test.js" > "$tmp/ranking.log" 2>&1; then
    ok "result ranking"
else
    bad "result ranking" "$(tail -20 "$tmp/ranking.log")"
fi

echo "focus transitions"
if [ -z "$node_bin" ]; then
    printf '  skip %s\n' "Node.js is not installed"
elif "$node_bin" "$root/tests/nexus/focus.test.js" > "$tmp/focus.log" 2>&1; then
    ok "focus transitions"
else
    bad "focus transitions" "$(tail -20 "$tmp/focus.log")"
fi

echo "QML syntax"
qmllint=/usr/lib/qt6/bin/qmllint
if [ -x "$qmllint" ]; then
    qml_files=(
        "$root/shell/components/FocusRing.qml"
        "$root/shell/components/controls/SearchBar.qml"
        "$root/shell/modules/nexus/SettingsSearch.qml"
        "$root/shell/modules/nexus/SettingsCatalog.qml"
        "$root/shell/modules/nexus/NexusState.qml"
        "$root/shell/modules/nexus/Nexus.qml"
        "$root/shell/modules/nexus/NavPane.qml"
        "$root/shell/modules/nexus/navpane/NavLocations.qml"
        "$root/shell/modules/nexus/Pages.qml"
        "$root/shell/modules/nexus/common/PageBase.qml"
        "$root/shell/modules/nexus/common/ToggleRow.qml"
        "$root/shell/modules/nexus/common/SelectRow.qml"
        "$root/shell/modules/nexus/common/SliderRow.qml"
        "$root/shell/modules/nexus/common/TextFieldRow.qml"
        "$root/shell/modules/nexus/common/StepperRow.qml"
        "$root/shell/modules/nexus/common/RowButton.qml"
        "$root/shell/modules/nexus/common/InfoRow.qml"
        "$root/shell/modules/nexus/common/PopupRow.qml"
    )
    lint_failed=()
    for file in "${qml_files[@]}"; do
        if ! "$qmllint" -I /usr/lib/qt6/qml -I "$root/shell" "$file" > "$tmp/qmllint.log" 2>&1; then
            lint_failed+=("$file")
        fi
    done
    if [ ${#lint_failed[@]} -eq 0 ]; then
        ok "qmllint accepts the search and navigation files"
    else
        bad "qmllint accepts the search and navigation files" "${lint_failed[0]}: $(tail -4 "$tmp/qmllint.log")"
    fi
else
    printf '  skip %s\n' "Qt 6 qmllint is not installed"
fi

echo "QML loading"
qs_bin=$(command -v qs || true)
if [ -z "$qs_bin" ] || [ ! -d /usr/lib/qt6/qml/Quickshell ] || [ ! -d /usr/lib/qt6/qml/Caelestia ]; then
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
    export PADILHA_NEXUS_FOCUS_RING="$root/shell/components/FocusRing.qml"
    mkdir -p "$tmp/load"
    cp "$root/tests/nexus/load.qml" "$tmp/load/load.qml"
    cp "$root/shell/modules/nexus/search/SearchRanking.js" "$root/shell/modules/nexus/search/FocusNavigation.js" "$tmp/load/"
    # FocusRing uses qs.services for the accessibility focus-ring width. Expose
    # just that singleton to this isolated harness without copying the tree.
    mkdir -p "$tmp/load/qs/services"
    cp "$root/shell/services/Accessibility.qml" "$tmp/load/qs/services/"
    printf 'module qs.services\nsingleton Accessibility 1.0 Accessibility.qml\n' > "$tmp/load/qs/services/qmldir"
    export QML2_IMPORT_PATH="$tmp/load${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
    if timeout 60 "$qs_bin" -p "$tmp/load/load.qml" > "$tmp/load.log" 2>&1; then
        ok "search modules and FocusRing load under Quickshell"
    else
        bad "search modules and FocusRing load under Quickshell" "$(tail -30 "$tmp/load.log")"
    fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
