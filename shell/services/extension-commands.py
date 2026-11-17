#!/usr/bin/env python3
"""Print the local command dependencies declared by one extension manifest.

The extension manager uses this only to report a missing executable. It never
installs anything and never touches the network. Output is a tab-separated list
of ``name=resolved-path`` pairs; an empty path means the command was not found.
"""

from __future__ import annotations

import json
import shutil
import sys


def main() -> int:
    try:
        with open(sys.argv[1], encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError):
        return 0

    if not isinstance(data, dict):
        return 0

    commands = data.get("commands")
    if not isinstance(commands, list):
        return 0

    pairs: list[str] = []
    for command in commands:
        if not isinstance(command, str):
            continue
        name = command.strip()
        if not name:
            continue
        pairs.append(f"{name}={shutil.which(name) or ''}")
    if pairs:
        sys.stdout.write("\t".join(pairs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
