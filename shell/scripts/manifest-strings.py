#!/usr/bin/env python3
"""Write extension manifest fields as gettext-extractable Tr.tr calls.

Extension manifests are JSON data, so xgettext cannot see their user-facing
name and description. The translation template generator runs this script to
turn those fields into ordinary `Tr.tr("...")` lines in a temporary file, then
runs xgettext over that file with the rest of the shell sources.
"""

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 3:
        print(f"usage: {Path(sys.argv[0]).name} OUT MANIFEST...", file=sys.stderr)
        return 2

    out = Path(sys.argv[1])
    with out.open("w", encoding="utf-8") as handle:
        for name in sys.argv[2:]:
            try:
                data = json.loads(Path(name).read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError) as error:
                print(f"{name}: {error}", file=sys.stderr)
                return 1
            if not isinstance(data, dict):
                continue
            for field in ("name", "description"):
                value = data.get(field)
                if isinstance(value, str) and value:
                    handle.write(f"Tr.tr({json.dumps(value, ensure_ascii=False)});\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
