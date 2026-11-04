#!/usr/bin/env bash
# Contract tests for tools/promo-agents. The scheduler spends money and runs
# detached agents, so the promises are narrow: it never starts outside a
# window, never signals a PID it does not own, and never loses what an agent
# produced. The `dsh` call is replaced with `sh` so the suite is offline.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
agents="$root/tools/promo-agents"
tmp=$(mktemp -d)
pids=()

cleanup() {
    for pid in ${pids[@]+"${pids[@]}"}; do
        kill -9 "$pid" 2>/dev/null
    done
    rm -rf "$tmp"
}
trap cleanup EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# A clean checkout with one commit: worktrees need a HEAD to branch from.
mkdir -p "$tmp/repo" "$tmp/queue"
git -C "$tmp/repo" init -q -b main
git -C "$tmp/repo" config user.email tests@padilha.invalid
git -C "$tmp/repo" config user.name "Padilha tests"
printf 'hello\n' > "$tmp/repo/README.md"
git -C "$tmp/repo" add -A
git -C "$tmp/repo" commit -qm "init"

read -r inside_start inside_end past_start past_end latest_start latest_end < <(
    python3 - <<'PY'
from datetime import datetime, timedelta, timezone

now = datetime.now(timezone.utc)

def hhmm(when):
    return when.strftime("%H:%M")

print(
    hhmm(now - timedelta(hours=1)), hhmm(now + timedelta(hours=2)),
    hhmm(now - timedelta(hours=3)), hhmm(now - timedelta(hours=2)),
    hhmm(now - timedelta(hours=1)), hhmm(now + timedelta(minutes=10)),
)
PY
)

# write_config NAME START END ENABLED MAX_ROUNDS COMMAND_LITERAL
write_config() {
    local name=$1 start=$2 end=$3 enabled=$4 max_rounds=$5 command=$6
    cat > "$tmp/$name.toml" <<EOF
[schedule]
timezone = "UTC"
stop_margin_minutes = 25
stop_grace_seconds = 2

[[schedule.windows]]
days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
start = "$start"
end = "$end"

[agent]
command = $command

[maintenance]
enabled = $enabled
max_rounds_per_window = $max_rounds
min_round_seconds = 0

[repos."demo"]
path = "$tmp/repo"
queue = "$tmp/queue"
EOF
}

write_config inside "$inside_start" "$inside_end" true 0 '["sh", "-c", "printf ran > agent-ran.txt"]'
write_config outside "$past_start" "$past_end" true 0 '["sh", "-c", "exit 0"]'
write_config late "$latest_start" "$latest_end" true 0 '["sh", "-c", "exit 0"]'
write_config no-maintenance "$inside_start" "$inside_end" false 0 '["sh", "-c", "exit 0"]'
write_config limited "$inside_start" "$inside_end" true 1 '["sh", "-c", "printf ran > agent-ran.txt"]'

echo "usage"

out=$("$agents" --help 2>&1)
if [ $? -eq 0 ]; then ok "--help exits 0"; else bad "--help exits 0"; fi
if printf '%s' "$out" | grep -q -- '--once'; then
    ok "--help documents --once"
else
    bad "--help documents --once" "$out"
fi

"$agents" --config "$tmp/missing.toml" > /dev/null 2>"$tmp/err"
status=$?
if [ "$status" -eq 2 ] && grep -q "no config" "$tmp/err"; then
    ok "a missing config exits 2 with a message"
else
    bad "a missing config exits 2 with a message" "$(cat "$tmp/err")"
fi

cat > "$tmp/empty-windows.toml" <<'EOF'
[schedule]
windows = []
EOF
"$agents" --config "$tmp/empty-windows.toml" > /dev/null 2>"$tmp/err"
status=$?
if [ "$status" -ne 0 ] && grep -q "windows is empty" "$tmp/err"; then
    ok "an empty window list is a configuration error"
else
    bad "an empty window list is a configuration error" "$(cat "$tmp/err")"
fi

cat > "$tmp/bad-clock.toml" <<'EOF'
[schedule]
[[schedule.windows]]
start = "25:00"
end = "26:00"
EOF
"$agents" --config "$tmp/bad-clock.toml" > /dev/null 2>"$tmp/err"
status=$?
if [ "$status" -ne 0 ] && grep -q "not HH:MM" "$tmp/err"; then
    ok "a malformed clock is refused"
else
    bad "a malformed clock is refused" "$(cat "$tmp/err")"
fi

cat > "$tmp/bad-day.toml" <<'EOF'
[schedule]
[[schedule.windows]]
days = ["funday"]
start = "10:00"
end = "11:00"
EOF
"$agents" --config "$tmp/bad-day.toml" > /dev/null 2>"$tmp/err"
status=$?
if [ "$status" -ne 0 ] && grep -q "unknown day" "$tmp/err"; then
    ok "an unknown day is refused"
