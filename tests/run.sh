#!/usr/bin/env bash
# Contract tests for bin/padilha-config. Run from anywhere; exits non-zero on
# the first broken guarantee.
#
# The point is not coverage, it is the promises in CONFIG.md: a bad config
# fails loudly with a useful message, and it never replaces a working file.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
padilha_config="$root/bin/padilha-config"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# expect_fail NAME CONFIG_PATTERN MESSAGE_PATTERN
expect_fail() {
    local name=$1 file=$2 pattern=$3
    local err status
    err=$("$padilha_config" compile --config "$file" --check 2>&1)
    status=$?
    if [ "$status" -eq 0 ]; then
        bad "$name" "exited 0, expected failure"
    elif ! printf '%s' "$err" | grep -qiE "$pattern"; then
        bad "$name" "message was: $err"
    else
        ok "$name"
    fi
}

echo "valid configs"

cat > "$tmp/good.lua" <<'LUA'
return {
    appearance = { transparency = { enabled = false } },
    general = { idle = { timeouts = padilha.array {} } },
}
LUA
out=$("$padilha_config" compile --config "$tmp/good.lua" --print 2>&1)
if printf '%s' "$out" | python3 -m json.tool >/dev/null 2>&1; then ok "emits valid JSON"; else bad "emits valid JSON" "$out"; fi
if printf '%s' "$out" | grep -q '"timeouts": \[\]'; then ok "padilha.array{} is a list"; else bad "padilha.array{} is a list" "$out"; fi

echo "overlay"

mkdir -p "$tmp/withlocal"
cat > "$tmp/withlocal/init.lua" <<'LUA'
return { enabled = false, appearance = { transparency = { enabled = false } } }
LUA
cat > "$tmp/withlocal/local.lua" <<'LUA'
return { appearance = { transparency = { enabled = true } } }
LUA
out=$("$padilha_config" compile --config "$tmp/withlocal/init.lua" --print 2>&1)
if printf '%s' "$out" | grep -q '"enabled": true' && printf '%s' "$out" | grep -q '"enabled": false'; then
    ok "local.lua overrides, keeps the rest"
else
    bad "local.lua overrides, keeps the rest" "$out"
fi

echo "broken configs"

printf 'return { appearance = }\n' > "$tmp/syntax.lua"
expect_fail "syntax error names the line" "$tmp/syntax.lua" "syntax\.lua:[0-9]+:"

printf 'return { bar = { onClick = function() end } }\n' > "$tmp/function.lua"
expect_fail "function value is rejected" "$tmp/function.lua" "function"

printf 'return { hooks = { on_scheme = 1 } }\n' > "$tmp/hooks.lua"
expect_fail "hooks is reserved" "$tmp/hooks.lua" "reserved"

printf 'return 42\n' > "$tmp/number.lua"
expect_fail "non-table return is rejected" "$tmp/number.lua" "must return a table"

printf 'local t = {} t.self = t return { bar = t }\n' > "$tmp/recursive.lua"
err=$("$padilha_config" compile --config "$tmp/recursive.lua" --no-schema --check 2>&1)
if printf '%s' "$err" | grep -qi "refers to itself"; then ok "recursive table is rejected"; else bad "recursive table is rejected" "$err"; fi

echo "schema"

schema="$root/tests/fixtures/schema.qmltypes"
cat > "$tmp/schema_good.lua" <<'LUA'
return { enabled = true, appearance = { transparency = { enabled = false } } }
LUA
if "$padilha_config" compile --config "$tmp/schema_good.lua" --schema "$schema" --check >/dev/null 2>&1; then
    ok "valid keys pass"
else
    bad "valid keys pass"
fi

cat > "$tmp/schema_unknown.lua" <<'LUA'
return { enabled = true, appearanc = {} }
LUA
err=$("$padilha_config" compile --config "$tmp/schema_unknown.lua" --schema "$schema" --check 2>&1)
if printf '%s' "$err" | grep -q 'unknown key' && printf '%s' "$err" | grep -q 'did you mean "appearance"'; then
    ok "unknown key suggests the real one"
else
    bad "unknown key suggests the real one" "$err"
fi

cat > "$tmp/schema_type.lua" <<'LUA'
return { enabled = "yes" }
LUA
err=$("$padilha_config" compile --config "$tmp/schema_type.lua" --schema "$schema" --check 2>&1)
if printf '%s' "$err" | grep -q 'expected a boolean, got string'; then
    ok "wrong type is reported"
else
    bad "wrong type is reported" "$err"
fi

cat > "$tmp/schema_nested.lua" <<'LUA'
return { appearance = { transparency = { enable = true } } }
LUA
err=$("$padilha_config" compile --config "$tmp/schema_nested.lua" --schema "$schema" --check 2>&1)
if printf '%s' "$err" | grep -q 'appearance.transparency.enable: unknown key'; then
    ok "nested unknown key is caught"
else
    bad "nested unknown key is caught" "$err"
fi

if "$padilha_config" compile --config "$tmp/schema_unknown.lua" --no-schema --check >/dev/null 2>&1; then
    ok "--no-schema skips validation"
else
    bad "--no-schema skips validation"
fi

cat > "$tmp/schema_enum.lua" <<'LUA'
return { mode = "dark" }
LUA
if "$padilha_config" compile --config "$tmp/schema_enum.lua" --schema "$schema" --check >/dev/null 2>&1; then
    ok "enum values are matched case-insensitively"
