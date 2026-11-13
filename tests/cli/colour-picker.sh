#!/usr/bin/env bash
# Contract tests for bin/padilha-colour and the colour-picker extension.
# hyprpicker and wl-copy are faked: CI must never sample the live screen and
# these tests only exercise parsing, cancellation, clipboard failure, and the
# QML wiring that starts a picker from an explicit click.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
colour="$root/bin/padilha-colour"
widget="$root/extensions/colour-picker/Widget.qml"
tab="$root/extensions/colour-picker/Tab.qml"
manifest="$root/extensions/colour-picker/extension.json"
bar="$root/shell/modules/bar"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

fake="$tmp/bin"
mkdir -p "$fake"

cat > "$fake/hyprpicker" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "${HYPRPICKER_ARGS:-/dev/null}"
[ -n "${HYPRPICKER_PID:-}" ] && printf '%s\n' "$$" > "$HYPRPICKER_PID"
[ -n "${HYPRPICKER_FAIL:-}" ] && exit "$HYPRPICKER_FAIL"
printf '%s' "${HYPRPICKER_OUT:-}"
SH

cat > "$fake/wl-copy" <<'SH'
#!/bin/sh
[ -n "${WL_COPY_FAIL:-}" ] && { cat >/dev/null; exit 1; }
cat > "${WL_COPY_OUT:-/dev/null}"
SH

chmod +x "$fake/hyprpicker" "$fake/wl-copy"
export PATH="$fake:$PATH"

echo "syntax and usage"

check "colour command passes sh syntax check via Lua parser" "lua -e 'assert(loadfile(\"$colour\"))'"
check "colour command is executable" "test -x '$colour'"
check "the compatibility name is an alias" "test -L '$root/bin/lilith-colour'"

"$colour" -h > "$tmp/help.out" 2> "$tmp/help.err"
status=$?
check "-h exits 0" "[ $status -eq 0 ]" "exit $status"
check "-h prints usage" "grep -q 'usage:' '$tmp/help.err'"

"$colour" --nope > /dev/null 2> "$tmp/usage.err"
status=$?
check "unknown commands exit 2" "[ $status -eq 2 ]" "exit $status"
check "unknown commands print usage" "grep -q 'usage:' '$tmp/usage.err'"

echo "colour parsing"

"$colour" parse '#FF8000' > "$tmp/hex.out" 2> "$tmp/hex.err"
status=$?
check "hex parsing exits 0" "[ $status -eq 0 ]" "exit $status"
check "hex is normalised" "grep -qx 'HEX=#ff8000' '$tmp/hex.out'"
check "rgb is printed" "grep -qx 'RGB=rgb(255, 128, 0)' '$tmp/hex.out'"
check "hsl is printed" "grep -qx 'HSL=hsl(30, 100%, 50%)' '$tmp/hex.out'"

"$colour" parse '#f80' > "$tmp/short.out" 2>&1
check "short hex expands" "grep -qx 'HEX=#ff8800' '$tmp/short.out'"
check "short hex hsl is exact" "grep -qx 'HSL=hsl(32, 100%, 50%)' '$tmp/short.out'"

"$colour" parse 'rgb(51, 102, 153)' > "$tmp/rgb.out" 2>&1
check "rgb input is accepted" "grep -qx 'HEX=#336699' '$tmp/rgb.out'"
check "rgb input gets the right hsl" "grep -qx 'HSL=hsl(210, 50%, 40%)' '$tmp/rgb.out'"

"$colour" parse 'hsl(210, 50%, 40%)' > "$tmp/hsl.out" 2>&1
check "hsl input is accepted" "grep -qx 'HEX=#336699' '$tmp/hsl.out'"

"$colour" parse '#336699' --json > "$tmp/parse.json" 2> "$tmp/parse.err"
status=$?
check "json parsing exits 0" "[ $status -eq 0 ]" "exit $status"
if /usr/bin/python3 - "$tmp/parse.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["hex"] == "#336699", d
assert d["rgb"] == "rgb(51, 102, 153)", d
assert d["hsl"] == "hsl(210, 50%, 40%)", d
assert (d["red"], d["green"], d["blue"]) == (51, 102, 153), d
PY
then
    ok "json carries hex, rgb, hsl and channels"
else
    bad "json carries hex, rgb, hsl and channels" "$(cat "$tmp/parse.json")"
fi

echo "invalid selections"

for value in '#12345' '#gg0000' 'not-a-colour' 'rgb(300, 0, 0)' 'hsl(20, 200%, 50%)'; do
    "$colour" parse "$value" > "$tmp/invalid.out" 2> "$tmp/invalid.err"
    status=$?
    if [ "$status" -eq 1 ]; then ok "rejects $value"; else bad "rejects $value" "exit $status"; fi
done
check "invalid input names the problem" "grep -q 'not a colour' '$tmp/invalid.err'"

"$colour" parse > /dev/null 2>&1
status=$?
check "parse without a value is a usage error" "[ $status -eq 2 ]" "exit $status"

echo "picking"

HYPRPICKER_OUT='#336699' HYPRPICKER_PID="$tmp/picker.pid" \
    HYPRPICKER_ARGS="$tmp/picker.args" WL_COPY_OUT="$tmp/clipboard" \
    "$colour" pick --json > "$tmp/pick.json" 2> "$tmp/pick.err"
status=$?
check "a successful pick exits 0" "[ $status -eq 0 ]" "exit $status"
check "the picked value reaches the clipboard" "[ \"\$(cat '$tmp/clipboard')\" = '#336699' ]" "$(cat "$tmp/clipboard" 2>/dev/null)"
if /usr/bin/python3 - "$tmp/pick.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["hex"] == "#336699", d
assert d["rgb"] == "rgb(51, 102, 153)", d
assert d["hsl"] == "hsl(210, 50%, 40%)", d
PY
then
    ok "pick returns the same json the parser does"