else
    bad "an unknown day is refused" "$(cat "$tmp/err")"
fi

echo "windows"

out=$("$agents" --config "$tmp/outside.toml" --state-dir "$tmp/state-outside" --dry-run 2>&1)
if printf '%s' "$out" | grep -q "outside a discount window"; then
    ok "outside a window, nothing starts"
else
    bad "outside a window, nothing starts" "$out"
fi
if [ ! -e "$tmp/state-outside/state.json" ] && [ ! -e "$tmp/state-outside/agents.log" ]; then
    ok "a dry run writes no state"
else
    bad "a dry run writes no state"
fi

out=$("$agents" --config "$tmp/late.toml" --state-dir "$tmp/state-late" --dry-run 2>&1)
if printf '%s' "$out" | grep -q "inside the stop margin"; then
    ok "the stop margin is respected"
else
    bad "the stop margin is respected" "$out"
fi

out=$("$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-dry" --dry-run 2>&1)
if printf '%s' "$out" | grep -q "would start demo"; then
    ok "inside a window, an empty queue starts a maintenance round"
else
    bad "inside a window, an empty queue starts a maintenance round" "$out"
fi
if printf '%s' "$out" | grep -q "maintenance round 1"; then
    ok "the maintenance prompt is the first round"
else
    bad "the maintenance prompt is the first round" "$out"
fi

out=$("$agents" --config "$tmp/no-maintenance.toml" --state-dir "$tmp/state-dry" --dry-run 2>&1)
if printf '%s' "$out" | grep -q "queue empty (maintenance disabled)"; then
    ok "maintenance can be disabled"
else
    bad "maintenance can be disabled" "$out"
fi

printf '# Fix the widget\n\nBody.\n' > "$tmp/queue/001-fix.md"
out=$("$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-dry" --status 2>&1)
if printf '%s' "$out" | grep -q "demo: queued (001-fix.md)"; then
    ok "status names the queued task"
else
    bad "status names the queued task" "$out"
fi
rm -f "$tmp/queue/001-fix.md"

echo "safety"

# A record left by a previous boot must never be signalled: the PID may now
# belong to something else entirely.
sleep 60 &
victim=$!
pids+=("$victim")
mkdir -p "$tmp/state-boot"
python3 - "$tmp/state-boot/state.json" "$victim" <<'PY'
import json
import sys

path, pid = sys.argv[1], int(sys.argv[2])
json.dump({
    "running": {"demo": {
        "pid": pid,
        "boot": "00000000-0000-0000-0000-000000000000",
        "worktree": "/nonexistent",
        "branch": "agent/stale",
        "task": "",
        "title": "stale",
    }},
    "finished": [],
}, open(path, "w"))
PY
"$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-boot" --stop > /dev/null 2>&1
status=$?
if [ "$status" -eq 0 ] && kill -0 "$victim" 2>/dev/null; then
    ok "a PID from an earlier boot is not signalled"
else
    bad "a PID from an earlier boot is not signalled"
fi
if grep -q "earlier boot" "$tmp/state-boot/agents.log"; then
    ok "the stale record is reported"
else
    bad "the stale record is reported"
fi

# pid 0 must never reach killpg: that would signal the scheduler's own group.
# Run the scheduler in its own process group so a regression kills only it.
mkdir -p "$tmp/state-zero"
python3 - "$tmp/state-zero/state.json" <<'PY'
import json
import sys

json.dump({
    "running": {"demo": {
        "pid": 0,
        "worktree": "/nonexistent",
        "branch": "agent/zero",
        "task": "",
        "title": "zero",
    }},
    "finished": [],
}, open(sys.argv[1], "w"))
PY
python3 - "$agents" "$tmp/inside.toml" "$tmp/state-zero" <<'PY'
import os
import sys

os.setpgrp()
os.execv(sys.executable, [
    sys.executable, sys.argv[1], "--config", sys.argv[2],
    "--state-dir", sys.argv[3], "--stop",
])
PY
status=$?
if [ "$status" -eq 0 ]; then
    ok "a record without a pid never signals a process group"
else
    bad "a record without a pid never signals a process group" "exit $status"
fi

# A failed launch is not a maintenance round: the repository is missing.
name=missing-repo
cat > "$tmp/$name.toml" <<EOF
[schedule]
timezone = "UTC"
[[schedule.windows]]
start = "$inside_start"
end = "$inside_end"

[agent]
command = ["sh", "-c", "exit 0"]

[maintenance]
enabled = true
min_round_seconds = 0

[repos."demo"]
path = "$tmp/does-not-exist"
queue = "$tmp/queue"
EOF
"$agents" --config "$tmp/$name.toml" --state-dir "$tmp/state-missing" --once > /dev/null 2>&1
rounds=$(python3 -c "import json; print(json.load(open('$tmp/state-missing/state.json'))['maintenance']['demo']['rounds'])")
if [ "$rounds" -eq 0 ]; then
    ok "a failed launch does not consume a maintenance round"
