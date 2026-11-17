#!/usr/bin/env python3
"""Static contracts for the accessibility and keyboard-only pass.

The runtime harness in load.qml proves the shared controls load and expose
their accessible names. This checker keeps the promises that are easy to lose
in a refactor: focus rings, Escape/Enter handlers, accessible labels, the
screen-reader checklist, reduced motion and font-scaling fallbacks.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SHELL = ROOT / "shell"
DOCS = ROOT / "docs"

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


def require(path: Path, label: str, markers: tuple[str, ...]) -> None:
    source = text(path)
    missing = [marker for marker in markers if marker not in source]
    if missing:
        bad(f"{label} keeps its accessibility contract", ", ".join(repr(marker) for marker in missing))
    else:
        ok(f"{label} keeps its accessibility contract")


def main() -> int:
    require(SHELL / "services" / "Accessibility.qml", "Accessibility singleton", (
        "PADILHA_REDUCED_MOTION",
        "readonly property bool reducedMotion",
        "function motion(",
        "focusRingWidth",
    ))
    require(SHELL / "components" / "FocusRing.qml", "focus ring", (
        "required property Item target",
        "target.activeFocus",
        "Colours.palette.m3primary",
        "Accessibility.focusRingWidth",
    ))

    for name in ("Anim.qml", "AnchorAnim.qml", "CAnim.qml"):
        source = text(SHELL / "components" / name)
        if "Accessibility.motion(" in source:
            ok(f"{name} honours reduced motion")
        else:
            bad(f"{name} honours reduced motion")

    require(SHELL / "components" / "controls" / "ButtonBase.qml", "ButtonBase", (
        "activeFocusOnTab: true",
        "Accessible.role:",
        "Accessible.name: accessibleName",
        "Accessible.onPressAction:",
        "Keys.onReturnPressed:",
        "Keys.onSpacePressed:",
        "FocusRing {",
    ))
    require(SHELL / "components" / "controls" / "TextFieldBase.qml", "text field", (
        "activeFocusOnTab: true",
        "Accessible.role: Accessible.EditableText",
        "Accessible.name:",
        "Accessible.passwordEdit:",
    ))
    require(SHELL / "components" / "controls" / "StyledSwitch.qml", "switch", (
        "Accessible.role: Accessible.CheckBox",
        "Accessible.checked: checked",
        "Keys.onSpacePressed:",
        "FocusRing {",
    ))
    require(SHELL / "components" / "controls" / "StyledRadioButton.qml", "radio button", (
        "Accessible.role: Accessible.RadioButton",
        "Accessible.checked: checked",
        "Keys.onSpacePressed:",
        "FocusRing {",
    ))
    for name in ("StyledSlider.qml", "FilledSlider.qml"):
        require(SHELL / "components" / "controls" / name, name, (
            "Accessible.role: Accessible.Slider",
            "Keys.onLeftPressed:",
            "Keys.onRightPressed:",
            "FocusRing {",
        ))

    # The keyboard entry points and their Escape/Enter behaviour.
    require(SHELL / "modules" / "drawers" / "ContentWindow.qml", "drawer keyboard focus", (
        "screenState.dashboard",
        "screenState.barFocus",
        "WlrKeyboardFocus.OnDemand",
    ))
    require(SHELL / "modules" / "Shortcuts.qml", "taskbar shortcut", (
        'name: "taskbar"',
        "screenState.barFocus = !screenState.barFocus",
    ))
    require(SHELL / "modules" / "bar" / "Bar.qml", "bar keyboard handling", (
        "focus: root.screenState.barFocus",
        "Keys.onEscapePressed:",
        "root.popouts.hasCurrent = false",
    ))
    require(SHELL / "modules" / "launcher" / "Content.qml", "launcher keyboard handling", (
        "Keys.onEscapePressed:",
        "Keys.onUpPressed:",
        "Keys.onDownPressed:",
        "search.forceActiveFocus()",
    ))
    require(SHELL / "modules" / "dashboard" / "Content.qml", "dashboard keyboard handling", (
        "Keys.onEscapePressed:",
        "Keys.onLeftPressed:",
        "Keys.onRightPressed:",
        "forceActiveFocus()",
    ))
    require(SHELL / "modules" / "dashboard" / "Tabs.qml", "dashboard tab semantics", (
        "Accessible.role: Accessible.PageTab",
        "Accessible.selected:",
        "activeFocusOnTab: true",
        "FocusRing {",
    ))
    require(SHELL / "modules" / "nexus" / "Nexus.qml", "settings keyboard handling", (
        "Keys.onEscapePressed:",
        "nState.closeSubPage()",
        "forceActiveFocus()",
    ))
    require(SHELL / "modules" / "nexus" / "navpane" / "NavLocations.qml", "settings navigation", (
        "Accessible.role: Accessible.PageTab",
        "Keys.onUpPressed:",
        "Keys.onDownPressed:",
        "Keys.onReturnPressed:",
        "FocusRing {",
    ))

    # Icon-only controls on the main surfaces carry names.
    for relative, markers in {
        "modules/bar/components/OsIcon.qml": ("Open launcher",),
        "modules/bar/components/Settings.qml": ("Open settings",),
        "modules/bar/components/Power.qml": ("Session menu",),
        "modules/bar/components/Clock.qml": ("Clock:",),
        "modules/bar/components/Media.qml": ("Accessible.name:",),
        "modules/bar/components/workspaces/Workspaces.qml": ("Accessible.role:",),
        "modules/bar/popouts/Media.qml": ("Previous track", "Pause", "Next track"),
        "modules/bar/popouts/Bluetooth.qml": ("Accessible.name:",),
        "modules/bar/popouts/Network.qml": ("Accessible.name:",),
        "modules/bar/popouts/Battery.qml": ("Accessible.role: Accessible.RadioButton",),
    }.items():
        source = text(SHELL / relative)
        missing = [marker for marker in markers if marker not in source]
        if missing:
            bad(f"{relative} names its icon-only controls", ", ".join(missing))
        else:
            ok(f"{relative} names its icon-only controls")

    # Every extension that contains interactive controls must expose at least
    # one accessible name. Purely informational widgets (system monitor, disk
    # usage) have no interactive control and are deliberately skipped.
    extension_dirs = []
    for base in (ROOT / "extensions", ROOT / "share" / "extensions"):
        if base.is_dir():
            extension_dirs.extend(path for path in base.iterdir() if path.is_dir())
    for directory in sorted(extension_dirs):
        sources = list(directory.rglob("*.qml"))
        if not sources:
            continue
        combined = "\n".join(path.read_text(encoding="utf-8") for path in sources)
        interactive = any(marker in combined for marker in ("MouseArea {", "IconButton {", "TextButton {", "ActionButton"))
        if not interactive:
            continue
        if "Accessible." in combined and "Keys.on" in combined:
            ok(f"extension {directory.name} exposes accessible keyboard controls")
        else:
            bad(
                f"extension {directory.name} exposes accessible keyboard controls",
                "needs Accessible.* and a Keys.on* handler",
            )

    # Font scaling: launcher rows grow with the font token instead of clipping
    # at the raw 57 px token; the bar gets the same treatment.
    launcher = text(SHELL / "modules" / "launcher" / "AppList.qml")
    if "delegateHeight:" in launcher and "pointSize" in launcher:
        ok("launcher height follows the scaled font")
    else:
        bad("launcher height follows the scaled font")
    for item in (SHELL / "modules" / "launcher" / "items").glob("*.qml"):
        source = item.read_text(encoding="utf-8")
        if "implicitHeight: Tokens.sizes.launcher.itemHeight" in source:
            bad(f"{item.name} keeps a fixed launcher row height")
        else:
            ok(f"{item.name} grows with the scaled font")
    require(SHELL / "modules" / "bar" / "BarWrapper.qml", "bar width scaling", (
        "Tokens.font.icon.medium.pointSize",
        "Math.max(",
    ))

    # The palette token, not a one-off component override, keeps outline text
    # readable in the light scheme.
    scheme = text(ROOT / "lib" / "scheme.lua")
    if re.search(r'\{\s*"outline",\s*"nv",\s*40\s*\}', scheme):
        ok("light outline token clears the text contrast threshold")
    else:
        bad("light outline token clears the text contrast threshold")

    # Documentation is part of the deliverable: without it a screen-reader
    # user has no manual checklist and reduced motion is undiscoverable.
    checklist = text(DOCS / "accessibility.md")
    for marker in (
        "Screen-reader checklist",
        "Keyboard-only checklist",
        "PADILHA_REDUCED_MOTION",
        "Escape",
        "Tab",
        "contrast",
        "font scaling",
        "Reduced motion",
    ):
        if marker.lower() in checklist.lower():
            ok(f"accessibility checklist mentions {marker!r}")
        else:
            bad(f"accessibility checklist mentions {marker!r}")

    config = text(DOCS / "_config.yml")
    if "accessibility.md" in config:
        ok("the accessibility page is in the docs navigation")
    else:
        bad("the accessibility page is in the docs navigation")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
