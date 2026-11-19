#!/usr/bin/python3
"""Check the generated app themes for contrast, coverage and wiring.

    tests/theme/check-app-contrast.py [repo-root]

The fixture names scheme roles, not literal colours, so the same contract is
checked for every seed, variant and both modes. Templates may not contain
hard-coded colours; every role they ask for must exist in the scheme, and each
app has to be wired into lib/apply.lua.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
FIXTURE = ROOT / "tests" / "fixtures" / "app-contrast.json"
APPLY = ROOT / "lib" / "apply.lua"
COVERAGE = ROOT / "docs" / "app-themes.md"
THEME = ROOT / "bin" / "padilha-theme"

DISPLAY = {
    "btop": "btop",
    "cava": "cava",
    "fuzzel": "fuzzel",
    "micro": "micro",
    "mc": "Midnight Commander",
    "spicetify": "Spicetify",
}

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


def strip_comments(text: str) -> str:
    """Remove whole-line and inline # / ; comments from the INI-ish templates."""
    lines = []
    for raw in text.splitlines():
        line = raw
        for marker in ("#", ";"):
            if marker in line:
                line = line.split(marker, 1)[0]
        lines.append(line)
    return "\n".join(lines)


def placeholders(text: str) -> set[str]:
    return set(re.findall(r"{{\s*\$(\w+)\s*}}", text))


def section_names(text: str) -> list[str]:
    return re.findall(r"^\s*\[([^\]]+)\]", text, flags=re.M)


def ini_keys(text: str) -> set[str]:
    keys = set()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("[") or line.startswith("#") or line.startswith(";"):
            continue
        if "=" in line:
            keys.add(line.split("=", 1)[0].strip().lower())
    return keys


def check_file(app_id: str, relative: str, roles: set[str]) -> str | None:
    path = ROOT / relative
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{app_id}: {relative} is readable", str(error))
        return None

    code = strip_comments(text)
    if re.search(r"#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla)\s*\(", code):
        bad(f"{app_id}: {relative} has no hard-coded colours")
    else:
        ok(f"{app_id}: {relative} has no hard-coded colours")

    used = placeholders(text) - {"mode", "aliases"}
    missing = sorted(used - roles)
    if missing:
        bad(f"{app_id}: {relative} only asks for generated roles", ", ".join(missing))
    else:
        ok(f"{app_id}: {relative} only asks for generated roles")

    return text


def wiring_ok(template_name: str, apply_text: str) -> bool:
    if "{mode}" in template_name:
        prefix, suffix = template_name.split("{mode}", 1)
        return prefix in apply_text and apply_text.count(suffix) >= 2
    return template_name in apply_text


def main() -> int:
    try:
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        bad("the app contrast fixture is readable", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    try:
        apply_text = APPLY.read_text(encoding="utf-8")
    except OSError as error:
        bad("lib/apply.lua is readable", str(error))
        apply_text = ""

    try:
        coverage = COVERAGE.read_text(encoding="utf-8")
    except OSError as error:
        bad("the app theme coverage table is readable", str(error))
        coverage = ""

    # One palette proves every role in the fixture exists somewhere.
    try:
        first = scheme(fixture["seeds"][0], "light", fixture["variants"][0])
    except (RuntimeError, json.JSONDecodeError) as error:
        bad("the palette generates", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    cache: dict[tuple[str, str, str], dict[str, str]] = {}

    for app_id, app in fixture["apps"].items():
        files = app.get("templates") or [app["template"]]
        combined = ""
        file_texts: dict[str, str] = {}
        for relative in files:
            text = check_file(app_id, relative, set(first))
            if text is not None:
                file_texts[relative] = text
                combined += text + "\n"

        missing = [token for token in app.get("required", []) if token not in combined]
        if missing:
            bad(f"{app_id}: the template covers its app keys", f"missing {', '.join(missing[:6])}")
        else:
            ok(f"{app_id}: the template covers its app keys")

        if app.get("uniqueSections"):
            names = section_names(strip_comments(combined))
            duplicates = sorted({name for name in names if names.count(name) > 1})
            if duplicates:
                bad(f"{app_id}: no duplicate sections", ", ".join(duplicates))
            else:
                ok(f"{app_id}: no duplicate sections")

        if app.get("sameKeys") and len(file_texts) == 2:
            key_sets = [ini_keys(strip_comments(text)) for text in file_texts.values()]
            if key_sets[0] == key_sets[1]:
                ok(f"{app_id}: light and dark templates expose the same keys")
            else:
                only = sorted(key_sets[0] ^ key_sets[1])
                bad(f"{app_id}: light and dark templates expose the same keys", ", ".join(only))

        support_ok = True
        for relative, tokens in app.get("support", {}).items():
            path = ROOT / relative
            try:
                text = path.read_text(encoding="utf-8")
            except OSError as error:
                bad(f"{app_id}: {relative} is readable", str(error))
                support_ok = False
                continue
            missing_support = [token for token in tokens if token not in text]
            if missing_support:
                bad(f"{app_id}: {relative} carries the generated aliases", ", ".join(missing_support))
                support_ok = False
        if support_ok and app.get("support"):
            ok(f"{app_id}: alias support is wired")

        if app.get("destination") and app["destination"] in apply_text:
            ok(f"{app_id}: the theme engine writes {app['destination']}")
        else:
            bad(f"{app_id}: the theme engine writes {app.get('destination', '?')}")

        if app.get("templateName") and wiring_ok(app["templateName"], apply_text):
            ok(f"{app_id}: the theme engine uses {app['templateName']}")
        elif app.get("templateName"):
            bad(f"{app_id}: the theme engine uses {app['templateName']}")

        local_failures: list[str] = []
        for pair in app.get("pairs", []):
            worst: tuple[float, tuple[str, str, str, str, str]] | None = None
            for seed in fixture["seeds"]:
                for variant in fixture["variants"]:
                    for mode in ("light", "dark"):
                        key = (seed, mode, variant)
                        try:
                            palette = cache.get(key) or scheme(*key)
                            cache[key] = palette
                        except (RuntimeError, json.JSONDecodeError) as error:
                            local_failures.append(f"{pair['name']}: {error}")
                            continue
                        fg = palette.get(pair["fg"])
                        bg = palette.get(pair["bg"])
                        if fg is None or bg is None:
                            local_failures.append(
                                f"{pair['name']}: missing {pair['fg']} or {pair['bg']}"
                            )
                            continue
                        actual = ratio(fg, bg)
                        if worst is None or actual < worst[0]:
                            worst = (actual, (mode, seed, variant, fg, bg))

            if worst is not None and worst[0] + 1e-9 < float(pair["minimum"]):
                mode, seed, variant, fg, bg = worst[1]
                local_failures.append(
                    f"{pair['name']}: {worst[0]:.2f}:1 < {pair['minimum']}:1 "
                    f"({mode} {variant} seed {seed}, {fg} on {bg})"
                )

        if local_failures:
            bad(
                f"{app_id}: {len(app.get('pairs', []))} contrast pairs",
                "; ".join(local_failures[:6]),
            )
        else:
            ok(
                f"{app_id}: {len(app.get('pairs', []))} contrast pairs in light and dark"
            )

        display = DISPLAY.get(app_id, app_id)
        if coverage and display.lower() in coverage.lower():
            ok(f"{app_id}: the coverage table lists {display}")
        else:
            bad(f"{app_id}: the coverage table lists {display}")

    lowered = coverage.lower()
    if "optional" in lowered and "spotify" in lowered and "spicetify" in lowered:
        ok("the coverage table documents Spicetify as optional")
    else:
        bad("the coverage table documents Spicetify as optional")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
