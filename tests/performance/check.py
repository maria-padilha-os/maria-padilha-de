#!/usr/bin/env python3
"""Static performance contracts for the shell.

The runtime budget in ``measure.py`` catches a slow build. These checks catch
the code patterns that make it slow in the first place: a new always-on
repeating timer, a second media position poll, or an infinite animation that
ignores reduced motion. They are intentionally narrow so normal animation and
timer work is not blocked.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SHELL = ROOT / "shell"
BASELINE = ROOT / "tests" / "performance" / "baseline.json"
DOCS = ROOT / "docs" / "performance.md"

failures: list[str] = []
checks = 0


def ok(message: str) -> None:
    global checks
    checks += 1
    print(f"  ok   {message}")


def bad(message: str, detail: str = "") -> None:
    global checks
    checks += 1
    failures.append(message)
    print(f"  FAIL {message}")
    if detail:
        print(f"       {detail}")


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{path.relative_to(ROOT)} is readable", str(error))
        return ""


def qml_files() -> list[Path]:
    return sorted(SHELL.rglob("*.qml"))


def timer_blocks(source: str) -> list[str]:
    """Return the text of each top-level ``Timer { ... }`` block."""
    blocks: list[str] = []
    lines = source.splitlines()
    index = 0
    while index < len(lines):
        if re.search(r"\bTimer\s*\{", lines[index]):
            depth = lines[index].count("{") - lines[index].count("}")
            block = [lines[index]]
            index += 1
            while index < len(lines) and depth > 0:
                block.append(lines[index])
                depth += lines[index].count("{") - lines[index].count("}")
                index += 1
            blocks.append("\n".join(block))
            continue
        index += 1
    return blocks


def check_polling_budget() -> None:
    offenders: list[str] = []
    for path in qml_files():
        source = read(path)
        for block in timer_blocks(source):
            if not re.search(r"^\s*repeat:\s*true\s*$", block, re.MULTILINE):
                continue
            if not re.search(r"^\s*running:\s*true\s*$", block, re.MULTILINE):
                continue
            interval = re.search(r"^\s*interval:\s*([0-9]+)\s*$", block, re.MULTILINE)
            if interval and int(interval.group(1)) < 60000:
                offenders.append(f"{path.relative_to(ROOT)} ({interval.group(1)} ms)")
    if offenders:
        bad("no sub-minute always-on repeating timers", ", ".join(offenders))
    else:
        ok("no sub-minute always-on repeating timers")


def check_media_timer() -> None:
    owners = []
    for path in qml_files():
        source = read(path)
        if "positionChanged()" in source:
            owners.append(path.relative_to(ROOT).as_posix())
    expected = ["shell/services/Players.qml"]
    if owners == expected:
        ok("one media position poll (Players singleton)")
    else:
        bad("one media position poll (Players singleton)", "found: " + ", ".join(owners) if owners else "found none")


def check_reduced_motion() -> None:
    looping = []
    frame = []
    for path in qml_files():
        source = read(path)
        relative = path.relative_to(ROOT).as_posix()
        if "loops: Animation.Infinite" in source:
            if "Accessibility.reducedMotion" not in source:
                looping.append(relative)
        if re.search(r"\bFrameAnimation\s*\{", source):
            if "Accessibility.reducedMotion" not in source:
                frame.append(relative)
    if looping:
        bad("looping animations stop under reduced motion", ", ".join(looping))
    else:
        ok("looping animations stop under reduced motion")
    if frame:
        bad("frame animations stop under reduced motion", ", ".join(frame))
    else:
        ok("frame animations stop under reduced motion")


def check_baseline() -> None:
    if not BASELINE.is_file():
        bad("performance baseline is recorded", str(BASELINE))
        return
    try:
        baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        bad("performance baseline is valid JSON", str(error))
        return
    required = ("schema", "reference_machine", "method", "startup_ms", "idle_cpu_percent", "rss_kb", "qml_warnings", "thresholds")
    missing = [key for key in required if key not in baseline]
    if missing:
        bad("performance baseline has the expected fields", ", ".join(missing))
        return
    if not isinstance(baseline["qml_warnings"], dict):
        bad("performance baseline records QML warning classes")
        return
    ok("performance baseline is recorded and readable")


def check_docs() -> None:
    if not DOCS.is_file():
        bad("performance budget is documented", str(DOCS))
        return
    source = DOCS.read_text(encoding="utf-8")
    markers = ("startup", "idle CPU", "memory", "QML warnings", "baseline.json", "tests/performance/run.sh", "reduced motion")
    missing = [marker for marker in markers if marker.lower() not in source.lower()]
    if missing:
        bad("performance budget is documented", ", ".join(repr(marker) for marker in missing))
    else:
        ok("performance budget is documented")


def main() -> int:
    check_polling_budget()
    check_media_timer()
    check_reduced_motion()
    check_baseline()
    check_docs()
    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
