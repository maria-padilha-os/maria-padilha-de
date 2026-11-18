#!/usr/bin/python3
"""Check the Thunar stylesheet contract.

    tests/theme/check-thunar-contrast.py [repo-root]

The stylesheet is generated twice, for the GTK 3 and GTK 4 include points. It
must use scheme roles only, and the text/selection/focus pairs it paints must
stay readable in light and dark palettes. The contrast values come from the
same generated palette the stylesheet is rendered with.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
FIXTURE = ROOT / "tests" / "fixtures" / "thunar-contrast.json"
TEMPLATE = ROOT / "share" / "templates" / "thunar.css"
APPLY = ROOT / "lib" / "apply.lua"
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
            "--print",
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "scheme failed")
    return json.loads(result.stdout)["colours"]


def check_template(roles: set[str]) -> None:
    try:
        text = TEMPLATE.read_text(encoding="utf-8")
        apply_text = APPLY.read_text(encoding="utf-8")
    except OSError as error:
        bad("the Thunar template is readable", str(error))
        return

    # Comments mention the old reset on purpose; only declarations count.
    code = re.sub(r"/\*.*?\*/", "", text, flags=re.S)

    if re.search(r"#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla)\s*\(", code):
        bad("the template has no hard-coded colours")
    else:
        ok("the template has no hard-coded colours")

    if re.search(r"outline(?:-style)?\s*:\s*none", code):
        bad("the template does not suppress focus outlines")
    else:
        ok("the template does not suppress focus outlines")

    used = set(re.findall(r"{{%?\s*\$(\w+)\s*}}", text)) | set(
        re.findall(r"\{\{\s*\$(\w+)\s*\}\}", text)
    )
    used.discard("mode")
    missing = sorted(used - roles)
    if missing:
        bad("the template only asks for generated roles", ", ".join(missing))
    else:
        ok("the template only asks for generated roles")

    sections = {
        "titlebar": ("titlebar", "headerbar"),
        "tabs": ("tabs tab", "reorderable-page"),
        "path bar": ("path-bar-button", "location-button"),
        "sidebar": (".sidebar",),
        "list and icon views": ("treeview.view", "iconview", "listview", "gridview"),
        "selection": ("primaryContainer", "onPrimaryContainer"),
        "rubberband": ("rubberband",),
        "status bar": ("statusbar",),
        "menus": ("menuitem", "popover"),
        "dialogs": ("dialog",),
        "focus": (":focus", "outline-color"),
    }
    for name, needles in sections.items():
        found = [needle for needle in needles if needle in text]
        if len(found) == len(needles):
            ok(f"the template covers {name}")
        else:
            bad(f"the template covers {name}", f"missing {', '.join(set(needles) - set(found))}")

    for destination in ("gtk-3.0/thunar.css", "gtk-4.0/thunar.css"):
        if destination in apply_text:
            ok(f"the theme engine writes {destination}")
        else:
            bad(f"the theme engine writes {destination}")


def main() -> int:
    try:
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        bad("the Thunar contrast fixture is readable", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    pairs = [(pair, "text") for pair in fixture["textPairs"]]
    pairs += [(pair, "focus") for pair in fixture["focusPairs"]]
    fixture_roles = {pair[key] for pair, _ in pairs for key in ("fg", "bg")}

    # One palette is enough to prove every role in the fixture exists.
    try:
        first = scheme(fixture["seeds"][0], "light", fixture["variants"][0])
    except (RuntimeError, json.JSONDecodeError) as error:
        bad("the palette generates", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    missing_roles = sorted(fixture_roles - set(first))
    if missing_roles:
        bad("the contrast fixture only names generated roles", ", ".join(missing_roles))
    else:
        ok("the contrast fixture only names generated roles")

    check_template(set(first))

    cache: dict[tuple[str, str, str], dict[str, str]] = {}

    for variant in fixture["variants"]:
        for mode in ("light", "dark"):
            for seed in fixture["seeds"]:
                key = (seed, mode, variant)
                try:
                    palette = cache.get(key) or scheme(*key)
                    cache[key] = palette
                except (RuntimeError, json.JSONDecodeError) as error:
                    bad(f"{mode} {variant} seed {seed} generates a palette", str(error))
                    continue

                local: list[str] = []
                for pair, _kind in pairs:
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
