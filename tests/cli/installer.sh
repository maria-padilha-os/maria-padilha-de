#!/usr/bin/env bash
# Contract tests for install.sh that do not need root: every plan is printed
# with --dry-run. The shell install path is the one that used to be wrong.
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
installer="$root/install.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1" "$2"; fi; }

run_plan() {
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" "$installer" --dry-run --no-dotfiles "$@" 2>&1
}

echo "dry-run plan"

mkdir -p "$tmp/home"
out=$(run_plan --full)
contains "full installs the session entry" "$out" "/usr/share/wayland-sessions/maria-padilha.desktop"
contains "full installs the user units" "$out" "/usr/lib/systemd/user"
contains "the shell is installed with the absolute config dir" "$out" \
    "PADILHA_QSCONFDIR=/etc/xdg/quickshell/caelestia"

out=$(run_plan --rice)
if printf '%s' "$out" | grep -q 'wayland-sessions'; then
    bad "rice leaves the session entry alone"
else
    ok "rice leaves the session entry alone"
fi

if [ -e "$tmp/config" ]; then
    bad "dry-run writes nothing under XDG_CONFIG_HOME"
else
    ok "dry-run writes nothing under XDG_CONFIG_HOME"
fi

echo "arguments"

if "$installer" --nonsense >/dev/null 2>&1; then
    bad "unknown options are refused"
else
    [ $? -eq 2 ] && ok "unknown options are refused" || bad "unknown options exit 2"
fi

if "$installer" --editor ed >/dev/null 2>&1; then
    bad "an unknown editor is refused"
else
    ok "an unknown editor is refused"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
