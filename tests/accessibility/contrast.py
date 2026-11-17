#!/usr/bin/env python3
"""Check the generated light and dark schemes against the contrast fixture."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
FIXTURE = ROOT / "tests" / "fixtures" / "contrast.json"
THEME = ROOT / "bin" / "padilha-theme"

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


def luminance(value: str) -> float:
    value = value.lstrip("#")
    channels = [int(value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    channels = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def ratio(first: str, second: str) -> float:
    lighter, darker = sorted((luminance(first), luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def scheme(seed: str, mode: str, variant: str) -> dict[str, str]:
    with tempfile.TemporaryDirectory(prefix="padilha-contrast-") as temporary:
        out = Path(temporary) / "scheme.json"
        result = subprocess.run(
            [
                str(THEME),
                "scheme",
                "--seed",
                seed,
                "--mode",
                mode,
                "--variant",
                variant,
                "--out",
                str(out),
                "--quiet",
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0 or not out.is_file():
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "scheme failed")
        return json.loads(out.read_text(encoding="utf-8"))["colours"]


def main() -> int:
    try:
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        bad("contrast fixture is readable", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    pairs = [(pair, "text") for pair in fixture["textPairs"]]
    pairs += [(pair, "focus") for pair in fixture["focusPairs"]]

    for variant in fixture["variants"]:
        for mode in ("light", "dark"):
            for seed in fixture["seeds"]:
                try:
                    palette = scheme(seed, mode, variant)
                except RuntimeError as error:
                    bad(f"{mode} {variant} seed {seed} generates a scheme", str(error))
                    continue

                local: list[str] = []
                for pair, kind in pairs:
                    fg = palette.get(pair["fg"])
                    bg = palette.get(pair["bg"])
                    if fg is None or bg is None:
                        local.append(f"missing {pair['fg']} or {pair['bg']}")
                        continue
                    actual = ratio(fg, bg)
                    if actual + 1e-9 < float(pair["minimum"]):
                        local.append(
                            f"{pair['name']}: {actual:.2f}:1 < {pair['minimum']}:1 ({fg} on {bg})"
                        )

                label = f"{mode} {variant} seed {seed}"
                if local:
                    bad(label, "; ".join(local[:6]))
                else:
                    ok(label)

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