else
    bad "pick returns the same json the parser does" "$(cat "$tmp/pick.json")"
fi
picker_pid=$(cat "$tmp/picker.pid" 2>/dev/null || true)
if [ -n "$picker_pid" ] && kill -0 "$picker_pid" 2>/dev/null; then
    bad "the picker process is gone after selection" "pid $picker_pid still running"
else
    ok "the picker process is gone after selection"
fi

rm -f "$tmp/no-copy"
HYPRPICKER_OUT='#abcdef' WL_COPY_OUT="$tmp/no-copy" \
    "$colour" pick --no-copy > "$tmp/no-copy.out" 2>&1
status=$?
check "--no-copy still reports the colour" "[ $status -eq 0 ] && grep -qx 'HEX=#abcdef' '$tmp/no-copy.out'" "exit $status"
check "--no-copy leaves the clipboard alone" "[ ! -e '$tmp/no-copy' ]"

echo "cancelled selection"

rm -f "$tmp/cancel-clip" "$tmp/cancel-pid"
HYPRPICKER_OUT='' HYPRPICKER_FAIL=1 HYPRPICKER_PID="$tmp/cancel-pid" \
    WL_COPY_OUT="$tmp/cancel-clip" \
    "$colour" pick --json > "$tmp/cancel.out" 2> "$tmp/cancel.err"
status=$?
check "Escape/cancel exits 3" "[ $status -eq 3 ]" "exit $status"
check "Escape/cancel prints no colour" "[ ! -s '$tmp/cancel.out' ]" "$(cat "$tmp/cancel.out")"
check "Escape/cancel writes no clipboard" "[ ! -e '$tmp/cancel-clip' ]"
cancel_pid=$(cat "$tmp/cancel-pid" 2>/dev/null || true)
if [ -n "$cancel_pid" ] && kill -0 "$cancel_pid" 2>/dev/null; then
    bad "the picker process is gone after cancellation" "pid $cancel_pid still running"
else
    ok "the picker process is gone after cancellation"
fi

echo "bad picker output"

rm -f "$tmp/bad-clip"
HYPRPICKER_OUT='the picker said no' WL_COPY_OUT="$tmp/bad-clip" \
    "$colour" pick --json > "$tmp/bad.out" 2> "$tmp/bad.err"
status=$?
check "malformed picker output exits 1" "[ $status -eq 1 ]" "exit $status"
check "malformed picker output copies nothing" "[ ! -e '$tmp/bad-clip' ]"
check "malformed picker output explains itself" "grep -q 'not a colour' '$tmp/bad.err'"

echo "clipboard failure"

rm -f "$tmp/fail-clip"
HYPRPICKER_OUT='#112233' WL_COPY_FAIL=1 WL_COPY_OUT="$tmp/fail-clip" \
    "$colour" pick --json > "$tmp/fail.json" 2> "$tmp/fail.err"
status=$?
check "clipboard failure exits 4" "[ $status -eq 4 ]" "exit $status"
check "clipboard failure keeps the parsed value" "grep -q '\"hex\": \"#112233\"' '$tmp/fail.json'"
check "clipboard failure names the clipboard" "grep -qi 'clipboard' '$tmp/fail.err'"

WL_COPY_OUT="$tmp/copied" "$colour" copy '#AbCdEf' > "$tmp/copy.out" 2> "$tmp/copy.err"
status=$?
check "copy normalises and exits 0" "[ $status -eq 0 ] && [ \"\$(cat '$tmp/copied')\" = '#abcdef' ]" "exit $status"
check "copy prints the canonical hex" "grep -qx '#abcdef' '$tmp/copy.out'"

rm -f "$tmp/copy-invalid"
WL_COPY_OUT="$tmp/copy-invalid" "$colour" copy 'nope' > /dev/null 2> "$tmp/copy-invalid.err"
status=$?
check "copy rejects an invalid colour" "[ $status -eq 1 ]" "exit $status"
check "copy rejection writes no clipboard" "[ ! -e '$tmp/copy-invalid' ]"

WL_COPY_FAIL=1 "$colour" copy '#123456' > /dev/null 2> "$tmp/copy-fail.err"
status=$?
check "copy reports clipboard failure as 4" "[ $status -eq 4 ]" "exit $status"

echo "extension wiring"

check "the extension manifest declares the picker tab" "grep -q '\"tab\": \"Tab.qml\"' '$manifest'"
check "the dashboard tab embeds the extension widget" "grep -q 'Widget {' '$tab'"
check "the picker only starts from an explicit click" "grep -q 'onClicked: root.pick()' '$widget'"
check "the extension does not start a process when loaded" "! grep -Eq 'Component.onCompleted.*pick|running: true' '$widget'"
check "the extension calls the foreground command" "grep -q 'command: \[\"padilha-colour\", \"pick\", \"--json\"\]' '$widget'"
check "the extension stops a pending picker when inactive" "grep -q 'pickProc.running = false' '$widget'"
check "the extension has no screenshot capture" "! grep -Eqi 'screencopy|grim|saveItem' '$widget'"
check "the extension draws from the active palette" "grep -q 'root.themePalette.m3' '$widget'"
check "the swatch label uses the contrast colour" "grep -q 'root.api.colours.on(root.hex)' '$widget'"
check "the picker is no longer hardcoded in the bar" "! grep -Rqi 'colourPicker\|colourpicker\|ColourPicker' '$bar'"
check "the picker command never invokes a screenshot tool" "! grep -Eqi 'grim|screencopy|saveItem' '$colour'"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
