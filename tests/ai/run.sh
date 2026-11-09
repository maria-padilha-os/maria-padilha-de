#!/usr/bin/env bash
# Contract tests for the permissioned home-access broker (ADR 0001).
#
# Everything runs under a temporary HOME, XDG_CONFIG_HOME and XDG_STATE_HOME.
# The real home directory is never read or written.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
ai="$root/bin/padilha-ai"
tmp=$(mktemp -d)
trap 'chmod -R u+rwX "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"
unset PADILHA_AI_CONFIG PADILHA_AI_ROOTS PADILHA_AI_STATE PADILHA_AI_HOME 2>/dev/null || true

config_dir="$XDG_CONFIG_HOME/padilha"
config_file="$config_dir/ai.lua"
state_dir="$XDG_STATE_HOME/padilha/ai"
audit_file="$state_dir/audit.jsonl"

mkdir -p "$HOME/Documents" "$HOME/Projects" "$HOME/Doc" \
    "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.dsh" \
    "$HOME/.config/google-chrome" "$HOME/.config/BraveSoftware" \
    "$HOME/.mozilla" "$config_dir"

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

write_config() {
    local write=${1:-false}
    cat >"$config_file" <<LUA
return {
    permissions = {
        write = $write,
        roots = {},
        deny = {},
    },
}
LUA
    chmod 600 "$config_file"
}

ai() { "$ai" "$@"; }

expect_ok() {
    local name=$1
    shift
    local out status
    out=$(ai "$@" 2>&1)
    status=$?
    if [ "$status" -eq 0 ]; then
        ok "$name"
    else
        bad "$name" "exit $status: $out"
    fi
    printf '%s' "$out"
}

expect_denied() {
    local name=$1 pattern=$2
    shift 2
    local out status
    out=$(ai "$@" 2>&1)
    status=$?
    if [ "$status" -eq 0 ]; then
        bad "$name" "exited 0, expected denial: $out"
    elif ! printf '%s' "$out" | grep -qiE "$pattern"; then
        bad "$name" "message was: $out"
    else
        ok "$name"
    fi
}

write_config false
printf 'Document notes\n' >"$HOME/Documents/notes.txt"
printf 'project notes\n' >"$HOME/Projects/project.txt"
printf 'boundary\n' >"$HOME/Doc/boundary.txt"
printf 'ssh secret\n' >"$HOME/.ssh/id_rsa"
printf 'gpg secret\n' >"$HOME/.gnupg/private.gpg"
printf 'dsh secret\n' >"$HOME/.dsh/token"
printf 'chrome cookie\n' >"$HOME/.config/google-chrome/Cookies"
printf 'brave cookie\n' >"$HOME/.config/BraveSoftware/Cookies"
printf 'firefox data\n' >"$HOME/.mozilla/key4.db"
printf 'local secret\n' >"$HOME/Documents/env.local.lua"
printf 'netrc secret\n' >"$HOME/Documents/.netrc"
printf 'pem secret\n' >"$HOME/Documents/key.pem"
printf 'binary\0data\n' >"$HOME/Documents/binary.bin"
mkdir -p "$HOME/Documents/.ssh"
printf 'nested ssh\n' >"$HOME/Documents/.ssh/id_ed25519"

echo "no roots state"

out=$(ai status 2>&1)
if printf '%s' "$out" | grep -q 'no roots approved'; then
    ok "status says no roots approved"
else
    bad "status says no roots approved" "$out"
fi
expect_denied "read is denied before approval" 'no_roots|denied' \
    read "$HOME/Documents/notes.txt"

echo "approval"

out=$(ai roots approve "$HOME/Documents" 2>&1)
if printf '%s' "$out" | grep -q 'approved ro root'; then
    ok "approve a directory read-only"
else
    bad "approve a directory read-only" "$out"
fi
out=$(ai roots list 2>&1)
if printf '%s' "$out" | grep -q 'Documents' && printf '%s' "$out" | grep -q '^ro'; then
    ok "approved root is listed"
else
    bad "approved root is listed" "$out"
fi
out=$(ai read "$HOME/Documents/notes.txt" 2>&1)
if [ "$out" = "Document notes" ]; then
    ok "read works inside an approved root"
else
    bad "read works inside an approved root" "$out"
fi
expect_denied "home itself is not a root" 'invalid_root|home' roots approve "$HOME"
expect_denied "a denied directory cannot be a root" 'denied' roots approve "$HOME/.ssh"
expect_denied "a root outside home is refused" 'outside|home' roots approve /etc
expect_denied "the filesystem root is refused" 'invalid|refused' roots approve /

echo "traversal and boundary"

expect_denied "parent traversal is refused" 'dotdot|travers' \
    read "$HOME/Documents/../.ssh/id_rsa"
