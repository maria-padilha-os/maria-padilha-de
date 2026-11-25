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
| Lua idle process (PSS) | **0.43 MB** |
| Python daemon (PSS) | **4.92 MB** |
| always-on saving | **~4.5 MB** |

The curve comparison imports `target_percent()` from the Python script and
compares it with the Lua output for local time on 2026-11-25. The Lua side
implements Python's half-to-even `round()` so the comparison is about the
curve, not the rounding mode.

## Run

```sh
lua spikes/lua-brightness/brightness.lua --table
lua spikes/lua-brightness/brightness.lua --target 1795000000
lua spikes/lua-brightness/brightness.lua --dry-run 5
python3 spikes/lua-brightness/compare.py
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

## Not covered yet

The spike only covers the curve and the idle footprint. A production port also
needs:

- the state file and the 4-hour manual-override hold
- a single-instance lock (a directory lock or `posix.fcntl`)
- reading sysfs / `brightnessctl` and writing through `brightnessctl`
- an efficient sleep (`lua-posix`), instead of `os.execute("sleep 2")`

Those are mechanical, but they are where the behaviour and safety tests live.
`lua-posix` is packaged in `extra`; `lua-filesystem` or `posix` covers the sysfs
directory listing. No Python package is removed either way (104 packages depend
on it), so the decision is about runtime memory and long-term language
consistency, not image size.
