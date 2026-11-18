#!/usr/bin/env bash
# Contract tests for the update manager. Fake pacman and pkexec scripts record
# their arguments, so this suite never touches the real package database, the
# real policy agent, the battery or root.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "${3:-}"; fi; }

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$HOME" "$tmp/bin" "$tmp/power/BAT0" "$tmp/power/AC"
calls="$tmp/calls"
: > "$calls"

cat > "$tmp/bin/pacman" <<'SH'
#!/bin/sh
printf 'pacman %s\n' "$*" >> "${PADILHA_TEST_CALLS:?}"
case " $* " in
    *" -Qu "*)
        [ -n "${PADILHA_TEST_EMPTY:-}" ] && exit 0
        cat "${PADILHA_TEST_FIXTURES:?}/query.txt"
        exit 0
        ;;
    *" -Si "*)
        cat "${PADILHA_TEST_FIXTURES:?}/info.txt"
        exit 0
        ;;
    *" -Syu "*)
        printf 'fake pacman applied the update\n'
        exit "${FAKE_PACMAN_STATUS:-0}"
        ;;
    *)
        printf 'unexpected pacman arguments: %s\n' "$*" >&2
        exit 99
        ;;
esac
SH

cat > "$tmp/bin/pkexec" <<'SH'
#!/bin/sh
printf 'pkexec %s\n' "$*" >> "${PADILHA_TEST_CALLS:?}"
exec "$@"
SH
chmod 755 "$tmp/bin/pacman" "$tmp/bin/pkexec"

printf 'Battery\n' > "$tmp/power/BAT0/type"
printf '15\n' > "$tmp/power/BAT0/capacity"
printf 'Discharging\n' > "$tmp/power/BAT0/status"
printf 'Mains\n' > "$tmp/power/AC/type"
printf '0\n' > "$tmp/power/AC/online"

export PADILHA_PACMAN="$tmp/bin/pacman"
export PADILHA_UPDATE_ESCALATE="$tmp/bin/pkexec"
export PADILHA_UPDATE_POWER_SUPPLY="$tmp/power"
export PADILHA_TEST_CALLS="$calls"
export PADILHA_TEST_FIXTURES="$root/tests/updates/fixtures"

command="$root/bin/padilha-update"

echo "read-only check"

"$command" check --json > "$tmp/check.json" 2> "$tmp/check.err"
status=$?
check "check exits successfully" "[ $status -eq 0 ]" "$(cat "$tmp/check.err")"
if /usr/bin/python3 - "$tmp/check.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["count"] == 3, data
assert data["updates"][0]["name"] == "linux"
assert data["updates"][0]["oldVersion"] == "6.12.1-arch1-1"
assert data["updates"][0]["newVersion"] == "6.12.2-arch1-1"
assert data["updates"][0]["downloadBytes"] == 600 * 1024 * 1024
assert data["updates"][0]["downloadLabel"] == "600 MiB"
assert data["updates"][1]["newVersion"] == "1:24.3.1-1"
assert data["updates"][2]["ignored"] is True
assert data["downloadBytes"] >= 500 * 1024 * 1024
assert data["large"] is True
assert data["battery"]["present"] is True
assert data["battery"]["percent"] == 15
assert data["battery"]["onAc"] is False
assert "battery-low" in data["warnings"]
assert "not-on-ac-large" in data["warnings"]
PY
then
    ok "check reports versions, sizes, battery and warnings as JSON"
else
    bad "check reports versions, sizes, battery and warnings as JSON"
fi

check "check only runs pacman -Qu and -Si" "grep -q -- '-Qu' '$calls' && grep -q -- '-Si' '$calls'"
check "check never runs the upgrade or an escalation helper" "! grep -q -- '-Syu' '$calls' && ! grep -q '^pkexec' '$calls'"

if "$root/bin/padilha" update check --json > "$tmp/main-check.json" 2>/dev/null &&
    /usr/bin/python3 - "$tmp/check.json" "$tmp/main-check.json" <<'PY'
import json, sys
a = json.load(open(sys.argv[1], encoding="utf-8"))
b = json.load(open(sys.argv[2], encoding="utf-8"))
assert a["count"] == b["count"]
assert a["updates"] == b["updates"]
PY
then
    ok "padilha update check and padilha-update agree"
else
    bad "padilha update check and padilha-update agree"
fi

echo "confirmation and abort"

