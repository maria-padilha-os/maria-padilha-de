#!/usr/bin/env python3
"""Summarise the Lua brightness shadow log."""

from __future__ import annotations

import sys
import time
from pathlib import Path


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".local/state/padilha/brightness-observe.csv"
    rows: list[tuple[int, int, int, int]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split(",")
        if len(parts) != 4:
            continue
        now, current, target, action = parts
        try:
            now_i = int(now)
            current_i = int(current)
            target_i = int(target)
        except ValueError:
            continue
        until = 0
        if action.startswith("observe:"):
            try:
                until = int(action.split(":", 1)[1])
            except ValueError:
                pass
        rows.append((now_i, current_i, target_i, until))

    if not rows:
        print("no rows")
        return 1

    mismatches = [row for row in rows if row[3] <= row[0] and abs(row[1] - row[2]) > 1]
    print(f"rows={len(rows)} span={rows[-1][0] - rows[0][0]}s mismatches={len(mismatches)}")
    for now, current, target, until in mismatches[:10]:
        stamp = time.strftime("%H:%M:%S", time.localtime(now))
        print(f"  {stamp} current={current} target={target} until={until}")
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
