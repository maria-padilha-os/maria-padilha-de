#!/usr/bin/env python3
"""Static contracts for multi-monitor and hotplug behaviour.

The runtime behaviour is covered by model.test.js and the QML load check. This
file keeps the wiring honest: every per-output surface must use the deduplicated
Screens model, notifications must be routed to one output, and the layout file
must remain metadata-only.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SHELL = ROOT / "shell"

checks = 0
failures: list[str] = []


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
    try:
        return (ROOT / relative).read_text(encoding="utf-8")
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


def reject(relative: str, markers: tuple[str, ...]) -> None:
    text = read(relative)
    for marker in markers:
        if marker in text:
            bad(f"{relative} avoids {marker}")
        else:
            ok(f"{relative} avoids {marker}")


print("screen model wiring")

for relative in (
    "shell/services/ScreenModel.js",
    "shell/services/OutputLayout.js",
    "shell/services/Screens.qml",
    "shell/services/PanelLayout.qml",
):
    if (ROOT / relative).is_file():
        ok(f"{relative} exists")
    else:
        bad(f"{relative} exists")

require("shell/services/Screens.qml", (
    'import "ScreenModel.js" as ScreenModel',
    "selectScreens",
    "choosePrimary",
    "focusedName",
    "primaryName",
    "modelChanged",
))
reject("shell/services/Screens.qml", ("Quickshell.screens[0]", "Quickshell.screens[1]"))

require("shell/services/ShellState.qml", (
    "s.outputName === key",
    "const focused = Screens.focused",
    "return detached",
    "PanelLayout.reconcile",
    "boundTarget",
    "Component.onDestruction",
))
reject("shell/services/ShellState.qml", (
    "Hypr.monitorFor(s.modelData) === mon",
    "Hypr.monitorFor(c.modelData) === mon",
))

require("shell/modules/drawers/Drawers.qml", ("model: Screens.screens",))
require("shell/modules/background/Background.qml", ("Screens.screens", "GlobalConfig.forScreen"))
require("shell/modules/areapicker/AreaPicker.qml", ("model: Screens.screens",))
reject("shell/modules/clipboard/Clipboard.qml", ("Quickshell.screens[0]",))
reject("shell/modules/lock/Lock.qml", ("Quickshell.screens[0]",))

print("surfaces")

require("shell/modules/bar/BarWrapper.qml", (
    "PanelLayout.placement(screen",
    'placement.edge === "left"',
    "edgeOffset",
    "!screen ||",
))
require("shell/modules/drawers/Panels.qml", (
    "function placement",
    'root.placement("notifications")',
    'root.placement("launcher")',
    'root.placement("dashboard")',
))
require("shell/modules/launcher/Wrapper.qml", ("placementX", "placementY"))
require("shell/modules/dashboard/Wrapper.qml", ("placementX", "placementY"))
require("shell/modules/notifications/Wrapper.qml", ("placementX", "placementY"))
require("shell/modules/background/Wallpaper.qml", ("property bool alive", "Component.onDestruction", "!root.alive"))

print("notification routing")

require("shell/services/NotifData.qml", ("property string outputName",))
require("shell/services/Notifs.qml", (
    "function reconcileOutputs",
    "outputName: active?.outputName || Screens.primaryName",
    "outputName: n.outputName",
    "target: Screens",
))
require("shell/modules/notifications/Content.qml", (
    "readonly property string outputName",
    "(n.outputName || Screens.primaryName) === root.outputName",
))

print("layout file is metadata-only")

layout = read("shell/services/OutputLayout.js")
for panel in ("bar", "launcher", "dashboard", "notifications", "wallpaper"):
    if f'"{panel}"' in layout:
        ok(f"layout knows the {panel} panel")
    else:
        bad(f"layout knows the {panel} panel")

for forbidden in (
    "screenshot",
    "thumbnail",
    "wallpaperPath",
    "windowTitle",
    "pixels",
    "base64",
):
    # The comments explicitly promise these are not stored; only flag an
    # assignment or object key, not the prose that documents the rule.
    pattern = re.compile(rf"(?m)(?:\b{forbidden}\s*:|\.{forbidden}\s*=)")
    if pattern.search(layout):
        bad(f"layout does not store {forbidden}")
    else:
        ok(f"layout does not store {forbidden}")

require("shell/services/PanelLayout.qml", (
    "PADILHA_PANEL_LAYOUT",
    "panel-layout.json",
    "OutputLayout.sanitise",
    "mkdir",
))

print("documentation")

docs = read("docs/multi-monitor.md")
for marker in (
    "Test matrix",
    "nested",
    "headless",
    "rotate",
    "scale",
    "Hyprland",
    "panel positions",
    "private",
    "panel-layout.json",
):
    if marker.lower() in docs.lower():
        ok(f"multi-monitor docs mention {marker}")
    else:
        bad(f"multi-monitor docs mention {marker}")

all_tests = read("tests/all.sh")
if "tests/screens/run.sh" in all_tests:
    ok("tests/all.sh runs the screens suite")
else:
    bad("tests/all.sh runs the screens suite")

print(f"\n{checks} checks, {len(failures)} failed")
if failures:
    print(json.dumps(failures, indent=2))
    raise SystemExit(1)
