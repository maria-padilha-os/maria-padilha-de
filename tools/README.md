# Promo-window agents

`promo-agents` starts one headless DSH agent per repository inside a configured
discount window, stops it before the window closes, and leaves the work on a
branch for review. It never pushes `main` and never merges.

This is a prototype. The window schedule is configuration, not a hardcoded
guess; verify DeepSeek's current discount hours before using it.

## Setup

1. Copy the example:

   ```sh
   mkdir -p ~/.config/padilha/agents/queue/padilha-de
   mkdir -p ~/.config/padilha/agents/queue/padilha-dotfiles
   cp tools/promo-agents.example.toml ~/.config/padilha/agents.toml
   ```

2. Edit the windows, timezone, stop margin, and repository paths. The supplied
   times are placeholders.

3. Put task files in each queue directory. A task is a focused Markdown brief,
   not a vague goal:

   ```markdown
   # Fix the keyboard-backlight restore

   The panel brightness is lost after a reboot. Reproduce it, find where
   systemd-backlight saves the value, fix the restore path, and add a test.
   Do not touch the wallpaper engine.
   ```

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

## What a tick does

- If no window is active, or the stop margin has been reached, stops the
  running agents and finalizes their work.
- Otherwise, for each repo with a queued task and no running agent:
  - refuses a dirty checkout;
  - creates a git worktree under
    `~/.local/state/padilha/agents/worktrees/<repo>/...` on branch
    `agent/<timestamp>-<slug>`;
  - starts `dsh --profile headless` with a repo-owner prompt and the task;
  - records the PID, worktree, branch, and log.
- When an agent exits, or when it is stopped at the margin, it runs the repo's
  configured tests, commits any changes to the agent branch, optionally pushes
  the branch (`push = true`), moves the task to `done/`, and records the result.
- If the queue is empty and `maintenance.enabled` is true, the agent does not
  idle. It starts a maintenance round: review the project, tests, docs, and
  rough edges, then make one concrete optimization/polish or write a
  `PROPOSALS.md` with next steps. Set `max_rounds_per_window = 0` to keep going
  until the stop margin; `min_round_seconds` prevents a fast failure from
  spinning.

No PR is opened automatically. The coordinator reviews the branch.

## Timer

The systemd **user** bus is not available in the current LightDM session, so use
a system timer (or run the tick from cron). A system unit has to run as the
same user that owns `~/.dsh` and the checkouts:

```ini
# /etc/systemd/system/padilha-agents.service
[Unit]
Description=Padilha promo-window agent tick
After=network-online.target

[Service]
Type=oneshot
User=machine
Environment=HOME=/home/machine
WorkingDirectory=/home/machine/Códigos/padilha/padilha-de
ExecStart=/usr/bin/python3 /home/machine/Códigos/padilha/padilha-de/tools/promo-agents --once
```

```ini
# /etc/systemd/system/padilha-agents.timer
[Unit]
Description=Tick the Padilha promo-window scheduler

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now padilha-agents.timer
```

Adjust the hardcoded paths before installing. A plain `while` loop calling
`tools/promo-agents --once` every five minutes also works; the state lock
prevents overlapping ticks.

## Safety rules

- Keep `push = false` until the branches have been reviewed a few times; the
  worktrees survive for inspection either way.
- Keep `stop_margin_minutes` generous. The agent is asked to commit before it
  stops, but a hard kill can leave an uncommitted worktree.
- The API credentials live outside the repositories. Never put them in a task,
  a prompt, or a commit.
- The service does not run when the schedule is unknown: an empty or malformed
  window list is a configuration error.
- One agent per repository is the default. More than two DSH agents on this
  7 GB laptop will compete for memory; the per-repo lock is deliberate.