expect_denied "an absolute path outside the root is refused" 'outside_root|outside' \
    read "$HOME/Projects/project.txt"
expect_denied "component boundary is respected" 'outside_root' \
    read "$HOME/Doc/boundary.txt"
expect_denied "a ~user path is refused" 'tilde|absolute|invalid' \
    read "~root/notes.txt"
expect_denied "a nonexistent path is refused" 'not_found|invalid' \
    read "$HOME/Documents/missing.txt"

echo "symlinks"

ln -s "$HOME/.ssh" "$HOME/Documents/ssh-link"
ln -s "$HOME/Projects" "$HOME/Documents/projects-link"
ln -s "$HOME/Documents/loop" "$HOME/Documents/loop"
ln -s "$HOME/.ssh/id_rsa" "$HOME/Documents/key-link"
expect_denied "a symlink escape is refused" 'denied|outside|symlink' \
    read "$HOME/Documents/ssh-link/id_rsa"
expect_denied "a symlink loop is refused" 'symlink|invalid|not_found' \
    read "$HOME/Documents/loop"
expect_denied "a symlink to a denied file is refused" 'denied|symlink' \
    read "$HOME/Documents/key-link"
if ai read "$HOME/Documents/projects-link/project.txt" >/dev/null 2>&1; then
    bad "symlink handling" "a link outside the root was followed"
else
    ok "an in-root symlink whose target is outside the root is refused"
fi
ln -s "$HOME/Documents/notes.txt" "$HOME/Documents/.ssh-alias"
# A harmless target does not make a denied component name readable.
ln -s "$HOME/Documents/notes.txt" "$HOME/Documents/ssh-name"
ln -sfn "$HOME/Documents/notes.txt" "$HOME/Documents/.dsh"
expect_denied "a symlink with a denied basename is refused" 'denied' \
    read "$HOME/Documents/.dsh"

echo "built-in deny list"

for denied in \
    "$HOME/.ssh/id_rsa" \
    "$HOME/.gnupg/private.gpg" \
    "$HOME/.dsh/token" \
    "$HOME/.config/google-chrome/Cookies" \
    "$HOME/.config/BraveSoftware/Cookies" \
    "$HOME/.mozilla/key4.db" \
    "$HOME/Documents/env.local.lua" \
    "$HOME/Documents/.netrc" \
    "$HOME/Documents/key.pem" \
    "$HOME/Documents/.ssh/id_ed25519"; do
    expect_denied "denied path $(basename "$denied")" 'denied|outside_home' read "$denied"
done

out=$(ai list "$HOME/Documents" 2>&1)
if printf '%s' "$out" | grep -q 'env.local.lua'; then
    bad "list omits denied entries" "$out"
elif printf '%s' "$out" | grep -q '/.ssh$'; then
    bad "list omits denied directories" "$out"
else
    ok "list omits denied entries instead of naming them"
fi

echo "file type and size limits"

expect_denied "binary files are refused" 'not a text file|binary' \
    read "$HOME/Documents/binary.bin"
python3 - "$HOME/Documents/huge.txt" <<'PY'
import sys
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write("a" * (256 * 1024 + 1))
PY
expect_denied "oversized files are refused" 'too large|large' \
    read "$HOME/Documents/huge.txt"
mkfifo "$HOME/Documents/pipe"
expect_denied "FIFOs are refused" 'regular|unsafe' read "$HOME/Documents/pipe"

printf 'outside hardlink secret\n' >"$HOME/outside-secret.txt"
ln "$HOME/outside-secret.txt" "$HOME/Documents/hardlink.txt"
expect_denied "hard links are refused" 'hard.link|hardlink' \
    read "$HOME/Documents/hardlink.txt"
ln "$HOME/.ssh/id_rsa" "$HOME/Documents/ssh-hardlink"
expect_denied "a hard link to a denied file is refused even with the override" \
    'hard.link|denied|credential' read "$HOME/Documents/ssh-hardlink" --allow-hard-link

echo "redaction and audit"

cat >"$HOME/Documents/secrets.txt" <<'SECRETS'
password=hunter2
api_key = sk-abcdefghijklmnopqrstuvwxyz
Authorization: Bearer abcdefghijklmnop
-----BEGIN OPENSSH PRIVATE KEY-----
SUPERSECRETKEYMATERIAL
-----END OPENSSH PRIVATE KEY-----
https://user:pass@example.com/private
SECRETS
out=$(ai read "$HOME/Documents/secrets.txt" 2>&1)
if printf '%s' "$out" | grep -q '\[REDACTED:'; then
    ok "secrets are replaced with redaction markers"
else
    bad "secrets are replaced with redaction markers" "$out"
