#!/usr/bin/env python3
"""Compare the Lua brightness curve with bin/padilha-brightness."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "padilha-brightness-python"
LUA = ROOT / "spikes" / "lua-brightness" / "brightness.lua"


def load_python_curve():
    loader = importlib.machinery.SourceFileLoader("padilha_brightness", str(SCRIPT))
    spec = importlib.util.spec_from_loader("padilha_brightness", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module.target_percent


def main() -> int:
    target_percent = load_python_curve()
    base = int(time.mktime((2026, 11, 25, 0, 0, 0, 0, 0, -1)))
    output = subprocess.check_output(["lua", str(LUA), "--table"], text=True)
    mismatches: list[tuple[int, int, int]] = []
    for line in output.splitlines():
        minute, target = map(int, line.split(","))
        expected = target_percent(base + minute * 60)
        if target != expected:
            mismatches.append((minute, target, expected))
    print(f"compared 1440 minutes, {len(mismatches)} mismatches")
    for minute, got, want in mismatches[:10]:
        print(f"  minute {minute}: lua={got} python={want}")
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
