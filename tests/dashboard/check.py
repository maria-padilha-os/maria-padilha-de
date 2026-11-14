#!/usr/bin/env python3
"""Regression checks for the dashboard tab host and built-in panels.

The QML import path for ``qs.*`` only exists when Quickshell runs the shell
tree, so the runtime loader test lives in tests/extensions. These checks cover
the layout contract that keeps the tab strip and panel edges from clipping.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
DASHBOARD = ROOT / "shell" / "modules" / "dashboard"
HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")

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


def read(relative: str) -> str:
    path = DASHBOARD / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{relative} is readable", str(error))
        return ""


def require(relative: str, markers: tuple[str, ...]) -> None:
    text = read(relative)
    for marker in markers:
        if marker in text:
            ok(f"{relative} keeps {marker}")
        else:
            bad(f"{relative} keeps {marker}")


def main() -> int:
    require("Tabs.qml", (
        "Layout.minimumWidth",
        "elide: Text.ElideRight",
        "maximumLineCount: 1",
        "Tokens.sizes.dashboard.tabIndicatorHeight",
        "minimumWidth:",
    ))
    require("Content.qml", (
        "Math.max(view.implicitWidth, tabs.minimumWidth)",
    ))
    require("ExtensionTab.qml", (
        "minimumWidth",
        "minimumHeight",
        "implicitWidth: Math.max(panelWidth, minimumWidth",
    ))
    require("Wrapper.qml", (
        "Tokens.sizes.dashboard.mediaTabWidth",
    ))
    if "854" in read("Wrapper.qml"):
        bad("Wrapper.qml does not hardcode the first-open width")
    else:
        ok("Wrapper.qml does not hardcode the first-open width")

    for panel in ("Dash.qml", "Media.qml", "Performance.qml", "WeatherTab.qml"):
        text = read(panel)
        if "implicitWidth" in text and "implicitHeight" in text:
            ok(f"{panel} declares its implicit size")
        else:
            bad(f"{panel} declares its implicit size")

    for path in sorted(DASHBOARD.rglob("*.qml")):
        text = path.read_text(encoding="utf-8")
        raw = HEX.findall(text)
        if raw:
            bad(f"{path.relative_to(ROOT)} uses a raw colour", ", ".join(raw))

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