else
    bad "a failed launch does not consume a maintenance round" "rounds=$rounds"
fi

echo "agent lifecycle"

"$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-run" --once > /dev/null 2>&1
pid=$(python3 -c "import json; print(json.load(open('$tmp/state-run/state.json'))['running']['demo']['pid'])")
for _ in $(seq 1 50); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
done
"$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-run" --stop > /dev/null 2>&1
branch=$(python3 -c "import json; print(json.load(open('$tmp/state-run/state.json'))['finished'][-1]['branch'])")
if [ -n "$branch" ] && git -C "$tmp/repo" rev-parse --verify -q "$branch" > /dev/null; then
    ok "the agent's branch survives the stop"
else
    bad "the agent's branch survives the stop" "$branch"
fi
ran=$(git -C "$tmp/repo" show "$branch:agent-ran.txt" 2>/dev/null)
if [ "$ran" = "ran" ]; then
    ok "the agent's work is committed before finalizing"
else
    bad "the agent's work is committed before finalizing" "$ran"
fi
if [ "$(python3 -c "import json; print(len(json.load(open('$tmp/state-run/state.json'))['running']))")" -eq 0 ]; then
    ok "stopping clears the running record"
else
    bad "stopping clears the running record"
fi

"$agents" --config "$tmp/limited.toml" --state-dir "$tmp/state-limit" --once > /dev/null 2>&1
pid=$(python3 -c "import json; print(json.load(open('$tmp/state-limit/state.json'))['running']['demo']['pid'])")
for _ in $(seq 1 50); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
done
"$agents" --config "$tmp/limited.toml" --state-dir "$tmp/state-limit" --stop > /dev/null 2>&1
out=$("$agents" --config "$tmp/limited.toml" --state-dir "$tmp/state-limit" --once 2>&1)
if printf '%s' "$out" | grep -q "maintenance limit reached (1)"; then
    ok "max_rounds_per_window caps the window"
else
    bad "max_rounds_per_window caps the window" "$out"
fi

printf '# Fix the widget\n\nBody.\n' > "$tmp/queue/002-fix.md"
"$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-task" --once > /dev/null 2>&1
pid=$(python3 -c "import json; print(json.load(open('$tmp/state-task/state.json'))['running']['demo']['pid'])")
for _ in $(seq 1 50); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
done
"$agents" --config "$tmp/inside.toml" --state-dir "$tmp/state-task" --stop > /dev/null 2>&1
if [ -z "$(find "$tmp/queue" -maxdepth 1 -name '*.md' -print -quit)" ] &&
   find "$tmp/queue/done" -name '*002-fix.md' -print -quit | grep -q .; then
    ok "a finished task moves to done/"
else
    bad "a finished task moves to done/" "$(find "$tmp/queue" -type f)"
fi
task_branch=$(python3 -c "import json; print(json.load(open('$tmp/state-task/state.json'))['finished'][-1]['branch'])")
if printf '%s' "$task_branch" | grep -q "fix-the-widget"; then
    ok "the task branch is named from the task title"
else
    bad "the task branch is named from the task title" "$task_branch"
fi

echo "one project at a time"

mkdir -p "$tmp/repo-one" "$tmp/repo-two" "$tmp/queue-one" "$tmp/queue-two"
for repo in repo-one repo-two; do
    git -C "$tmp/$repo" init -q -b main
    git -C "$tmp/$repo" config user.email tests@padilha.invalid
    git -C "$tmp/$repo" config user.name "Padilha tests"
    printf 'repo\n' > "$tmp/$repo/README.md"
    git -C "$tmp/$repo" add -A
    git -C "$tmp/$repo" commit -qm "init"
done
printf '# First task\n\nBody.\n' > "$tmp/queue-one/001-first.md"
printf '# Second task\n\nBody.\n' > "$tmp/queue-two/001-second.md"
cat > "$tmp/two-repos.toml" <<EOF
[schedule]
timezone = "UTC"
[[schedule.windows]]
start = "$inside_start"
end = "$inside_end"

[agent]
command = ["sh", "-c", "printf ran > agent-ran.txt"]

[maintenance]
enabled = false

[repos."one"]
path = "$tmp/repo-one"
queue = "$tmp/queue-one"

[repos."two"]
path = "$tmp/repo-two"
queue = "$tmp/queue-two"
EOF
"$agents" --config "$tmp/two-repos.toml" --state-dir "$tmp/state-two" --once > /dev/null 2>&1
first=$(git -C "$tmp/repo-one" branch --list 'agent/*' | wc -l)
second=$(git -C "$tmp/repo-two" branch --list 'agent/*' | wc -l)
if [ $((first + second)) -eq 1 ]; then
    ok "only one repository starts per --once"
else
    bad "only one repository starts per --once" "one=$first two=$second"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
