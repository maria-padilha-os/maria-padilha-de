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
| Lua full daemon (PSS / RSS) | **0.46 MB / 2.77 MB** |
| always-on saving | **~4.5 MB** |

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

- initial run applies the curve target (94)
- a manual change to 30 while the daemon is running is held, with
  `override_until` in the future
- after expiring the hold, the daemon applies the curve target again (94)
- the full daemon idles at **0.46 MB PSS** (2.77 MB RSS)

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

## Remaining before production

The dry-run daemon covers the behaviour; the remaining work is:

- replace `os.execute("sleep")` and the directory lock with `lua-posix`
  (`posix.sleep`, `posix.fcntl`). `lua-posix` is packaged in `extra`, but it
  needs a `sudo pacman -S lua-posix` (no passwordless sudo here).
- replace the `ls` used to list `/sys/class/backlight` with `lua-filesystem`
  or `posix` so the poll does not spawn a shell.
- run the Lua daemon beside the Python one for a full day before swapping;
  keep the Python script as the reference until then.

No Python package is removed either way (104 packages depend on it), so the
decision is about runtime memory and long-term language consistency, not image
size.
