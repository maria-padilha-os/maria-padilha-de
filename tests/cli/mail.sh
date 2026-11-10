#!/usr/bin/env bash
# Contract tests for the optional email app: the Mail launcher entry, the
# mailto: handler, the Office/Mail package group, and the rule that Thunderbird
# is never a hard dependency of the base package.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
mail="$root/bin/padilha-mail"
entry="$root/share/applications/padilha-mail.desktop"
apps="$root/packaging/apps.list"
pkgbuild="$root/packaging/PKGBUILD"
installer="$root/install.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

echo "launcher entry"

check "the handler passes sh -n" "sh -n '$mail'"
check "the handler is executable" "test -x '$mail'"
check "the desktop entry exists" "test -s '$entry'"
check "the entry launches padilha-mail" "grep -qx 'Exec=padilha-mail %u' '$entry'"
check "the entry registers mailto:" "grep -qx 'MimeType=x-scheme-handler/mailto;' '$entry'"
check "the entry is an application" "grep -qx 'Type=Application' '$entry'"
check "the entry names a mail icon" "grep -qx 'Icon=thunderbird' '$entry'"

echo "handler"

fake="$tmp/fake"
mkdir -p "$fake"
cat > "$fake/thunderbird" <<'SH'
#!/bin/sh
printf '%s' "$*" > "${THUNDERBIRD_ARGS:?}"
SH
chmod +x "$fake/thunderbird"

url='mailto:person@example.test?subject=hello%20there'
THUNDERBIRD_ARGS="$tmp/args" PADILHA_THUNDERBIRD="$fake/thunderbird" \
    "$mail" "$url" > "$tmp/mail.out" 2> "$tmp/mail.err"
status=$?
check "the handler launches Thunderbird" "[ $status -eq 0 ]" "exit $status: $(cat "$tmp/mail.err")"
check "the mailto: URI reaches Thunderbird unchanged" \
    "[ \"\$(cat '$tmp/args')\" = '$url' ]" "$(cat "$tmp/args" 2>/dev/null)"

rm -f "$tmp/args"
THUNDERBIRD_ARGS="$tmp/args" PADILHA_THUNDERBIRD="$fake/thunderbird" \
    "$mail" > "$tmp/mail-noarg.out" 2> "$tmp/mail-noarg.err"
status=$?
check "the launcher opens Thunderbird with no URI" \
    "[ $status -eq 0 ] && [ ! -s '$tmp/args' ]" "exit $status: $(cat "$tmp/mail-noarg.err")"

if "$mail" 'https://example.test/' > /dev/null 2> "$tmp/bad.err"; then
    bad "a non-mailto: argument is refused"
else
    [ $? -eq 2 ] && ok "a non-mailto: argument is refused" || bad "a non-mailto: argument exits 2"
fi
check "the refusal does not echo the argument" \
    "! grep -q 'https://example.test' '$tmp/bad.err'"

echo "clean fallback without Thunderbird"

# A PATH with only a stand-in notify-send: no thunderbird, flatpak, or snap.
notify="$tmp/notify"
mkdir -p "$notify"
cat > "$notify/notify-send" <<'SH'
#!/bin/sh
printf '%s' "$*" > "${NOTIFY_ARGS:?}"
SH
chmod +x "$notify/notify-send"

secret='mailto:person@example.test?subject=private-token&body=secret'
NOTIFY_ARGS="$tmp/notify.args" PATH="$notify" "$mail" "$secret" \
    > "$tmp/absent.out" 2> "$tmp/absent.err"
status=$?
check "the absent app exits 0" "[ $status -eq 0 ]" "exit $status: $(cat "$tmp/absent.err")"
check "the fallback sends a desktop notice" "grep -q 'Thunderbird is not installed' '$tmp/notify.args'"
check "the fallback does not log the URI or message" \
    "! grep -qiE 'private-token|secret|mailto:' '$tmp/notify.args' '$tmp/absent.out' '$tmp/absent.err'"

