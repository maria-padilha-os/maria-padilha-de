#!/usr/bin/env python3
"""Contract checks for the graphical calculator.

The calculator must keep the qalc command backend, expose the full keypad and
a visible history, use shared design tokens and palette roles, and never hand
an expression to a shell.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
TAB = ROOT / "extensions" / "calculator" / "Tab.qml"
WIDGET = ROOT / "extensions" / "calculator" / "Widget.qml"
HEX_COLOUR = re.compile(r"#[0-9a-fA-F]{3,8}\b")
NAMED_COLOUR = re.compile(r'"(?:white|black|red|green|blue|gray|grey|lightgray|darkgray)"', re.IGNORECASE)
SHELL_CALL = re.compile(r"(?:\b(?:sh|bash|zsh)\s+-c\b|\bQt\.shell\b|\$\{)")

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


def text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{path.relative_to(ROOT)} is readable", str(error))
        return ""


def require(source: str, label: str, markers: tuple[str, ...]) -> None:
    for marker in markers:
        if marker in source:
            ok(f"{label} keeps {marker!r}")
        else:
            bad(f"{label} keeps {marker!r}")


def main() -> int:
    tab = text(TAB)
    widget = text(WIDGET)

    require(tab, "Tab.qml", (
        "readonly property int minimumWidth: 360",
        "readonly property int minimumHeight: 460",
        "readonly property bool compact",
        "implicitWidth: Math.max",
        "implicitHeight: Math.max",
        'objectName: "calculatorWidget"',
        "active: root.active",
        "compact: root.compact",
    ))

    require(widget, "Widget.qml", (
        "property var history: []",
        "property alias expression: input.text",
        "readonly property int minimumWidth: 360",
        "readonly property int minimumHeight: 460",
        "readonly property int keyMinimumSize: 44",
        "function insert(",
        "function backspace(",
        "function clear(",
        "function press(",
        "function evaluate(",
        "function completeEvaluation(",
        "calculatorDisplay",
        "calculatorInput",
        "calculatorResult",
        "calculatorHistory",
        "calculatorKeypad",
        "activeFocusOnTab: true",
        "Accessible.Button",
        "Accessible.name:",
        "Tokens.padding",
        "Tokens.spacing",
        "Tokens.rounding",
        "Tokens.font",
        "m3surfaceContainerHigh",
        "m3surfaceContainerHighest",
        "m3secondaryContainer",
        "m3primary",
        "m3error",
        "m3outlineVariant",
    ))

    # The qalc backend is the same one-argument Process call as before, and it
    # is the only command the widget constructs.
    require(widget, "Widget.qml backend", (
        "Process {",
        'calcProc.command = ["qalc", "-t", expression]',
        "stdout: StdioCollector",
        "stderr: StdioCollector",
        "root.completeEvaluation(exitCode, calcOut.text, calcErr.text)",
    ))

    if "execDetached" in widget or "sh -c" in widget or "bash -c" in widget:
        bad("calculator never delegates user input to a shell")
    else:
        ok("calculator never delegates user input to a shell")

    shell_match = SHELL_CALL.search(widget)
    if shell_match:
        bad("calculator has no shell-interpolation marker", shell_match.group(0))
    else:
        ok("calculator has no shell-interpolation marker")

    for name in ("clear", "backspace", "equals"):
        marker = f'"value": "{name}"'
        if marker in widget:
            ok(f"keypad exposes {name}")
        else:
            bad(f"keypad exposes {name}")

    for value in ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "(", ")", "+", "-", "*", "/"):
        marker = f'"value": "{value}"'
        if marker in widget:
            ok(f"keypad exposes {value!r}")
        else:
            bad(f"keypad exposes {value!r}")

    for name in (
        "Open parenthesis",
        "Close parenthesis",
        "Divide",
        "Multiply",
        "Subtract",
        "Add",
        "Decimal point",
        "Clear",
        "Backspace",
        "Equals",
    ):
        if name in widget:
            ok(f"keypad has the accessible label {name!r}")
        else:
            bad(f"keypad has the accessible label {name!r}")

    for marker in ("font.pixelSize", 'font.family: "monospace"'):
        if marker in widget:
            bad(f"calculator uses typography tokens instead of {marker}")
        else:
            ok(f"calculator uses typography tokens instead of {marker}")

    raw = HEX_COLOUR.findall(widget + tab)
    named = NAMED_COLOUR.findall(widget + tab)
    if raw or named:
        bad("calculator uses palette colours in both modes", ", ".join(raw + named))
    else:
        ok("calculator uses palette colours in both modes")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