fi
if printf '%s' "$out" | grep -qE 'hunter2|SUPERSECRETKEYMATERIAL|abcdefghijklmnop|sk-abcdefghijklmnopqrstuvwxyz'; then
    bad "raw secrets do not reach the output" "$out"
else
    ok "raw secrets do not reach the output"
fi
if [ -f "$audit_file" ]; then
    if grep -qE 'hunter2|SUPERSECRETKEYMATERIAL|sk-abcdefghijklmnopqrstuvwxyz|user:pass' "$audit_file"; then
        bad "audit never stores file contents" "$(grep -nE 'hunter2|SUPERSECRET|sk-abcdef|user:pass' "$audit_file" | head -2)"
    else
        ok "audit never stores file contents"
    fi
    if grep -q '"event":"file.read"' "$audit_file" && grep -q '"decision":"allow"' "$audit_file"; then
        ok "audit records a metadata-only read decision"
    else
        bad "audit records a metadata-only read decision" "$(tail -2 "$audit_file")"
    fi
else
    bad "audit never stores file contents" "audit file is missing"
fi

out=$(ai search password "$HOME/Documents" 2>&1)
if printf '%s' "$out" | grep -q 'secrets.txt' && printf '%s' "$out" | grep -q 'REDACTED'; then
    ok "search returns redacted hits"
else
    bad "search returns redacted hits" "$out"
fi

echo "revocation"

out=$(ai roots approve "$HOME/Projects" 2>&1)
if printf '%s' "$out" | grep -q 'approved'; then ok "approve a second root"; else bad "approve a second root" "$out"; fi
if ai read "$HOME/Projects/project.txt" >/dev/null 2>&1; then ok "second root is readable"; else bad "second root is readable"; fi
out=$(ai roots revoke "$HOME/Projects" 2>&1)
if printf '%s' "$out" | grep -q 'revoked'; then ok "revoke a generated grant"; else bad "revoke a generated grant" "$out"; fi
expect_denied "a revoked root is denied immediately" 'outside_root|no_roots' \
    read "$HOME/Projects/project.txt"
expect_denied "revoking an unknown root fails" 'no such|not_found' roots revoke "$HOME/Projects"

cat >"$config_file" <<LUA
return {
    permissions = {
        write = false,
        roots = { { path = "$HOME/Projects", mode = "ro" } },
    },
}
LUA
chmod 600 "$config_file"
out=$(ai roots revoke "$HOME/Projects" 2>&1)
status=$?
if [ "$status" -eq 0 ] && printf '%s' "$out" | grep -q 'declared_in_config'; then
    ok "a config-declared root is not silently removed"
else
    bad "a config-declared root is not silently removed" "exit $status: $out"
fi
if ai read "$HOME/Projects/project.txt" >/dev/null 2>&1; then
    ok "a config-declared root stays readable after a refused revoke"
else
    bad "a config-declared root stays readable after a refused revoke"
fi
write_config false

echo "writes need explicit confirmation"

write_config false
out=$(ai roots approve "$HOME/Documents" --rw 2>&1)
if printf '%s' "$out" | grep -q 'approved rw root'; then ok "approve a read-write root"; else bad "approve a read-write root" "$out"; fi
printf 'original\n' >"$HOME/Documents/write.txt"
expect_denied "write is disabled globally by default" 'write_disabled|read_only|disabled' \
    write "$HOME/Documents/write.txt" --content 'changed'

