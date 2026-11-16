#!/usr/bin/env bash
# Clipboard history contract: the bounded store, pause/clear, private entries,
# the local picker, and the failure message when a Wayland tool is missing.
# The daemon is exercised with fake wl-paste/hyprctl, so no live clipboard or
# compositor is touched.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
clipboard="$root/bin/padilha-clipboard"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

fake="$tmp/bin"
state="$tmp/state"
mkdir -p "$fake" "$state"

cat > "$fake/hyprctl" <<'SH'
#!/bin/sh
case ${1:-} in
    activewindow)
        printf 'Window 1 -> test\n\n\tclass: %s\n\ttitle: %s\n' "${ACTIVE_CLASS:-foot}" "${ACTIVE_TITLE:-terminal}"
        ;;
esac
SH

cat > "$fake/wl-paste" <<'SH'
#!/bin/sh
case ${1:-} in
    --list-types) printf 'text/plain;charset=utf-8\n' ;;
    --watch)
        shift
        printf 'daemon entry' | "$@"
        ;;
esac
SH

cat > "$fake/wl-copy" <<'SH'
#!/bin/sh
cat > "${WL_COPY_OUT:-/dev/null}"
SH

cat > "$fake/cliphist" <<'SH'
#!/bin/sh
case ${1:-} in
    list) printf '1\told entry\n' ;;
    decode) printf 'decoded:'; cat ;;
    delete) cat > "${CLIPHIST_DELETED:-/dev/null}" ;;
esac
SH

cat > "$fake/fuzzel" <<'SH'
#!/bin/sh
cat > "${FUZZEL_STDIN:-/dev/null}"
printf '%s\n' "$*" > "${FUZZEL_ARGS:-/dev/null}"
[ -n "${FUZZEL_PICK:-}" ] || exit 1
printf '%s\n' "$FUZZEL_PICK"
SH

cat > "$fake/nope" <<'SH'
#!/bin/sh
exit 1
SH

chmod +x "$fake"/*
export PATH="$fake:$PATH"

export PADILHA_CLIPBOARD_DIR="$state"
export PADILHA_CLIPBOARD_MAX=3
export PADILHA_CLIPBOARD_DELAY=5
export PADILHA_CLIPBOARD_MIME_TYPES=

record() {
    now=$1
    class=$2
    title=$3
    text=$4
    mime=${5:-$PADILHA_CLIPBOARD_MIME_TYPES}
    printf '%s' "$text" | env \
        PADILHA_CLIPBOARD_NOW="$now" \
        PADILHA_CLIPBOARD_ACTIVE_CLASS="$class" \
        PADILHA_CLIPBOARD_ACTIVE_TITLE="$title" \
        PADILHA_CLIPBOARD_DIR="$state" \
        PADILHA_CLIPBOARD_MAX="$PADILHA_CLIPBOARD_MAX" \
        PADILHA_CLIPBOARD_DELAY="$PADILHA_CLIPBOARD_DELAY" \
        PADILHA_CLIPBOARD_MIME_TYPES="$mime" \
        "$clipboard" --record
}

count() {
    [ -f "$state/history" ] || {
        printf '0'
        return
    }
    wc -l < "$state/history" | tr -d ' '
}

echo "opt-in config and QML widget contract"

check "clipboard is disabled by default" "grep -q 'CONFIG_PROPERTY(bool, enabled, false)' '$root/shell/plugin/src/Caelestia/Config/clipboardconfig.hpp'"
check "the store path is the user state directory" "grep -q 'padilha/clipboard' '$root/shell/services/ClipboardHistory.qml'"
check "the widget uses the shared palette" "grep -q 'Colours.palette' '$root/shell/modules/clipboard/ClipboardWindow.qml'"
check "the widget has an empty state" "grep -q 'clipboardEmpty' '$root/shell/modules/clipboard/ClipboardWindow.qml'"
check "the widget shows recording state and failures" "grep -q 'clipboardStatus' '$root/shell/modules/clipboard/ClipboardWindow.qml' && grep -q 'ClipboardHistory.error' '$root/shell/modules/clipboard/ClipboardWindow.qml'"
check "the widget is keyboard navigable" "grep -q 'Keys.onUpPressed' '$root/shell/modules/clipboard/ClipboardWindow.qml' && grep -q 'onAccepted' '$root/shell/modules/clipboard/ClipboardWindow.qml'"
check "the widget offers pause and clear all" "grep -q 'Pause history' '$root/shell/modules/clipboard/ClipboardWindow.qml' && grep -q 'Clear all' '$root/shell/modules/clipboard/ClipboardWindow.qml'"
check "the widget has no hard-coded palette hex values" "! grep -Eq '#[0-9a-fA-F]{3,8}' '$root/shell/modules/clipboard/ClipboardWindow.qml' '$root/shell/modules/clipboard/Clipboard.qml'"
for file in "$root/shell/services/ClipboardHistory.qml" "$root/shell/modules/clipboard/Clipboard.qml" "$root/shell/modules/clipboard/ClipboardWindow.qml"; do
    check "QML conventions: ${file##*/}" "/usr/bin/python3 '$root/shell/scripts/qml-lint-conventions.py' --file '$file' > /dev/null 2>&1"
