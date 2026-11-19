#!/usr/bin/python3
"""Check the generated GTK and Qt theme contract.

    tests/theme/check-gtk-qt-contrast.py [repo-root]

The GTK 3/4 stylesheet and both KDE/Qt colour schemes must use generated
scheme roles only, cover the states that are easy to lose (menus, tooltips,
disabled text, selections, focus rings and borders), and keep their text and
indicator contrast above the thresholds in tests/fixtures/gtk-qt-contrast.json.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
FIXTURE = ROOT / "tests" / "fixtures" / "gtk-qt-contrast.json"
GTK = ROOT / "share" / "templates" / "gtk.css"
QT_LIGHT = ROOT / "share" / "templates" / "qtlight.colors"
QT_DARK = ROOT / "share" / "templates" / "qtdark.colors"
QT_ENGINE = ROOT / "share" / "templates" / "qtengine.json"
APPLY = ROOT / "lib" / "apply.lua"
THEME = ROOT / "bin" / "padilha-theme"

COLOR_REF = re.compile(r"\{\{\s*\$(\w+)\s*(?:\|\s*(\w+)\s*)?\}\}")
HARD_COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b|\b(?:rgb|rgba|hsl|hsla)\s*\(", re.I)
RAW_RGB = re.compile(r"(?m)^[A-Za-z]\w*=\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*$")

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


def css_code(text: str) -> str:
    return re.sub(r"/\*.*?\*/", "", text, flags=re.S)


def colours_file_code(text: str) -> str:
    return re.sub(r"(?m)^\s*#.*$", "", text)


def refs(text: str) -> list[tuple[str, str]]:
    return [(match.group(1), match.group(2) or "") for match in COLOR_REF.finditer(text)]


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


def parse_colours(text: str) -> tuple[list[str], dict[str, dict[str, str]]]:
    order: list[str] = []
    sections: dict[str, dict[str, str]] = {}
    current: str | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        section = re.fullmatch(r"\[(.+)\]", line)
        if section:
            current = section.group(1)
            order.append(current)
            sections[current] = {}
        elif "=" in line and current is not None:
            key, value = line.split("=", 1)
            sections[current][key.strip()] = value.strip()
    return order, sections


def check_gtk(roles: set[str]) -> None:
    source = read(GTK)
    if not source:
        return
    code = css_code(source)

    if HARD_COLOR.search(code):
        bad("the GTK template has no hard-coded colours")
    else:
        ok("the GTK template has no hard-coded colours")

    if re.search(r"outline(?:-style)?\s*:\s*none", code):
        bad("the GTK template does not suppress focus outlines")
    else:
        ok("the GTK template does not suppress focus outlines")

    if '@import "thunar.css";' in source:
        ok("the GTK template imports the Thunar stylesheet")
    else:
        bad("the GTK template imports the Thunar stylesheet")

    required_roles = {
        "accent_color", "accent_bg_color", "accent_fg_color",
        "destructive_color", "destructive_bg_color", "destructive_fg_color",
        "success_color", "success_bg_color", "success_fg_color",
        "warning_color", "warning_bg_color", "warning_fg_color",
        "error_color", "error_bg_color", "error_fg_color",
        "window_bg_color", "window_fg_color", "view_bg_color", "view_fg_color",
        "headerbar_bg_color", "headerbar_fg_color", "headerbar_border_color",
        "headerbar_backdrop_color", "sidebar_bg_color", "sidebar_fg_color",
        "secondary_sidebar_bg_color", "secondary_sidebar_fg_color",
        "card_bg_color", "card_fg_color", "dialog_bg_color", "dialog_fg_color",
        "popover_bg_color", "popover_fg_color", "popover_border_color",
        "menu_bg_color", "menu_fg_color", "menu_border_color",
        "tooltip_bg_color", "tooltip_fg_color", "tooltip_border_color",
        "theme_fg_color", "theme_text_color", "theme_bg_color", "theme_base_color",
        "theme_selected_bg_color", "theme_selected_fg_color",
        "insensitive_bg_color", "insensitive_fg_color", "insensitive_base_color",
        "borders", "unfocused_borders", "placeholder_text_color",
        "link_color", "link_visited_color",
    }
    defined = set(re.findall(r"@define-color\s+(\w+)", code))
    missing = sorted(required_roles - defined)
    if missing:
        bad("the GTK template defines the semantic and compatibility roles", ", ".join(missing))
    else:
        ok("the GTK template defines the semantic and compatibility roles")

    used = {name for name, _filter in refs(source) if name != "mode"}
    unknown = sorted(used - roles)
    if unknown:
        bad("the GTK template only asks for generated roles", ", ".join(unknown))
    else:
        ok("the GTK template only asks for generated roles")

    sections = {
        "menus": ("menuitem", "menu separator"),
        "popovers": ("popover", "popover > arrow"),
        "tooltips": ("tooltip", "tooltip.background"),
        "disabled states": ("menuitem:disabled", "*:disabled", "button:disabled"),
        "selections": ("theme_selected_bg_color", "*:selected"),
        "focus rings": ("outline-color", "outline-offset"),
        "borders": ("border: 1px solid @borders", "border-color: @borders"),
        "file choosers": ("filechooser", "placessidebar"),
        "dialogs": ("dialog", "messagedialog"),
    }
    for name, needles in sections.items():
        missing_markers = [needle for needle in needles if needle not in code]
        if missing_markers:
            bad(f"the GTK template covers {name}", ", ".join(missing_markers))
        else:
            ok(f"the GTK template covers {name}")

    if re.search(
        r"@define-color\s+theme_selected_bg_color\s+\{\{\s*\$primaryContainer\s*\}\}",
        source,
    ) and re.search(
        r"@define-color\s+theme_selected_fg_color\s+\{\{\s*\$onPrimaryContainer\s*\}\}",
        source,
    ):
        ok("the GTK selection uses the same primaryContainer pair as Thunar")
    else:
        bad("the GTK selection uses the same primaryContainer pair as Thunar")


def check_qt(roles: set[str]) -> None:
    light_source = read(QT_LIGHT)
    dark_source = read(QT_DARK)
    if not light_source or not dark_source:
        return

    for path, source in ((QT_LIGHT, light_source), (QT_DARK, dark_source)):
        code = colours_file_code(source)
        if HARD_COLOR.search(code):
            bad(f"{path.name} has no hard-coded colours")
        else:
            ok(f"{path.name} has no hard-coded colours")
        if RAW_RGB.search(code):
            bad(f"{path.name} has no frozen RGB triples")
        else:
            ok(f"{path.name} has no frozen RGB triples")

        used = {name for name, _filter in refs(source) if name != "mode"}
        unknown = sorted(used - roles)
        if unknown:
            bad(f"{path.name} only asks for generated roles", ", ".join(unknown))
        else:
            ok(f"{path.name} only asks for generated roles")

        invalid_filters = sorted(
            {filter_name for _name, filter_name in refs(source) if filter_name not in ("", "rgb")}
        )
        if invalid_filters:
            bad(f"{path.name} uses known template filters", ", ".join(invalid_filters))
        else:
            ok(f"{path.name} uses known template filters")

    light_order, light_sections = parse_colours(light_source)
    dark_order, dark_sections = parse_colours(dark_source)

    required_sections = [
        "ColorEffects:Disabled",
        "ColorEffects:Inactive",
        "Colors:Button",
        "Colors:Complementary",
        "Colors:Header",
        "Colors:Header][Inactive",
        "Colors:Selection",
        "Colors:Tooltip",
        "Colors:View",
        "Colors:Window",
        "General",
        "KDE",
        "WM",
    ]
    for label, order, sections in (
        ("light", light_order, light_sections),
        ("dark", dark_order, dark_sections),
    ):
        missing = [name for name in required_sections if name not in sections]
        if missing:
            bad(f"the {label} Qt scheme has every KDE section", ", ".join(missing))
        else:
            ok(f"the {label} Qt scheme has every KDE section")

    if light_order == dark_order:
        ok("the light and dark Qt schemes have the same section order")
    else:
        bad("the light and dark Qt schemes have the same section order")

    required_keys = [
        "BackgroundAlternate", "BackgroundNormal",
        "DecorationFocus", "DecorationHover",
        "ForegroundActive", "ForegroundInactive",
        "ForegroundLink", "ForegroundNegative",
        "ForegroundNeutral", "ForegroundNormal",
        "ForegroundPositive", "ForegroundVisited",
    ]
    for label, sections in (("light", light_sections), ("dark", dark_sections)):
        local: list[str] = []
        for name in required_sections:
            if not name.startswith("Colors:"):
                continue
            missing = [key for key in required_keys if key not in sections.get(name, {})]
            if missing:
                local.append(f"{name}: {', '.join(missing)}")
        if local:
            bad(f"the {label} Qt colour groups carry every foreground/background role", "; ".join(local))
        else:
            ok(f"the {label} Qt colour groups carry every foreground/background role")

    same_keys = all(
        set(light_sections.get(name, {})) == set(dark_sections.get(name, {}))
        for name in required_sections
    )
    if same_keys:
        ok("the light and dark Qt schemes expose the same keys")
    else:
        bad("the light and dark Qt schemes expose the same keys")

    for label, sections in (("light", light_sections), ("dark", dark_sections)):
        disabled = sections.get("ColorEffects:Disabled", {})
        inactive = sections.get("ColorEffects:Inactive", {})
        if (
            disabled.get("ColorEffect") == "0"
            and disabled.get("ColorAmount") == "0"
            and inactive.get("ColorEffect") == "0"
            and inactive.get("ColorAmount") == "0"
        ):
            ok(f"the {label} Qt scheme does not blend disabled text below contrast")
        else:
            bad(f"the {label} Qt scheme does not blend disabled text below contrast")

        colours = sections.get("Colors:Selection", {})
        if (
            colours.get("BackgroundNormal") == "{{ $primaryContainer }}"
            and colours.get("ForegroundNormal") == "{{ $onPrimaryContainer }}"
            and colours.get("DecorationFocus") == "{{ $onPrimaryContainer }}"
        ):
            ok(f"the {label} Qt selection matches the GTK primaryContainer pair")
        else:
            bad(f"the {label} Qt selection matches the GTK primaryContainer pair")

        tooltip = sections.get("Colors:Tooltip", {})
        if (
            tooltip.get("BackgroundNormal") == "{{ $surfaceContainerHighest }}"
            and tooltip.get("ForegroundNormal") == "{{ $onSurface }}"
        ):
            ok(f"the {label} Qt tooltip uses the highest readable surface")
        else:
            bad(f"the {label} Qt tooltip uses the highest readable surface")

        inactive_ok = True
        for name in required_sections:
            if not name.startswith("Colors:") or name == "Colors:Selection":
                continue
            if sections.get(name, {}).get("ForegroundInactive") != "{{ $onSurfaceVariant }}":
                inactive_ok = False
                break
        if inactive_ok:
            ok(f"the {label} Qt inactive and disabled text uses onSurfaceVariant")
        else:
            bad(f"the {label} Qt inactive and disabled text uses onSurfaceVariant")

        wm = sections.get("WM", {})
        if "| rgb" in wm.get("activeBlend", "") and "| rgb" in wm.get("inactiveBlend", ""):
            ok(f"the {label} Qt titlebar blends come from generated roles")
        else:
            bad(f"the {label} Qt titlebar blends come from generated roles")


def check_qt_engine(roles: set[str]) -> None:
    source = read(QT_ENGINE)
    if not source:
        return
    try:
        config = json.loads(source)
    except json.JSONDecodeError as error:
        bad("qtengine.json is valid JSON", str(error))
        return
    ok("qtengine.json is valid JSON")

    if HARD_COLOR.search(source):
        bad("qtengine.json has no hard-coded colours")
    else:
        ok("qtengine.json has no hard-coded colours")

    theme = config.get("theme", {})
    if theme.get("colorScheme") == "~/.config/qtengine/caelestia.colors":
        ok("qtengine.json points at the generated colour scheme")
    else:
        bad("qtengine.json points at the generated colour scheme", str(theme.get("colorScheme")))

    if theme.get("iconTheme") == "Papirus-{{ $mode }}":
        ok("qtengine.json follows the light/dark icon theme")
    else:
        bad("qtengine.json follows the light/dark icon theme", str(theme.get("iconTheme")))

    used = {name for name, _filter in refs(source) if name != "mode"}
    if used <= roles:
        ok("qtengine.json only asks for generated roles")
    else:
        bad("qtengine.json only asks for generated roles", ", ".join(sorted(used - roles)))

    if isinstance(theme.get("style"), str) and theme["style"]:
        ok("qtengine.json selects a widget style")
    else:
        bad("qtengine.json selects a widget style")


def check_apply() -> None:
    source = read(APPLY)
    if not source:
        return
    for destination in (
        "gtk-3.0/gtk.css",
        "gtk-4.0/gtk.css",
        "qtengine/caelestia.colors",
        "qtengine/config.json",
    ):
        if destination in source:
            ok(f"the theme engine writes {destination}")
        else:
            bad(f"the theme engine writes {destination}")


def main() -> int:
    try:
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        bad("the GTK/Qt contrast fixture is readable", str(error))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    pairs = [(pair, "text") for pair in fixture["textPairs"]]
    pairs += [(pair, "indicator") for pair in fixture["focusPairs"]]
    fixture_roles = {pair[key] for pair, _kind in pairs for key in ("fg", "bg")}

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

    check_gtk(set(first))
    check_qt(set(first))
    check_qt_engine(set(first))
    check_apply()

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
                for pair, kind in pairs:
                    fg = palette.get(pair["fg"])
                    bg = palette.get(pair["bg"])
                    if fg is None or bg is None:
                        local.append(f"missing {pair['fg']} or {pair['bg']}")
                        continue
                    actual = ratio(fg, bg)
                    if actual + 1e-9 < float(pair["minimum"]):
                        local.append(
                            f"{pair['name']} ({kind}): {actual:.2f}:1 < {pair['minimum']}:1 "
                            f"({fg} on {bg})"
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
