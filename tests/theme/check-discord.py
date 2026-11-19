#!/usr/bin/python3
"""Check the generated Discord stylesheet contract.

    tests/theme/check-discord.py CSS SCHEME.json [CSS SCHEME.json ...]

Each pair is a stylesheet produced by `padilha-theme apply` and the scheme it
was rendered from. The checks are static: they never start Discord or a client
mod and they never touch an account, token or network.

The stylesheet must be a standalone BetterDiscord/Vencord theme with a meta
block, no remote imports or assets, a complete generated palette, literal
fallbacks on every custom property it consumes, and readable text pairs in the
mode it was rendered for.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

failures = 0
checks = 0


def report(ok: bool, name: str, detail: str = "") -> None:
    global failures, checks
    checks += 1
    if ok:
        print(f"  ok   {name}")
    else:
        failures += 1
        print(f"  FAIL {name}")
        if detail:
            print(f"       {detail}")


def strip_comments(css: str) -> str:
    """Remove /* ... */ comments while preserving strings and line layout."""
    out: list[str] = []
    i = 0
    quote = ""
    while i < len(css):
        ch = css[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < len(css):
                out.append(css[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = ""
            i += 1
            continue
        if css.startswith("/*", i):
            end = css.find("*/", i + 2)
            if end < 0:
                out.append(css[i:])
                break
            out.append("\n" * css.count("\n", i, end + 2))
            i = end + 2
            continue
        if ch in "\"'":
            quote = ch
        out.append(ch)
        i += 1
    return "".join(out)


def fallback_block(css: str) -> str:
    match = re.search(r":where\s*\(\s*:root\s*\)\s*\{", css)
    if not match:
        return ""
    start = match.end()
    depth = 1
    i = start
    quote = ""
    while i < len(css):
        ch = css[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return css[start:i]
        i += 1
    return ""


def extract_function(css: str, open_paren: int) -> tuple[str, int | None, int] | None:
    depth = 1
    i = open_paren + 1
    start = i
    quote = ""
    first_comma: int | None = None
    while i < len(css):
        ch = css[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return css[start:i], first_comma, i
        elif ch == "," and depth == 1 and first_comma is None:
            first_comma = i
        i += 1
    return None


def find_var_calls(css: str) -> list[tuple[str, str | None, str]]:
    calls: list[tuple[str, str | None, str]] = []
    for match in re.finditer(r"\bvar\s*\(", css, re.IGNORECASE):
        open_paren = css.find("(", match.start())
        parsed = extract_function(css, open_paren)
        if parsed is None:
            calls.append(("", None, match.group(0)))
            continue
        args, comma, close = parsed
        name = (args if comma is None else css[open_paren + 1:comma]).strip()
        fallback = None if comma is None else css[comma + 1:close].strip()
        calls.append((name, fallback, css[match.start():close + 1]))
    return calls


def check_balanced(name: str, css: str) -> None:
    pairs = {")": "(", "}": "{", "]": "["}
    stack: list[str] = []
    quote = ""
    errors: list[str] = []
    for ch in css:
        if quote:
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            stack.append(ch)
        elif ch in ")]}":
            if not stack or stack[-1] != pairs[ch]:
                errors.append(f"unexpected {ch!r}")
                break
            stack.pop()
    if stack:
        errors.append("unclosed " + "".join(stack[-5:]))
    report(not errors, f"{name}: braces and parentheses are balanced", "; ".join(errors))


def check_meta(name: str, raw: str) -> None:
    report(raw.lstrip().startswith("/**"), f"{name}: starts with a BetterDiscord meta block")
    block = re.match(r"\s*/\*\*(.*?)\*/", raw, re.DOTALL)
    text = block.group(1) if block else ""
    for field in ("name", "author", "description", "version"):
        report(
            bool(re.search(rf"@\s*{field}\s+\S", text, re.IGNORECASE)),
            f"{name}: meta has @{field}",
        )


def check_no_remote(name: str, css: str) -> None:
    report(not re.search(r"@import\b", css, re.IGNORECASE), f"{name}: no @import")
    report(not re.search(r"\burl\s*\(", css, re.IGNORECASE), f"{name}: no url() asset")
    report(not re.search(r"@font-face\b", css, re.IGNORECASE), f"{name}: no @font-face")
    report(not re.search(r"https?://", css, re.IGNORECASE), f"{name}: no remote URL")
    report(not re.search(r"<\s*script\b", css, re.IGNORECASE), f"{name}: no script element")
    report(not re.search(r"javascript\s*:", css, re.IGNORECASE), f"{name}: no javascript: URL")


def luminance(value: str) -> float:
    value = value.lstrip("#")
    channels = [int(value[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    channels = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def contrast(first: str, second: str) -> float:
    lighter, darker = sorted((luminance(first), luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def check_palette(name: str, css: str, colours: dict[str, str], mode: str) -> dict[str, str]:
    block = fallback_block(css)
    report(bool(block), f"{name}: has a :where(:root) fallback palette")
    declared_matches = re.findall(r"(--lilith-[\w-]+)\s*:\s*([^;]+);", block)
    declared = {prop: value.strip() for prop, value in declared_matches}
    empty = [prop for prop, value in declared_matches if not value.strip()]
    report(not empty, f"{name}: fallback palette declarations are non-empty", ", ".join(empty))

    used: set[str] = set()
    missing_fallback: list[str] = []
    empty_fallback: list[str] = []
    non_lilith: list[str] = []
    for prop, fallback, full in find_var_calls(css):
        if not prop.startswith("--lilith-"):
            non_lilith.append(full)
            continue
        used.add(prop)
        if fallback is None:
            missing_fallback.append(full)
        elif not fallback:
            empty_fallback.append(full)

    report(not non_lilith, f"{name}: every var() uses a --lilith-* property", "; ".join(non_lilith[:5]))
    report(not missing_fallback, f"{name}: every var(--lilith-*) has a fallback", "; ".join(missing_fallback[:5]))
    report(not empty_fallback, f"{name}: no empty --lilith-* fallbacks", "; ".join(empty_fallback[:5]))
    undeclared = sorted(used - set(declared))
    report(not undeclared, f"{name}: every used palette property is declared", ", ".join(undeclared))
    report(len(used) >= 12, f"{name}: consumes the generated palette ({len(used)} properties)")

    required = (
        "--background-primary",
        "--background-secondary",
        "--background-tertiary",
        "--text-normal",
        "--interactive-normal",
        "--focus-primary",
        "--bg-base-primary",
        "--bg-surface-raised",
        "--border-subtle",
    )
    for token in required:
        report(
            bool(re.search(rf"{re.escape(token)}\s*:\s*var\(--lilith-", css)),
            f"{name}: maps {token} to the generated palette",
        )

    wanted = {
        "surface": colours.get("surface", ""),
        "onSurface": colours.get("onSurface", ""),
        "primary": colours.get("primary", ""),
        "outlineVariant": colours.get("outlineVariant", ""),
    }
    for role, value in wanted.items():
        report(
            bool(value) and declared.get(f"--lilith-{re.sub(r'(?<!^)(?=[A-Z])', '-', role).lower()}") == f"#{value}",
            f"{name}: carries the generated {role} role",
        )

    report(declared.get("--lilith-scheme", "").lower() == mode.lower(),
           f"{name}: palette records {mode} mode", declared.get("--lilith-scheme", ""))
    report(bool(re.search(rf"color-scheme\s*:\s*{re.escape(mode)}\s*;", css, re.IGNORECASE)),
           f"{name}: color-scheme follows {mode} mode")

    return declared


def check_contrast(name: str, declared: dict[str, str]) -> None:
    pairs = [
        ("body text on surface", "on-surface", "surface", 4.5),
        ("body text on container", "on-surface", "surface-container", 4.5),
        ("body text on highest surface", "on-surface", "surface-container-highest", 4.5),
        ("muted text on surface", "on-surface-variant", "surface", 4.5),
        ("muted text on container", "on-surface-variant", "surface-container", 4.5),
        ("muted text on highest surface", "on-surface-variant", "surface-container-highest", 4.5),
        ("text on primary", "on-primary", "primary", 4.5),
        ("text on primary container", "on-primary-container", "primary-container", 4.5),
        ("text on secondary", "on-secondary", "secondary", 4.5),
        ("text on tertiary", "on-tertiary", "tertiary", 4.5),
        ("text on error", "on-error", "error", 4.5),
        ("focus ring on surface", "primary", "surface", 3.0),
    ]
    for label, foreground, background, minimum in pairs:
        fg = declared.get(f"--lilith-{foreground}", "")
        bg = declared.get(f"--lilith-{background}", "")
        if not fg or not bg:
            report(False, f"{name}: {label} has both colours", f"{fg!r} on {bg!r}")
            continue
        value = contrast(fg, bg)
        report(value >= minimum, f"{name}: {label} meets {minimum:g}:1", f"{value:.2f}:1")


def check_pair(css_path: Path, scheme_path: Path) -> None:
    name = css_path.name
    try:
        raw = css_path.read_text(encoding="utf-8")
        scheme = json.loads(scheme_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        report(False, f"{name}: is readable", str(error))
        return

    css = strip_comments(raw)
    report(bool(css.strip()), f"{name}: is not empty")
    check_meta(name, raw)
    check_balanced(name, css)
    check_no_remote(name, raw)
    colours = scheme.get("colours", {})
    mode = scheme.get("mode", "")
    declared = check_palette(name, css, colours, mode)
    check_contrast(name, declared)


def main() -> int:
    args = sys.argv[1:]
    if not args or len(args) % 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    print("discord theme contract")
    for index in range(0, len(args), 2):
        check_pair(Path(args[index]), Path(args[index + 1]))

    if failures:
        print(f"\n{failures} Discord theme check(s) failed ({checks} run)")
        return 1
    print(f"\n{checks} Discord theme checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