done

echo "syntax, usage and permissions"

check "clipboard passes sh -n" "sh -n '$clipboard'"
check "clipboard is executable" "test -x '$clipboard'"

"$clipboard" -h > "$tmp/help" 2>&1
status=$?
check "-h exits 0" "[ $status -eq 0 ]" "exit $status"
check "-h names the pause and clear actions" "grep -q -- '--pause' '$tmp/help' && grep -q -- '--clear' '$tmp/help'"

"$clipboard" --nope > "$tmp/usage" 2>&1
status=$?
check "unknown flags exit 2" "[ $status -eq 2 ]" "exit $status"
check "unknown flags print usage" "grep -q 'usage' '$tmp/usage'"

echo "bounded trimming"

record 1000 foot terminal one
record 1001 foot terminal two
record 1002 foot terminal three
record 1003 foot terminal four
record 1004 foot terminal five

check "the history is bounded" "[ \$(count) -eq 3 ]" "count=$(count)"
"$clipboard" --list > "$tmp/list"
check "the oldest entry is trimmed" "! grep -q 'one' '$tmp/list'"
check "the newest entry survives" "grep -q 'five' '$tmp/list'"
check "the list is newest first" "[ \"\$(head -n 1 '$tmp/list' | cut -f 2)\" = five ]"

echo "round trip, unicode and removal"

record 1010 foot terminal "$(printf 'olá\nsecond line')"
id=$("$clipboard" --list | head -n 1 | cut -f 1)
check "get returns the stored text" "[ \"\$('$clipboard' --get '$id')\" = \"\$(printf 'olá\nsecond line')\" ]"
WL_COPY_OUT="$tmp/copied" "$clipboard" --copy "$id"
check "copy puts the stored text back" "cmp -s '$tmp/copied' <(printf 'olá\nsecond line')" "$(cat "$tmp/copied" 2>/dev/null)"
check "copying does not grow the history" "[ \$(count) -eq 3 ]"

"$clipboard" --remove "$id"
check "remove deletes one entry" "[ \$(count) -eq 2 ]"
check "remove deletes the right entry" "! '$clipboard' --list | grep -q 'second line'"

echo "pause and clear"

"$clipboard" --clear
check "clear empties the history" "[ \$(count) -eq 0 ]"
"$clipboard" --pause
record 1020 foot terminal while-paused
check "pause stops recording" "[ \$(count) -eq 0 ]"
"$clipboard" --status > "$tmp/status"
check "status says paused" "grep -q '^paused$' '$tmp/status'"
"$clipboard" --resume
record 1021 foot terminal after-resume
check "resume records again" "[ \$(count) -eq 1 ] && '$clipboard' --list | grep -q after-resume"
"$clipboard" --clear
check "clear is immediate and complete" "[ \$(count) -eq 0 ]"

