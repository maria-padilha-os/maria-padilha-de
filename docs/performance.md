---
layout: default
title: Performance budget
---

# Performance budget

The shell starts with the session and then stays resident all day. This page
records the budget for that lifetime, the reference measurement, and the
checks that keep a later change from quietly spending more CPU or memory.

The budget is measured on the reference machine with Quickshell's offscreen
platform. It is the full shell QML tree — services, bindings, timers, loaders
and animations — with a small panel-window shim in place of the real Wayland
layer-shell surfaces. That makes the number reproducible on a machine without
a spare compositor while still exercising the code that runs at startup and
at idle. It does not composite pixels and does not replace a manual check on a
live session.

## Reference measurement

Recorded in [`tests/performance/baseline.json`](https://github.com/maria-padilha-os/maria-padilha-de/blob/main/tests/performance/baseline.json):

| Metric | Baseline |
| --- | ---: |
| Startup to `Configuration Loaded` | 1361 ms |
| Idle CPU (shell process) | 1.2 % |
| Resident memory | 277 MB |
| QML warning classes | 21 |

Reference machine: Manjaro Linux, kernel `7.3.0-rc6-1-MANJARO`, x86-64,
Quickshell 0.3.2 (`quickshell-git`), reduced motion off, offscreen Qt platform.
The startup number is the fastest of three runs; CPU and RSS are the median of
the same runs after a 1.5 s settle and a 2.5 s idle sample.

The QML warnings baseline includes the installed Caelestia plugin and two
missing per-user fixture files (`.face` and `scheme.json`). Those signatures are
recorded so a *new* QML warning class fails the check; they are not a claim
that the current log is clean. When `build/qml` exists the harness uses the
checkout's own plugin, as `padilha-session` does, which removes the
plugin-version warnings.

## Budget

`tests/performance/measure.py` compares a fresh run with the baseline:

- startup: at most **1.75× baseline + 1000 ms**;
- idle CPU: at most **2× baseline + 1 percentage point**;
- RSS: at most **1.25× baseline + 32 MiB**;
- every QML warning class must be in the baseline, and an existing class may
  not grow past **2× its baseline count + 1**.

The margins are deliberately wider than run-to-run noise. A new warning class
fails immediately because that is a code change, not load noise.

## Running and recording

```sh
bash tests/performance/run.sh
```

This runs the static contracts and the offscreen measurement. Set
`PADILHA_PERF_REPETITIONS=1` for a quicker single run while iterating.

After an intentional performance change, record a new baseline and review the
diff before committing:

```sh
/usr/bin/python3 tests/performance/measure.py --record --repetitions 3
```

Only re-record when the change is understood. A higher baseline should come
with a measured reason, not with "the test was in the way".

## What the checks cover

`tests/performance/check.py` fails on the patterns that caused avoidable work:

- a new sub-minute repeating `Timer` that is always running;
- a second media position poll outside the `Players` singleton (the bar,
  popout, dashboard and lock screen read the same timer now);
- a looping `Animation.Infinite` or `FrameAnimation` in a file that does not
  consult `Accessibility.reducedMotion`.

The static checks also assert that the baseline and this page exist.

## Changes made for this budget

- Media position updates moved from four per-surface timers to one timer in
  the `Players` service.
- Night light no longer wakes every minute; it schedules the next hour and
  reacts to config changes.
- Weather's relative-time tick only runs when there is data, and uptime moved
  from 15 s to 60 s, matching the minute resolution it displays.
- Clipboard history's watch safety net moved from 1.5 s to 5 s, and
  notification ages from 5 s to 30 s.
- Looping wave, spinner, pulse and recording animations stop under
  `PADILHA_REDUCED_MOTION=1` instead of spinning with a zero duration.
- No accessibility, focus, authentication, lock or security feature was
  disabled to meet the budget.

## Limits

The measurement is a development budget, not a frame-time profiler. It does
not include the compositor, GPU work, or other session processes. For a live
check, use `top`/`ps` on the `qs` process and the manual keyboard and
screen-reader checklists in [Accessibility](accessibility.md).
