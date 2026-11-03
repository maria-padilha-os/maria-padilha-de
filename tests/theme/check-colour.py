#!/usr/bin/python3
"""Hold lib/colour.lua to the Material Color Utilities numbers.

    tests/theme/check-colour.py

Prints the worst deviation per property and exits non-zero when anything is
off by more than the tolerance. The reference is the python-materialyoucolor
package; it is a test oracle only, never part of the desktop.
"""

import subprocess
import sys
from pathlib import Path

from materialyoucolor.hct import Hct

ROOT = Path(__file__).resolve().parents[2]

HEXES = [
    "000000", "ffffff", "ff0000", "00ff00", "0000ff", "181211", "8a5035",
    "ffb4ac", "3366cc", "f8ac8b", "d18881", "ff554c", "ede0de", "715d25",
    "1a73e8", "34a853", "ea4335", "fbbc04", "5f6368", "202124",
]

HCTS = [
    (300, 60, 50), (25, 80, 40), (210, 30, 90), (0, 0, 50), (120, 50, 10),
    (95, 100, 60), (265, 45, 75), (10, 20, 98), (200, 8, 20), (55, 90, 70),
    (330, 120, 45), (180, 40, 5), (20, 70, 95), (280, 15, 35), (45, 100, 55),
]

# HCT.from() gives up at some point; keep the tolerances honest but not absurd.
TOLERANCE = {
    "hue": 1.0,
    "chroma": 1.5,
    "tone": 0.5,
    "rgb": 3,
    "hex": 0.02,  # share of channels differing by more than 3
}


def run_lua(cases: list[str]) -> list[str]:
    out = subprocess.run(
        ["lua", str(ROOT / "tests/theme/dump-colour.lua"), str(ROOT)],
        input="\n".join(cases),
        text=True,
        capture_output=True,
        check=True,
    )
    return out.stdout.splitlines()


def main() -> int:
    cases = [f"hex {h}" for h in HEXES] + [f"hct {h} {c} {t}" for h, c, t in HCTS]
    lines = run_lua(cases)
    if len(lines) != len(cases):
        print(f"lua returned {len(lines)} lines for {len(cases)} cases")
        return 1

    worst = dict.fromkeys(TOLERANCE, 0.0)
    failures = 0

    for hexv, line in zip(HEXES, lines[: len(HEXES)]):
        hue, chroma, tone, roundtrip = line.split()
        ref = Hct.from_int(int(f"ff{hexv}", 16))
        dh = abs(float(hue) - ref.hue)
        dc = abs(float(chroma) - ref.chroma)
        dt = abs(float(tone) - ref.tone)
        worst["hue"] = max(worst["hue"], dh)
        worst["chroma"] = max(worst["chroma"], dc)
        worst["tone"] = max(worst["tone"], dt)
        # A roundtrip through HCT must come back to the same colour.
        diff = max(abs(int(roundtrip[i : i + 2], 16) - int(hexv[i : i + 2], 16)) for i in (0, 2, 4))
        worst["rgb"] = max(worst["rgb"], diff)
        if dh > TOLERANCE["hue"] or dc > TOLERANCE["chroma"] or dt > TOLERANCE["tone"] or diff > TOLERANCE["rgb"]:
            failures += 1
            print(f"hex {hexv}: got h={hue} c={chroma} t={tone} hex={roundtrip}, "
                  f"ref h={ref.hue:.4f} c={ref.chroma:.4f} t={ref.tone:.4f}")

    bad_channels = 0
    for (h, c, t), line in zip(HCTS, lines[len(HEXES) :]):
        got = line.strip()
        want = f"{Hct.from_hct(h, c, t).to_int() & 0xFFFFFF:06x}"
        diff = max(abs(int(got[i : i + 2], 16) - int(want[i : i + 2], 16)) for i in (0, 2, 4))
        worst["rgb"] = max(worst["rgb"], diff)
        if diff > TOLERANCE["rgb"]:
            bad_channels += 1
            failures += 1
            print(f"hct {h},{c},{t}: got {got}, ref {want} (max channel delta {diff})")

    print(f"cases: {len(cases)}  failures: {failures}")
    print("worst deviation: " + "  ".join(f"{k}={v:.3f}" for k, v in worst.items()))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