: > "$calls"
"$command" apply --json < /dev/null > "$tmp/abort-eof.json" 2> "$tmp/abort-eof.err"
status=$?
check "apply without confirmation exits non-zero" "[ $status -ne 0 ]"
if /usr/bin/python3 - "$tmp/abort-eof.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["aborted"] is True
assert data["ok"] is False
assert data["logPath"] == ""
PY
then
    ok "an empty reply is reported as an abort"
else
    bad "an empty reply is reported as an abort"
fi
check "an aborted apply never escalates" "! grep -q -- '-Syu' '$calls' && ! grep -q '^pkexec' '$calls'"

: > "$calls"
printf 'n\n' | "$command" apply --json > "$tmp/abort-no.json" 2> "$tmp/abort-no.err"
status=$?
check "answering n exits non-zero" "[ $status -ne 0 ]"
if /usr/bin/python3 - "$tmp/abort-no.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["aborted"] is True
assert data["ok"] is False
PY
then
    ok "answering n is reported as an abort"
else
    bad "answering n is reported as an abort"
fi
check "answering n never escalates" "! grep -q -- '-Syu' '$calls' && ! grep -q '^pkexec' '$calls'"

: > "$calls"
printf 'y\n' | "$command" apply --json > "$tmp/apply.json" 2> "$tmp/apply.err"
status=$?
check "answering y applies through the fake helper" "[ $status -eq 0 ]" "$(cat "$tmp/apply.err")"
if /usr/bin/python3 - "$tmp/apply.json" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ok"] is True
assert data["count"] == 3
assert data["logPath"]
assert os.path.isfile(data["logPath"])
assert os.path.basename(os.path.dirname(data["logPath"])) == "updates"
assert os.path.basename(os.path.dirname(os.path.dirname(data["logPath"]))) == "padilha"
PY
then
    ok "a confirmed apply writes a log under the Padilha state directory"
else
    bad "a confirmed apply writes a log under the Padilha state directory"
fi

log_path=$(/usr/bin/python3 - "$tmp/apply.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["logPath"])
PY
)
check "the log records the bounded pacman command" "grep -q -- '-Syu --noconfirm' '$log_path'"
check "the confirmed apply calls the existing helper once" "[ \"\$(grep -c '^pkexec' '$calls')\" -eq 1 ] && [ \"\$(grep -c '^pacman -Syu' '$calls')\" -eq 1 ]"
check "the log command prints the newest log path" "[ \"\$('$command' log 2>/dev/null)\" = '$log_path' ]"

echo "failure"

: > "$calls"
FAKE_PACMAN_STATUS=1 "$command" apply --yes --json > "$tmp/fail.json" 2> "$tmp/fail.err"
status=$?
check "a failed apply exits non-zero" "[ $status -ne 0 ]"
if /usr/bin/python3 - "$tmp/fail.json" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ok"] is False
assert data["status"] == 1
assert data["logPath"]
assert os.path.isfile(data["logPath"])
assert "fake pacman applied the update" in data["logTail"]
assert "exit status 1" in data["message"]
PY
then
    ok "a failure is reported with its log path and tail"
else
    bad "a failure is reported with its log path and tail"
fi

: > "$calls"
PADILHA_UPDATE_ESCALATE="$tmp/bin/missing-helper" "$command" apply --yes --json > "$tmp/missing-helper.json" 2> "$tmp/missing-helper.err"
status=$?
check "a missing privilege helper exits non-zero" "[ $status -ne 0 ]"
if /usr/bin/python3 - "$tmp/missing-helper.json" <<'PY'
import json, os, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ok"] is False
assert data["logPath"]
assert os.path.isfile(data["logPath"])
assert "Privilege helper" in data["message"]
assert "Privilege helper" in data["logTail"]
PY
then
    ok "a missing privilege helper still leaves a copyable log"
else
    bad "a missing privilege helper still leaves a copyable log"
fi
check "a missing privilege helper never runs the upgrade" "! grep -q -- '-Syu' '$calls'"

echo "no updates"

: > "$calls"
PADILHA_TEST_EMPTY=1 "$command" apply --yes --json > "$tmp/empty.json" 2> "$tmp/empty.err"
status=$?
check "an empty update list is not an error" "[ $status -eq 0 ]"
if /usr/bin/python3 - "$tmp/empty.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ok"] is True
assert data["count"] == 0
assert data["logPath"] == ""
PY
then
    ok "nothing is applied when the list is empty"
else
    bad "nothing is applied when the list is empty"
fi
check "an empty list never escalates" "! grep -q -- '-Syu' '$calls' && ! grep -q '^pkexec' '$calls'"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