# With no notifier either, it still exits cleanly and prints one short notice.
empty="$tmp/empty"
mkdir -p "$empty"
PATH="$empty" "$mail" "$secret" > "$tmp/quiet.out" 2> "$tmp/quiet.err"
status=$?
check "the fallback exits 0 without a notifier" "[ $status -eq 0 ]" "exit $status"
check "the fallback explains itself on stderr" "grep -q 'Thunderbird is not installed' '$tmp/quiet.err'"
check "the quiet fallback leaks no URI" "! grep -qiE 'private-token|secret|mailto:' '$tmp/quiet.err' '$tmp/quiet.out'"

echo "package and installer"

check "the app catalogue lists the Office/Mail group" \
    "grep -qE '^office-mail[[:space:]]+thunderbird[[:space:]]' '$apps'"

if /usr/bin/python3 - "$pkgbuild" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()


def array(name):
    match = re.search(rf"(?ms)^{re.escape(name)}=\((.*?)^\)", text)
    if not match:
        raise AssertionError(f"missing {name} array")
    values = []
    for raw in match.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        values.append(line.strip("'\""))
    return values


depends = [value.split(":", 1)[0] for value in array("depends")]
optdepends = array("optdepends")
if "thunderbird" in depends:
    raise AssertionError("thunderbird must not be a hard dependency")
if not any(value.split(":", 1)[0] == "thunderbird" for value in optdepends):
    raise AssertionError("thunderbird is missing from optdepends")
if "padilha-mail" not in text:
    raise AssertionError("PKGBUILD does not install padilha-mail")
if "share/applications/padilha-mail.desktop" not in text:
    raise AssertionError("PKGBUILD does not install the desktop entry")
PY
then
    ok "the package keeps Thunderbird optional"
else
    bad "the package keeps Thunderbird optional"
fi

# The installer must not add Thunderbird to the default plan, but must offer it
# in the Office/Mail group. A fake pacman reports every package missing; the
# installer is still in --dry-run, so nothing is executed.
fakebin="$tmp/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/pacman" <<'SH'
#!/bin/sh
exit 1
SH
chmod +x "$fakebin/pacman"
mkdir -p "$tmp/home" "$tmp/xdg-config"

run_plan() {
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_CONFIG_DIRS="$tmp/xdg-config" \
        PATH="$fakebin:$PATH" "$installer" --dry-run --no-dotfiles "$@" 2>&1
}

out=$(run_plan --full)
pacman_line=$(printf '%s\n' "$out" | grep -E '^\+ sudo pacman -S --needed ' | head -n 1 || true)
if printf '%s' "$pacman_line" | grep -q thunderbird; then
    bad "the default plan keeps Thunderbird out" "$pacman_line"
else
    ok "the default plan keeps Thunderbird out"
fi
if printf '%s' "$out" | grep -q '/usr/share/applications/padilha-mail.desktop'; then
    ok "the default plan still installs the Mail entry"
else
    bad "the default plan still installs the Mail entry" "$out"
fi

out=$(run_plan --full --with-office-mail)
pacman_line=$(printf '%s\n' "$out" | grep -E '^\+ sudo pacman -S --needed ' | head -n 1 || true)
if printf '%s' "$pacman_line" | grep -q thunderbird; then
    ok "the Office/Mail flag adds Thunderbird"
else
    bad "the Office/Mail flag adds Thunderbird" "$pacman_line"
fi
if printf '%s' "$out" | grep -q '/usr/share/applications/padilha-mail.desktop'; then
    ok "the Office/Mail flag keeps the Mail entry"
else
    bad "the Office/Mail flag keeps the Mail entry" "$out"
fi

out=$(run_plan --rice --office-mail)
pacman_line=$(printf '%s\n' "$out" | grep -E '^\+ sudo pacman -S --needed ' | head -n 1 || true)
if printf '%s' "$pacman_line" | grep -q thunderbird; then
    ok "the Office/Mail alias works for --rice"
else
    bad "the Office/Mail alias works for --rice" "$pacman_line"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