write_config true
out=$(ai write "$HOME/Documents/write.txt" --content 'replacement' 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -q 'confirmation required'; then
    ok "a write request is not a write"
else
    bad "a write request is not a write" "exit $status: $out"
fi
token=$(printf '%s' "$out" | sed -n 's/^confirm with: padilha-ai confirm //p')
if [ -n "$token" ] && [ "$(cat "$HOME/Documents/write.txt")" = "original" ]; then
    ok "the target is untouched before confirmation"
else
    bad "the target is untouched before confirmation" "$(cat "$HOME/Documents/write.txt" 2>/dev/null)"
fi
expect_denied "an unknown confirmation token is refused" 'unknown|invalid|confirmation' \
    confirm confirm-thisisnotarealtoken
expect_denied "a wrong confirmation token is refused" 'unknown|invalid|confirmation' \
    confirm confirm-AAAAAAAAAAAAAAAAAAAAAAAA
out=$(ai confirm "$token" 2>&1)
status=$?
if [ "$status" -eq 0 ] && [ "$(cat "$HOME/Documents/write.txt")" = "replacement" ]; then
    ok "a separate confirmation applies the write"
else
    bad "a separate confirmation applies the write" "exit $status: $out"
fi
expect_denied "a confirmation token is one-use" 'unknown|used|confirmation' \
    confirm "$token"

printf 'new file\n' >/dev/null
out=$(ai write "$HOME/Documents/new.txt" --content 'fresh' 2>&1)
token=$(printf '%s' "$out" | sed -n 's/^confirm with: padilha-ai confirm //p')
ai confirm "$token" >/dev/null 2>&1
if [ -f "$HOME/Documents/new.txt" ] && [ "$(stat -c %a "$HOME/Documents/new.txt")" = "600" ]; then
    ok "a new file is created mode 0600"
else
    bad "a new file is created mode 0600" "$(ls -l "$HOME/Documents/new.txt" 2>/dev/null)"
fi

printf 'original two\n' >"$HOME/Documents/changed.txt"
out=$(ai write "$HOME/Documents/changed.txt" --content 'model replacement' 2>&1)
token=$(printf '%s' "$out" | sed -n 's/^confirm with: padilha-ai confirm //p')
printf 'user edit\n' >"$HOME/Documents/changed.txt"
expect_denied "a file changed after the request is refused" 'changed|confirmation' \
    confirm "$token"
if [ "$(cat "$HOME/Documents/changed.txt")" = "user edit" ]; then
    ok "a failed confirmation leaves the file alone"
else
    bad "a failed confirmation leaves the file alone" "$(cat "$HOME/Documents/changed.txt")"
fi

ln -s "$HOME/.ssh/id_rsa" "$HOME/Documents/write-link"
expect_denied "a write through a symlink is refused" 'symlink' \
    write "$HOME/Documents/write-link" --content 'nope'

printf 'audit guard\n' >"$HOME/Documents/audit-guard.txt"
out=$(ai write "$HOME/Documents/audit-guard.txt" --content 'must not land' 2>&1)
token=$(printf '%s' "$out" | sed -n 's/^confirm with: padilha-ai confirm //p')
rm -f "$audit_file"
mkdir -p "$audit_file"
expect_denied "an unavailable audit blocks a confirmed write" 'audit' confirm "$token"
if [ "$(cat "$HOME/Documents/audit-guard.txt")" = "audit guard" ]; then
    ok "a write blocked by audit leaves the file alone"
else
    bad "a write blocked by audit leaves the file alone" "$(cat "$HOME/Documents/audit-guard.txt")"
fi
rmdir "$audit_file" 2>/dev/null || true

echo "commands are never executed"

marker="$tmp/command-ran"
expect_denied "command execution is disabled" 'command|shell|not available' \
    command "touch $marker"
if [ ! -e "$marker" ]; then ok "a command request did not run"; else bad "a command request did not run"; fi
out=$(ai propose-command "touch $marker" 2>&1)
if printf '%s' "$out" | grep -q "touch $marker" && [ ! -e "$marker" ]; then
    ok "propose-command returns text only"
else
    bad "propose-command returns text only" "$out"
fi

echo "configuration safety"

cp "$config_file" "$tmp/good.lua"
printf 'return { permissions = { write = true } }\n' >"$config_file"
chmod 644 "$config_file"
expect_denied "a world-readable config is refused" '0600|mode' status
chmod 600 "$config_file"
rm -f "$config_file"
ln -s "$tmp/good.lua" "$config_file"
expect_denied "a symlinked config is refused" 'symlink' status
rm -f "$config_file"
printf 'return { hooks = function() end }\n' >"$config_file"
chmod 600 "$config_file"
expect_denied "functions in config are refused" 'function|unsupported' status
write_config false

echo "audit failure is fail-closed"

rm -f "$audit_file"
mkdir -p "$audit_file"
out=$(ai read "$HOME/Documents/notes.txt" 2>&1)
status=$?
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qiE 'audit'; then
    ok "an unavailable audit disables reads"
else
    bad "an unavailable audit disables reads" "exit $status: $out"
fi
rmdir "$audit_file" 2>/dev/null || true

echo "JSON-lines protocol"

write_config false
out=$(printf '%s\n' \
    '{"v":1,"cmd":"status"}' \
    '{"v":1,"cmd":"roots","action":"approve","path":"'"$HOME"'/Documents"}' \
    '{"v":1,"cmd":"read","id":"r1","path":"'"$HOME"'/Documents/notes.txt"}' \
    '{"v":1,"cmd":"command","command":"true"}' \
    '{"v":1,"cmd":"shutdown"}' | ai --stdio 2>&1)
if printf '%s' "$out" | grep -q '"type": "ready"' &&
    printf '%s' "$out" | grep -q '"name": "read_file"' &&
    printf '%s' "$out" | grep -q '"code": "command_disabled"'; then
    ok "stdio protocol exposes only broker operations"
else
    bad "stdio protocol exposes only broker operations" "$out"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
