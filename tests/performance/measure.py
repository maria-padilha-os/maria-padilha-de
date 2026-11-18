#!/usr/bin/env python3
"""Measure the shell's offscreen startup, idle CPU, RSS and QML warnings.

The reference machine has no spare Wayland compositor, so this harness runs
the real shell object tree under Quickshell's offscreen platform with a tiny
panel-window shim. It exercises the services, bindings, timers, loaders and
animations that start with the shell; it does not composite pixels or talk to
the live compositor. See docs/performance.md for the method and limits.

Usage:
    measure.py [--record] [--root PATH] [--baseline FILE] [--repetitions N]
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_THRESHOLDS = {
    "startup_factor": 1.75,
    "startup_slack_ms": 1000,
    "idle_cpu_factor": 2.0,
    "idle_cpu_slack_percent": 1.0,
    "rss_factor": 1.25,
    "rss_slack_kb": 32768,
    "warning_count_factor": 2,
    "warning_count_slack": 1,
}

READY_MARKER = "Configuration Loaded"
FAILURE_MARKER = "Failed to load configuration"
WINDOW_ANCHOR = re.compile(
    r"^anchors\.(?:top|bottom|left|right|fill|horizontalCenter|verticalCenter):\s*(?:true|false)\s*$"
)
STUB_MARKERS = ("StubPanelWindow", "Region {", "ScreencopyView", "WlSessionLock", "IdleMonitor")


def write_stub_idle_inhibitor(shell: Path) -> None:
    """Replace the layer-shell inhibitor with an inert singleton for the run."""
    (shell / "services" / "IdleInhibitor.qml").write_text(
        """pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool enabled: false
    property var enabledSince: null
}
""",
        encoding="utf-8",
    )


def prepare_shell(source: Path, destination: Path) -> None:
    """Copy the shell and make its Wayland windows loadable offscreen."""
    shutil.copytree(source, destination)
    for path in destination.rglob("*.qml"):
        text = path.read_text(encoding="utf-8")
        text = text.replace("import Quickshell.Wayland", "import Shadow.Wayland")
        text = text.replace("PanelWindow {", "StubPanelWindow {")

        lines = []
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("WlrLayershell.") or WINDOW_ANCHOR.match(stripped):
                continue
            lines.append(line)
        text = "\n".join(lines) + "\n"

        if any(marker in text for marker in STUB_MARKERS) and "import Shadow.Wayland" not in text:
            lines = text.splitlines()
            for index, line in enumerate(lines):
                if line.startswith("import "):
                    lines.insert(index, "import Shadow.Wayland")
                    break
            text = "\n".join(lines) + "\n"

        path.write_text(text, encoding="utf-8")

    write_stub_idle_inhibitor(destination)


def compile_config(root: Path, env: dict[str, str]) -> bool:
    config = root / "share" / "init.lua"
    output = Path(env["XDG_CONFIG_HOME"]) / "padilha" / "shell.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            str(root / "bin" / "padilha-config"),
            "compile",
            "--config",
            str(config),
            "--out",
            str(output),
            "--no-schema",
            "--quiet",
        ],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if result.returncode != 0:
        print(result.stdout.strip(), file=sys.stderr)
    return result.returncode == 0


def proc_ticks(pid: int) -> int | None:
    try:
        stat = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")
    except OSError:
        return None
    fields = stat.rsplit(")", 1)[1].split()
    # fields[0] is state (field 3); utime/stime are fields 14/15.
    return int(fields[11]) + int(fields[12])


def proc_rss_kb(pid: int) -> int | None:
    try:
        status = Path(f"/proc/{pid}/status").read_text(encoding="utf-8")
    except OSError:
        return None
    match = re.search(r"^VmRSS:\s+(\d+)\s+kB$", status, re.MULTILINE)
    return int(match.group(1)) if match else None


def normalize_warning(line: str, scratch: Path) -> str | None:
    if not re.search(r"\bWARN\b", line):
        return None
    if "scene:" not in line and "qml:" not in line:
        return None

    line = re.sub(r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d(?:\.\d+)?\s+", "", line.strip())
    line = line.replace(str(scratch), "<tmp>")
    line = re.sub(r"@[^\s\[]+\[[^\]]*\]", "@<qml>", line)
    line = re.sub(r"file://\S+", "file://<path>", line)
    line = re.sub(r"0x[0-9a-fA-F]+", "<hex>", line)
    line = re.sub(r"\b\d+\b", "<n>", line)
    return re.sub(r"\s+", " ", line).strip()


def warning_counts(log: str, scratch: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for line in log.splitlines():
        signature = normalize_warning(line, scratch)
        if signature:
            counts[signature] = counts.get(signature, 0) + 1
    return counts


def measure_once(root: Path, scratch: Path, settle: float, sample: float) -> dict:
    shell = scratch / "shell"
    prepare_shell(root / "shell", shell)

    home = scratch / "home"
    config = scratch / "config"
    data = scratch / "data"
    state = scratch / "state"
    cache = scratch / "cache"
    runtime = scratch / "runtime"
    for directory in (home, config, data, state, cache, runtime):
        directory.mkdir(parents=True, exist_ok=True)
    runtime.chmod(0o700)

    env = os.environ.copy()
    env.update(
        {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(config),
            "XDG_DATA_HOME": str(data),
            "XDG_STATE_HOME": str(state),
            "XDG_CACHE_HOME": str(cache),
            "XDG_RUNTIME_DIR": str(runtime),
            "QT_QPA_PLATFORM": "offscreen",
            "NO_COLOR": "1",
            "PADILHA_REDUCED_MOTION": "0",
        }
    )
    stub_path = str(root / "tests" / "performance" / "stubs")
    existing = env.get("QML2_IMPORT_PATH", "")
    # Match bin/padilha-session: a checkout build is newer than the installed
    # plugin and carries the schema this tree expects.
    build_qml = root / "build" / "qml"
    import_paths = [str(build_qml)] if build_qml.is_dir() else []
    import_paths.append(stub_path)
    if existing:
        import_paths.append(existing)
    env["QML2_IMPORT_PATH"] = ":".join(import_paths)

    if not compile_config(root, env):
        raise RuntimeError("could not compile the shell config for the benchmark")

    qs = shutil.which("qs")
    if not qs:
        raise RuntimeError("qs (Quickshell) is not installed")

    log_path = scratch / "qs.log"
    start = time.monotonic_ns()
    with log_path.open("w", encoding="utf-8") as log_file:
        process = subprocess.Popen(
            [qs, "-p", str(shell), "--no-color", "--log-times"],
            env=env,
            stdout=log_file,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )

    try:
        deadline = time.monotonic() + 30.0
        ready = False
        while time.monotonic() < deadline:
            log = log_path.read_text(encoding="utf-8", errors="replace")
            if FAILURE_MARKER in log:
                raise RuntimeError("shell failed to load:\n" + "\n".join(log.splitlines()[-12:]))
            if READY_MARKER in log:
                ready = True
                break
            if process.poll() is not None:
                raise RuntimeError("shell exited before it was ready")
            time.sleep(0.05)

        if not ready:
            raise RuntimeError("shell did not reach the ready marker within 30 s")

        startup_ms = (time.monotonic_ns() - start) / 1_000_000
        time.sleep(settle)
        if process.poll() is not None:
            raise RuntimeError("shell exited during the idle settle window")

        before = proc_ticks(process.pid)
        time.sleep(sample)
        after = proc_ticks(process.pid)
        rss_kb = proc_rss_kb(process.pid)
        if before is None or after is None or rss_kb is None:
            raise RuntimeError("shell exited while samples were being collected")

        elapsed = sample
        hz = os.sysconf("SC_CLK_TCK")
        idle_cpu = (after - before) / hz / elapsed * 100.0
    finally:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)

    log = log_path.read_text(encoding="utf-8", errors="replace")
    return {
        "startup_ms": round(startup_ms, 1),
        "idle_cpu_percent": round(idle_cpu, 2),
        "rss_kb": rss_kb,
        "qml_warnings": warning_counts(log, scratch),
    }


def machine_info() -> dict:
    pretty = ""
    try:
        for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
            if line.startswith("PRETTY_NAME="):
                pretty = line.split("=", 1)[1].strip().strip('"')
                break
    except OSError:
        pass

    quickshell = ""
    try:
        result = subprocess.run(
            ["quickshell", "--version"], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=5
        )
        quickshell = result.stdout.splitlines()[0] if result.stdout else ""
    except (OSError, subprocess.TimeoutExpired):
        pass

    uname = platform.uname()
    return {
        "os": pretty or uname.system,
        "kernel": uname.release,
        "machine": uname.machine,
        "quickshell": quickshell,
        "display": "offscreen (QT_QPA_PLATFORM=offscreen)",
        "reduced_motion": False,
    }


def merge_counts(measurements: list[dict]) -> dict[str, int]:
    merged: dict[str, int] = {}
    for measurement in measurements:
        for key, value in measurement["qml_warnings"].items():
            merged[key] = max(merged.get(key, 0), value)
    return dict(sorted(merged.items()))


def summarize(measurements: list[dict]) -> dict:
    # Startup is the fastest run: a cold page cache or a busy reference machine
    # adds noise to the slow runs but not to the code we are budgeting.
    return {
        "startup_ms": round(min(m["startup_ms"] for m in measurements), 1),
        "idle_cpu_percent": round(statistics.median(m["idle_cpu_percent"] for m in measurements), 2),
        "rss_kb": int(statistics.median(m["rss_kb"] for m in measurements)),
        "qml_warnings": merge_counts(measurements),
    }


def compare(current: dict, baseline: dict) -> list[str]:
    thresholds = {**DEFAULT_THRESHOLDS, **baseline.get("thresholds", {})}
    failures: list[str] = []

    startup_limit = baseline["startup_ms"] * thresholds["startup_factor"] + thresholds["startup_slack_ms"]
    if current["startup_ms"] > startup_limit:
        failures.append(
            f"startup {current['startup_ms']:.0f} ms exceeds budget {startup_limit:.0f} ms "
            f"(baseline {baseline['startup_ms']:.0f} ms)"
        )

    cpu_limit = baseline["idle_cpu_percent"] * thresholds["idle_cpu_factor"] + thresholds["idle_cpu_slack_percent"]
    if current["idle_cpu_percent"] > cpu_limit:
        failures.append(
            f"idle CPU {current['idle_cpu_percent']:.2f}% exceeds budget {cpu_limit:.2f}% "
            f"(baseline {baseline['idle_cpu_percent']:.2f}%)"
        )

    rss_limit = baseline["rss_kb"] * thresholds["rss_factor"] + thresholds["rss_slack_kb"]
    if current["rss_kb"] > rss_limit:
        failures.append(
            f"RSS {current['rss_kb']} kB exceeds budget {rss_limit:.0f} kB "
            f"(baseline {baseline['rss_kb']} kB)"
        )

    known = baseline.get("qml_warnings", {})
    for signature, count in current["qml_warnings"].items():
        if signature not in known:
            failures.append(f"new QML warning class: {signature}")
            continue
        limit = known[signature] * thresholds["warning_count_factor"] + thresholds["warning_count_slack"]
        if count > limit:
            failures.append(f"QML warning class grew from {known[signature]} to {count}: {signature}")

    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent.parent))
    parser.add_argument("--baseline", default=str(Path(__file__).resolve().parent / "baseline.json"))
    parser.add_argument("--record", action="store_true")
    parser.add_argument("--repetitions", type=int, default=2)
    parser.add_argument("--settle", type=float, default=1.5)
    parser.add_argument("--sample", type=float, default=2.5)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    baseline_path = Path(args.baseline).resolve()
    if args.repetitions < 1:
        parser.error("--repetitions must be at least 1")

    measurements = []
    for index in range(args.repetitions):
        with tempfile.TemporaryDirectory(prefix="padilha-perf-") as temporary:
            scratch = Path(temporary)
            measurement = measure_once(root, scratch, args.settle, args.sample)
            measurements.append(measurement)
            print(f"  run {index + 1}: {json.dumps(measurement, sort_keys=True)}")

    current = summarize(measurements)
    if args.record:
        thresholds = DEFAULT_THRESHOLDS
        if baseline_path.is_file():
            try:
                thresholds = {**DEFAULT_THRESHOLDS, **json.loads(baseline_path.read_text()).get("thresholds", {})}
            except (OSError, json.JSONDecodeError):
                pass
        try:
            commit = subprocess.check_output(
                ["git", "-C", str(root), "rev-parse", "--short", "HEAD"], text=True, stderr=subprocess.DEVNULL
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            commit = ""
        baseline = {
            "schema": 1,
            "measured_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "commit": commit,
            "reference_machine": machine_info(),
            "method": (
                "Quickshell offscreen load of the full shell tree with tests/performance/stubs; "
                "startup is launch to the Configuration Loaded marker (fastest of "
                f"{args.repetitions} runs), CPU/RSS are the shell process after 1.5 s settle "
                "and a 2.5 s idle sample (median of the runs)"
            ),
            "startup_ms": current["startup_ms"],
            "idle_cpu_percent": current["idle_cpu_percent"],
            "rss_kb": current["rss_kb"],
            "qml_warnings": current["qml_warnings"],
            "thresholds": thresholds,
        }
        baseline_path.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"recorded baseline in {baseline_path}")
        print(json.dumps(current, indent=2, sort_keys=True))
        return 0

    if not baseline_path.is_file():
        print(f"missing baseline: {baseline_path}", file=sys.stderr)
        return 1
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    failures = compare(current, baseline)
    print("current:", json.dumps(current, sort_keys=True))
    if failures:
        for failure in failures:
            print(f"  FAIL {failure}")
        return 1
    print("  performance budget holds")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
