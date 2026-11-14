#!/usr/bin/env python3
"""Contract checks for the translator extension layout.

The runtime size checks live in ``size.qml``; these static checks make sure the
layout, interaction and provider markers stay in place even when Quickshell is
not installed in the test environment.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
TRANSLATOR = ROOT / "extensions" / "translator"
HEX_COLOUR = re.compile(r"#[0-9a-fA-F]{3,8}\b")
NAMED_COLOUR = re.compile(r'"(?:white|black|red|green|blue|gray|grey|lightgray|darkgray)"', re.IGNORECASE)

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


def read(name: str) -> str:
    path = TRANSLATOR / name
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{name} is readable", str(error))
        return ""


def require(name: str, text: str, markers: tuple[str, ...]) -> None:
    for marker in markers:
        if marker in text:
            ok(f"{name} keeps {marker!r}")
        else:
            bad(f"{name} keeps {marker!r}")


def main() -> int:
    tab = read("Tab.qml")
    widget = read("Widget.qml")
    if not tab or not widget:
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    require(
        "Tab.qml",
        tab,
        (
            "readonly property int minimumWidth: 360",
            "readonly property int minimumHeight: 280",
            "readonly property bool compact: width < 640 || height < 420",
            "implicitWidth: Math.max(480, minimumWidth)",
            "implicitHeight: Math.max(280, minimumHeight)",
            "compact: root.compact",
        ),
    )

    require(
        "Widget.qml",
        widget,
        (
            "readonly property bool compactLayout",
            "readonly property int minimumSourceHeight",
            "readonly property int minimumResultHeight",
            "Layout.minimumHeight: root.minimumSourceHeight",
            "Layout.minimumHeight: root.minimumResultHeight",
            "anchors.fill: parent",
            "layout",
            "languageRow",
            "swapButton",
            "footer",
            "statusLabel",
            "labelText",
            "fieldLabel",
            "ActionButton",
            "ColumnLayout",
            "Tokens.padding",
            "Tokens.spacing",
        ),
    )

    # The result and source are real scroll views, and the footer is a separate
    # row from the language controls.
    for marker in ("ScrollView", "clip: true", "ScrollBar.vertical"):
        if marker in widget:
            ok(f"Widget.qml keeps a scrollable text panel ({marker})")
        else:
            bad(f"Widget.qml keeps a scrollable text panel ({marker})")

    # Interaction promises: clipboard prefill/copy, language selection, busy and
    # error states, and keyboard focus.
    for marker in (
        "pasteProc",
        "wl-paste",
        "copyProc",
        "wl-copy",
        "LanguagePicker",
        "selectedIndex",
        "statusIsError",
        "busy",
        "Translating…",
        "activeFocusOnTab",
        "Keys.onReturnPressed",
        "Keys.onSpacePressed",
        "focusEditor",
        "forceActiveFocus",
    ):
        if marker in widget:
            ok(f"Widget.qml keeps {marker!r}")
        else:
            bad(f"Widget.qml keeps {marker!r}")

    # The translation provider is intentionally unchanged by a layout fix.
    provider = (
        "https://api.mymemory.translated.net/get?q=",
        '["curl", "-fsSL", "--max-time", "20", url]',
        "responseStatus",
        "responseData.translatedText",
    )
    for marker in provider:
        if marker in widget:
            ok(f"Widget.qml keeps the MyMemory request marker {marker!r}")
        else:
            bad(f"Widget.qml keeps the MyMemory request marker {marker!r}")

    if "XMLHttpRequest" in widget:
        bad("Widget.qml still uses the unchanged curl provider, not XMLHttpRequest")
    else:
        ok("Widget.qml still uses the unchanged curl provider")

    # No palette values outside the api.colours roles.
    text = "\n".join(path.read_text(encoding="utf-8") for path in sorted(TRANSLATOR.glob("*.qml")))
    raw = HEX_COLOUR.findall(text)
    named = NAMED_COLOUR.findall(text)
    if raw or named:
        bad("translator uses palette colours in both modes", ", ".join(raw + named))
    else:
        ok("translator uses palette colours in both modes")

    if "Qt.lighter" in text or "Qt.darker" in text:
        bad("translator derives hover states from palette roles, not Qt.lighter/darker")
    else:
        ok("translator derives hover states from palette roles")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