echo "denied entries never persist"

record 1030 KeePassXC 'KeePassXC' 'hunter2'
check "a password-manager class is refused" "[ \$(count) -eq 0 ]"
record 1031 firefox 'GitHub — Sign in' 'hunter2'
check "a password title is refused" "[ \$(count) -eq 0 ]"
mime_hint=$(printf 'text/plain\nx-kde-passwordManagerHint')
record 1033 foot terminal 'mime-secret' "$mime_hint"
check "a password-manager MIME hint is refused" "[ \$(count) -eq 0 ]"
check "no denied text reached the history file" "! grep -q \"\$(printf 'hunter2' | base64 | tr -d '\\n')\" '$state/history'"

echo "private-window delay"

record 2000 firefox 'Mozilla Firefox — Private Browsing' 'private-one'
check "a private window is refused" "[ \$(count) -eq 0 ]"
record 2001 firefox 'Mozilla Firefox' 'still-too-soon'
check "the delay keeps recording off after the private window" "[ \$(count) -eq 0 ]"
record 2006 firefox 'Mozilla Firefox' 'after-the-delay'
check "recording resumes after the delay" "[ \$(count) -eq 1 ] && '$clipboard' --list | grep -q after-the-delay"

echo "local picker and keyboard selection"

"$clipboard" --clear
record 3000 foot terminal 'picker entry'
chosen=$("$clipboard" --list | head -n 1)
FUZZEL_STDIN="$tmp/picker.stdin" FUZZEL_ARGS="$tmp/picker.args" \
    FUZZEL_PICK="$chosen" WL_COPY_OUT="$tmp/picker.copy" "$clipboard" --search
status=$?
check "the local history reaches fuzzel" "grep -q 'picker entry' '$tmp/picker.stdin'"
check "the local picker has a search prompt" "grep -q 'Type to search clipboard' '$tmp/picker.args'"
check "the chosen local entry is copied" "[ \"\$(cat '$tmp/picker.copy')\" = 'picker entry' ]"
check "the local picker exits 0" "[ $status -eq 0 ]" "exit $status"

rm -f "$tmp/picker.copy"
FUZZEL_PICK='' WL_COPY_OUT="$tmp/picker.copy" "$clipboard" --search
status=$?
check "Escape in the local picker exits 0" "[ $status -eq 0 ]" "exit $status"
check "Escape copies nothing" "[ ! -e '$tmp/picker.copy' ]"

echo "daemon and missing tools"

"$clipboard" --clear
PATH="$fake:$PATH" "$clipboard" --daemon --max 3 > "$tmp/daemon.out" 2> "$tmp/daemon.err"
status=$?
check "the daemon records a clipboard change" "[ $status -eq 0 ] && '$clipboard' --list | grep -q 'daemon entry'" "exit $status: $(cat "$tmp/daemon.err")"

restricted="$tmp/restricted"
mkdir -p "$restricted"
for tool in awk base64 cat cut date dirname flock head kill mkdir mktemp mv readlink rm sed sleep tail tr wc; do
    path=$(command -v "$tool" 2>/dev/null || true)
    [ -n "$path" ] && ln -sf "$path" "$restricted/$tool"
done

PATH="$restricted" "$clipboard" --daemon > "$tmp/no-paste.out" 2> "$tmp/no-paste.err"
status=$?
check "a missing wl-paste is reported" "[ $status -eq 3 ] && grep -q 'wl-paste' '$tmp/no-paste.err'" "exit $status: $(cat "$tmp/no-paste.err")"

PATH="$restricted" "$clipboard" > "$tmp/no-cliphist.out" 2> "$tmp/no-cliphist.err"
status=$?
check "a missing cliphist is reported" "[ $status -eq 3 ] && grep -q 'cliphist' '$tmp/no-cliphist.err'" "exit $status: $(cat "$tmp/no-cliphist.err")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
