# Promo-window agents

`promo-agents` runs at most one headless DSH agent at a time inside a configured
discount window. Repositories are picked round-robin; the next project starts
after the current agent exits. The scheduler stops the agent before the window
closes and leaves the work on a branch for review. It never pushes `main` and
never merges.

The scheduler does not invent work. The coordinator (the main DSH session,
briefed by the user) owns the queues; an empty queue means the window idles.
Maintenance rounds are opt-in (`maintenance.enabled`).

This is a prototype. The window schedule is configuration, not a hardcoded
guess; verify DeepSeek's current discount hours before using it.

## Setup

1. Copy the example:

   ```sh
   mkdir -p ~/.config/lilith/agents/queue/padilha-de
   mkdir -p ~/.config/lilith/agents/queue/padilha-dotfiles
   cp tools/promo-agents.example.toml ~/.config/lilith/agents.toml
   ```

2. Edit the windows, timezone, stop margin, and repository paths. The supplied
   times are placeholders.

3. Queue the first task. A task is a focused Markdown brief, not a vague goal:

   ```sh
   tools/promo-agents --config ~/.config/lilith/agents.toml \
       --enqueue padilha-de <<'EOF'
   # Fix the keyboard-backlight restore

   The panel brightness is lost after a reboot. Reproduce it, find where
   systemd-backlight saves the value, fix the restore path, and add a test.
   Do not touch the wallpaper engine.
   EOF
   ```

   `--title "…"` overrides the heading; `--body "…"` replaces stdin. The file
   lands in the repository's queue, oldest name first.

4. Check the configuration without changing anything:

   ```sh
   tools/promo-agents --dry-run
   tools/promo-agents --status
   ```

5. Run one tick manually:

   ```sh
   tools/promo-agents --once
   ```

The first `dsh --profile headless` use auto-initializes
`~/.dsh/profiles/headless` from the shipped template; its credentials live in
`~/.dsh`. The service runs as the same user so it can use them.

## Coordinator

The coordinator decides *what* the agents do; the scheduler decides *when* and
*which repository*. In practice the main DSH session turns the user's direction
into one brief per repository:

```sh
tools/promo-agents --enqueue padilha-de --title "Audit the installer"
tools/promo-agents --enqueue padilha-dotfiles --title "Check the tree colours"
```

Queues are FIFO and repositories alternate: one padilha-de task, then one
padilha-dotfiles task, then back. A repository with an empty queue is skipped,
so the other can take consecutive rounds. If nothing is worth doing, leave the
queues empty; the scheduler will not manufacture rounds to fill the window.

## What a tick does

- If no window is active, or the stop margin has been reached, stops the
  running agents and finalizes their work.
- Otherwise, for each repo with a queued task and no running agent:
  - refuses a dirty checkout;
  - creates a git worktree under
    `~/.local/state/lilith/agents/worktrees/<repo>/...` on branch
    `agent/<timestamp>-<slug>`;
  - starts `dsh --profile headless` with a repo-owner prompt and the task;
  - records the PID, worktree, branch, and log.
- When an agent exits, or when it is stopped at the margin, it runs the repo's
  configured tests, commits any changes to the agent branch, optionally pushes
  the branch (`push = true`), moves the task to `done/`, and records the result.
- If the queue is empty and `maintenance.enabled` is true, it starts a
  maintenance round: review the project, tests, docs, and recent changes, then
  make one concrete improvement. The agent may decide there is nothing worth
  changing and stop having committed nothing; it is not asked to produce
  filler. With `maintenance.enabled = false` (the example default) an empty
  queue simply idles. `max_rounds_per_window = 0` keeps rounds going until the
  stop margin; `min_round_seconds` prevents a fast failure from spinning.

No PR is opened automatically. The coordinator reviews the branch.

### Stopping and state

- At the margin the scheduler sends `SIGTERM` to the agent's process group, waits
  up to `schedule.stop_grace_seconds` (default 20), and only then sends
  `SIGKILL`, so a checkpoint is not cut short.
- Each running record stores the boot id. A record left by a previous boot is
  finalized but never signalled: after a reboot that PID may belong to
  something else.
- A record without a usable PID is never passed to `killpg`, and a failed
  launch (missing checkout, dirty tree, worktree error) does not consume a
  maintenance round.
- `tools/promo-agents --dry-run` reads state and prints the decision without
  writing a state file, a log, a worktree, or a branch.

`tests/cli/promo-agents.sh` covers these promises; it runs as part of
`tests/all.sh` and replaces `dsh` with `sh`, so it needs no network or API key.

## Timer

The systemd **user** bus is not available in the current LightDM session, so use
a system timer (or run the tick from cron). A system unit has to run as the
same user that owns `~/.dsh` and the checkouts:

```ini
# /etc/systemd/system/lilith-agents.service
[Unit]
Description=Lilith promo-window agent tick
After=network-online.target

[Service]
Type=oneshot
User=machine
Environment=HOME=/home/machine
WorkingDirectory=/home/machine/Códigos/lilith/lilith-de
ExecStart=/usr/bin/python3 /home/machine/Códigos/lilith/lilith-de/tools/promo-agents --once
```

```ini
# /etc/systemd/system/lilith-agents.timer
[Unit]
Description=Tick the Lilith promo-window scheduler

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now lilith-agents.timer
```

Adjust the hardcoded paths before installing. A plain `while` loop calling
`tools/promo-agents --once` every five minutes also works; the state lock
prevents overlapping ticks. Use `tools/promo-agents --daemon` when the next
repository should start the moment the previous agent exits: it ticks every
30 seconds until stopped and uses the same lock.

## Safety rules

- Keep `push = false` until the branches have been reviewed a few times; the
  worktrees survive for inspection either way.
- Keep `stop_margin_minutes` generous. The agent is asked to commit before it
  stops, but a hard kill can leave an uncommitted worktree.
- The API credentials live outside the repositories. Never put them in a task,
  a prompt, or a commit.
- The service does not run when the schedule is unknown: an empty or malformed
  window list is a configuration error.
- Only one agent runs at a time, and only one repository is launched per
  scheduler tick. Repositories rotate; the next one starts after the current
  agent exits. This keeps the 7 GB laptop out of a three-agent memory race.
- Do not queue a task to keep an agent busy. If there is nothing worth doing,
  leave the queue empty and let the window idle.
