# Lua brightness spike

Status: **experiment**, not wired into the session and not merged. Nothing here
writes the backlight.

## What it tests

`bin/padilha-brightness` is the only always-resident Python helper. This spike
answers two questions before considering a port:

1. Can pure Lua 5.5 reproduce the curve exactly?
2. How much resident memory would an equivalent idle process use?

## Results (2026-11-25)

| check | result |
| --- | --- |
| curve, every minute of a day | **1440 minutes, 0 mismatches** |
| Lua curve process (PSS) | **0.43 MB** |
| Python daemon (PSS) | **4.92 MB** |
| Lua full daemon, lua-posix + lfs (PSS / RSS) | **1.47 MB / 3.86 MB** |
| always-on saving | **~3.45 MB** |

The curve comparison imports `target_percent()` from the Python script and
compares it with the Lua output for local time on 2026-11-25. The Lua side
implements Python's half-to-even `round()` so the comparison is about the
curve, not the rounding mode.

## Full dry-run daemon

`daemon.lua` mirrors the Python state machine: poll, apply the curve, detect a
manual change and hold it for four hours, persist `override_until` /
`last_applied`, and take a single-instance lock. `scenario.sh` drives it with
fake sysfs and a fake `brightnessctl`, so the real backlight is never touched.

Scenario result:

- initial run applies the curve target (93)
- a manual change to 30 while the daemon is running is held, with
  `override_until` in the future
- after expiring the hold, the daemon applies the curve target again (93)
- the full daemon idles at **1.47 MB PSS** (3.86 MB RSS) with `lua-posix` and
  `lua-filesystem` loaded; it uses `posix.sleep`/`nanosleep`, `lfs.dir` and a
  POSIX record lock on `brightness.state.lock`

## Run

```sh
lua spikes/lua-brightness/brightness.lua --table
lua spikes/lua-brightness/brightness.lua --target 1795000000
lua spikes/lua-brightness/brightness.lua --dry-run 5
python3 spikes/lua-brightness/compare.py
bash spikes/lua-brightness/scenario.sh
```

PSS measurement:

```sh
lua spikes/lua-brightness/brightness.lua --dry-run 60 >/dev/null &
lua_pid=$!
sleep 1
awk '/^Pss:/{s+=$2} END{printf "lua PSS %.2f MB\n", s/1024}' /proc/$lua_pid/smaps_rollup
kill $lua_pid

python_pid=$(pgrep -f 'python3 .*bin/padilha-brightness' | head -1)
awk '/^Pss:/{s+=$2} END{printf "python PSS %.2f MB\n", s/1024}' /proc/$python_pid/smaps_rollup
```

## Day-long shadow

`--observe` logs `now,current,target,observe:<override_until>` every poll and
never writes the backlight, takes the lock, or touches the state file. Run it
beside the Python daemon for a day:

```sh
mkdir -p ~/.config/systemd/user
cp spikes/lua-brightness/padilha-brightness-observe.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now padilha-brightness-observe.service
tail -n 3 ~/.local/state/padilha/brightness-observe.csv
```

After a day:

```sh
systemctl --user disable --now padilha-brightness-observe.service
wc -l ~/.local/state/padilha/brightness-observe.csv
```

When `override_until` is not in the future, `current` and `target` should agree
within 1; mismatches are the bug list to fix before swapping.

## Before swapping

- keep `bin/padilha-brightness` as the reference until the shadow day passes;
- when swapping, change the session launch in `hypr/hyprland/execs.lua` and keep
  the Python script for one release as a fallback.

No Python package is removed either way (104 packages depend on it), so the
decision is about runtime memory and long-term language consistency, not image
size.
