#!/usr/bin/env bash
# Contract tests for bin/lilith-clipboard and bin/lilith-emoji. The pickers
# need a Wayland session, so fuzzel/cliphist/wl-copy are faked here; what is
# under test is the plumbing around them and the promises in the usage text.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
clipboard="$root/bin/lilith-clipboard"
emoji="$root/bin/lilith-emoji"
data="$root/share/emojis.txt"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

# Stand-ins for the Wayland tools. fuzzel records its stdin and arguments and
# prints $FUZZEL_PICK, or exits 1 like Escape when that is empty. cliphist
# serves a fixed history; wl-copy and cliphist delete write their stdin to the
# paths in $WL_COPY_OUT and $CLIPHIST_DELETED.
fake="$tmp/bin"
mkdir -p "$fake"

cat > "$fake/fuzzel" <<'SH'
#!/bin/sh
cat > "${FUZZEL_STDIN:-/dev/null}"
printf '%s\n' "$*" > "${FUZZEL_ARGS:-/dev/null}"
[ -n "${FUZZEL_PICK:-}" ] || exit 1
printf '%s\n' "$FUZZEL_PICK"
SH

cat > "$fake/cliphist" <<'SH'
#!/bin/sh
case ${1:-} in
    list) printf '1\tfirst entry\n2\tsecond entry\n' ;;
    decode) printf 'decoded:'; cat ;;
    delete) cat > "${CLIPHIST_DELETED:-/dev/null}" ;;
esac
SH

cat > "$fake/wl-copy" <<'SH'
#!/bin/sh
cat > "${WL_COPY_OUT:-/dev/null}"
SH

chmod +x "$fake/fuzzel" "$fake/cliphist" "$fake/wl-copy"
export PATH="$fake:$PATH"

# expect_usage NAME CMD...: unknown flags are a usage error, exit 2.
expect_usage() {
    local name=$1
    shift
    local out status
    out=$("$@" 2>&1)
    status=$?
    if [ "$status" -ne 2 ]; then
        bad "$name: exits 2" "exit $status"
    elif ! printf '%s' "$out" | grep -q 'usage'; then
        bad "$name: prints usage" "$out"
    else
        ok "$name"
    fi
}

echo "syntax and permissions"

check "clipboard passes sh -n" "sh -n '$clipboard'"
check "emoji passes sh -n" "sh -n '$emoji'"
check "clipboard is executable" "test -x '$clipboard'"
check "emoji is executable" "test -x '$emoji'"

echo "usage"

expect_usage "clipboard rejects unknown flags" "$clipboard" --nope
expect_usage "emoji rejects unknown flags" "$emoji" --nope

"$clipboard" -h > "$tmp/clipboard.help" 2>&1
status=$?
check "clipboard -h exits 0" "[ $status -eq 0 ]" "exit $status"
check "clipboard -h prints usage" "grep -q 'usage' '$tmp/clipboard.help'"

"$emoji" -h > "$tmp/emoji.help" 2>&1
status=$?
check "emoji -h exits 0" "[ $status -eq 0 ]" "exit $status"
check "emoji -h prints usage" "grep -q 'usage' '$tmp/emoji.help'"

echo "data"

check "the emoji data exists and is not empty" "test -s '$data'"
check "the first emoji line is non-empty" "[ -n \"\$(head -n 1 '$data')\" ]"

"$emoji" > "$tmp/all.out" 2> "$tmp/all.err"
status=$?
check "emoji with no args exits 0" "[ $status -eq 0 ]" "exit $status"
check "emoji with no args prints the data file" "cmp -s '$data' '$tmp/all.out'"

check "clipboard does not reference the old CLI" "! grep -Eqi 'caelestia|python' '$clipboard'"
check "emoji does not reference the old CLI" "! grep -Eqi 'caelestia|python' '$emoji'"

echo "emoji picker"

line=$(sed -n '2p' "$data")
FUZZEL_STDIN="$tmp/emoji.stdin" FUZZEL_ARGS="$tmp/emoji.args" \
    FUZZEL_PICK="$line" WL_COPY_OUT="$tmp/glyph" "$emoji" -p
status=$?
check "picking copies only the first field" "[ \"\$(cat '$tmp/glyph')\" = '←' ]" "$(cat "$tmp/glyph" 2>/dev/null)"
check "picking exits 0" "[ $status -eq 0 ]" "exit $status"
check "the data reaches fuzzel" "grep -q 'left arrow' '$tmp/emoji.stdin'"
check "the picker gets its own placeholder" "grep -q 'Type to search emojis' '$tmp/emoji.args'"

rm -f "$tmp/glyph"
FUZZEL_PICK= WL_COPY_OUT="$tmp/glyph" "$emoji" -p
status=$?
check "Escape in the emoji picker exits 0" "[ $status -eq 0 ]" "exit $status"
check "Escape in the emoji picker copies nothing" "[ ! -e '$tmp/glyph' ]"

"$emoji" -f > "$tmp/fetch.out" 2> "$tmp/fetch.err"
status=$?
check "-f exits 2" "[ $status -eq 2 ]" "exit $status"
check "-f explains itself in one line" "[ \$(wc -l < '$tmp/fetch.err') -eq 1 ]" "$(cat "$tmp/fetch.err")"

echo "clipboard picker"

FUZZEL_STDIN="$tmp/clipboard.stdin" FUZZEL_ARGS="$tmp/clipboard.args" \
    FUZZEL_PICK=$(printf '2\tsecond entry') WL_COPY_OUT="$tmp/copied" \
    "$clipboard"
status=$?
check "the history reaches fuzzel" "grep -q 'first entry' '$tmp/clipboard.stdin'"
check "the picker gets the search placeholder" "grep -q 'Type to search clipboard' '$tmp/clipboard.args'"
check "the chosen entry is decoded and copied" "grep -q 'second entry' '$tmp/copied'"
check "copying exits 0" "[ $status -eq 0 ]" "exit $status"

rm -f "$tmp/copied"
FUZZEL_PICK= WL_COPY_OUT="$tmp/copied" "$clipboard"
status=$?
check "Escape in the clipboard picker exits 0" "[ $status -eq 0 ]" "exit $status"
check "Escape in the clipboard picker copies nothing" "[ ! -e '$tmp/copied' ]"

FUZZEL_STDIN="$tmp/delete.stdin" FUZZEL_ARGS="$tmp/delete.args" \
    FUZZEL_PICK=$(printf '1\tfirst entry') CLIPHIST_DELETED="$tmp/deleted" \
    WL_COPY_OUT="$tmp/deleted-copy" "$clipboard" -d
status=$?
check "the delete prompt is shown" "grep -q 'del > ' '$tmp/delete.args'"
check "the chosen entry is deleted" "grep -q 'first entry' '$tmp/deleted'"
check "delete does not copy" "[ ! -e '$tmp/deleted-copy' ]"
check "deleting exits 0" "[ $status -eq 0 ]" "exit $status"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