else
    bad "enum values are matched case-insensitively"
fi

cat > "$tmp/schema_enum_bad.lua" <<'LUA'
return { mode = "drak" }
LUA
err=$("$padilha_config" compile --config "$tmp/schema_enum_bad.lua" --schema "$schema" --check 2>&1)
if printf '%s' "$err" | grep -q 'expected one of Auto, Light, Dark' && printf '%s' "$err" | grep -q 'did you mean "Dark"'; then
    ok "unknown enum value lists the options"
else
    bad "unknown enum value lists the options" "$err"
fi

cat > "$tmp/schema_enum_type.lua" <<'LUA'
return { mode = 2 }
LUA
err=$("$padilha_config" compile --config "$tmp/schema_enum_type.lua" --schema "$schema" --check 2>&1)
if printf '%s' "$err" | grep -q 'mode: expected a string, got number'; then
    ok "a non-string enum value is rejected"
else
    bad "a non-string enum value is rejected" "$err"
fi

real_schema="$root/build/qml/Caelestia/Config/caelestia-config.qmltypes"
if [ -f "$real_schema" ]; then
    if "$padilha_config" compile --config "$root/examples/init.lua" --check >/dev/null 2>&1; then
        ok "the shipped example matches the real schema"
    else
        bad "the shipped example matches the real schema"
    fi
fi

echo "settings carry-over"

mkdir -p "$tmp/carry"
printf 'return { a = 1, b = { c = 2 } }\n' > "$tmp/carry/init.lua"
"$padilha_config" compile --config "$tmp/carry/init.lua" --out "$tmp/carry.json" --no-schema --quiet
if [ -s "$tmp/carry.json.base" ]; then ok "the baseline is written"; else bad "the baseline is written"; fi

printf '{"a": 9, "b": {"c": 2}, "d": true}\n' > "$tmp/carry.json"
printf 'return { a = 1, b = { c = 3 } }\n' > "$tmp/carry/init.lua"
"$padilha_config" compile --config "$tmp/carry/init.lua" --out "$tmp/carry.json" --no-schema --quiet
carried=$(/usr/bin/python3 -c "import json;d=json.load(open('$tmp/carry.json'));print(d['a'],d['b']['c'],d.get('d'))")
if [ "$carried" = "9 3 True" ]; then ok "a UI edit survives the next compile"; else bad "a UI edit survives the next compile" "$carried"; fi

printf 'return { a = 1, b = { c = 2 } }\n' > "$tmp/carry/init.lua"
"$padilha_config" compile --config "$tmp/carry/init.lua" --out "$tmp/carry.json" --no-schema --quiet --no-merge
forced=$(/usr/bin/python3 -c "import json;print(json.load(open('$tmp/carry.json'))['a'])")
if [ "$forced" = "1" ]; then ok "--no-merge lets init.lua win"; else bad "--no-merge lets init.lua win" "a=$forced"; fi

printf '{"a": 9}\n' > "$tmp/carry.json"
cat > "$tmp/empty.lua" <<'LUA'
return { general = { idle = { timeouts = padilha.array {} } } }
LUA
"$padilha_config" compile --config "$tmp/empty.lua" --out "$tmp/empty.json" --no-schema --quiet
"$padilha_config" compile --config "$tmp/empty.lua" --out "$tmp/empty.json" --no-schema --quiet
if grep -q '"timeouts": \[\]' "$tmp/empty.json"; then
    ok "empty lists stay lists through the merge"
else
    bad "empty lists stay lists through the merge" "$(cat "$tmp/empty.json")"
fi

printf 'return { a = 1 }\n' > "$tmp/carry/init.lua"
"$padilha_config" compile --config "$tmp/carry/init.lua" --out "$tmp/carry.json" --no-schema --quiet
if grep -q '"b"' "$tmp/carry.json"; then bad "a key dropped from init.lua goes away"; else ok "a key dropped from init.lua goes away"; fi

echo "first run"

init_home="$tmp/fresh"
mkdir -p "$init_home"
XDG_CONFIG_HOME="$init_home" "$padilha_config" init > /dev/null 2>&1
check=""
if [ -s "$init_home/padilha/init.lua" ]; then ok "init writes a default config"; else bad "init writes a default config"; fi

if XDG_CONFIG_HOME="$init_home" "$padilha_config" init > /dev/null 2>&1; then
    bad "init refuses to overwrite an existing config"
else
    ok "init refuses to overwrite an existing config"
fi

if XDG_CONFIG_HOME="$init_home" "$padilha_config" compile --quiet; then
    ok "the default config compiles"
else
    bad "the default config compiles"
fi

echo "nothing is replaced on failure"

printf '{"kept": true}\n' > "$tmp/out.json"
printf 'return { broken = }\n' > "$tmp/bad.lua"
"$padilha_config" compile --config "$tmp/bad.lua" --out "$tmp/out.json" >/dev/null 2>&1
if grep -qx '{"kept": true}' "$tmp/out.json"; then ok "existing output untouched"; else bad "existing output untouched"; fi
if ls "$tmp"/out.json.tmp >/dev/null 2>&1; then bad "no temp file left behind"; else ok "no temp file left behind"; fi

echo "check mode writes nothing"

rm -f "$tmp/never.json"
"$padilha_config" compile --config "$tmp/good.lua" --out "$tmp/never.json" --check >/dev/null 2>&1
if [ -e "$tmp/never.json" ]; then bad "--check does not write"; else ok "--check does not write"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
