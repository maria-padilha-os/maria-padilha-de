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
return { appearance = { transparency = { enabled = false } }, general = { gaps = 10 } }
LUA
cat > "$tmp/withlocal/local.lua" <<'LUA'
return { appearance = { transparency = { enabled = true } } }
LUA
out=$("$padilha_config" compile --config "$tmp/withlocal/init.lua" --print 2>&1)
if printf '%s' "$out" | grep -q '"enabled": true' && printf '%s' "$out" | grep -q '"gaps": 10'; then
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
expect_fail "recursive table is rejected" "$tmp/recursive.lua" "refers to itself"

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
