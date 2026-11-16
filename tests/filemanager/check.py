#!/usr/bin/env python3
"""Contract checks for the Files keyboard/Vim work.

The runtime harness in load.qml proves the tab loads and focus switches; this
checker keeps the promises that are easy to lose in a refactor: the old keys
are still wired, the Vim guard exists, the address bar and file-dialog focus
rings are present, and no destructive command crept into the tab.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
TAB = ROOT / "extensions" / "filemanager" / "Tab.qml"
WIDGET = ROOT / "extensions" / "filemanager" / "Widget.qml"
KEYS = ROOT / "extensions" / "filemanager" / "Keybindings.js"
CHECKLIST = ROOT / "docs" / "files-keyboard-checklist.md"
FILEDIALOG = ROOT / "shell" / "components" / "filedialog"

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
    keys = text(KEYS)

    require(tab, "Tab.qml", (
        "objectName: \"fileManagerTab\"",
        "readonly property int minimumWidth: 520",
        "readonly property int minimumHeight: 360",
        "implicitWidth: Math.max",
        "implicitHeight: Math.max",
        "active: root.active",
    ))

    require(widget, "Widget.qml", (
        "property bool vimEnabled: false",
        "property bool searchActive: false",
        "property bool editingPath: false",
        "readonly property bool textEditing:",
        "readonly property string modeLabel:",
        "function dispatchVim(",
        "function handleKeyEvent(",
        "function openSearch(",
        "function clearSearch(",
        "function focusAddressBar(",
        "function commitAddressBar(",
        "function cancelAddressBar(",
        "function moveToFirst(",
        "function moveToLast(",
        "function movePage(",
        "Keys.onUpPressed",
        "Keys.onDownPressed",
        "Keys.onReturnPressed",
        "Keys.onEnterPressed",
        "Qt.Key_Backspace",
        "Qt.ControlModifier",
        "objectName: \"fileManagerList\"",
        "objectName: \"fileManagerSearch\"",
        "objectName: \"fileManagerAddressField\"",
        "objectName: \"fileManagerVimToggle\"",
        "objectName: \"fileManagerMode\"",
        "objectName: \"fileManagerFocusRing\"",
        "border.width: fileList.activeFocus",
        "border.width: searchField.activeFocus",
        "border.width: addressField.activeFocus",
        "activeFocusOnTab: true",
        "Accessible.role: Accessible.EditableText",
        "MouseArea {",
        "onClicked: {",
        "onDoubleClicked: root.activateIndex(row.index)",
    ))

    # Mouse operation must survive the keyboard work: click selects and
    # double-click opens, exactly as before Vim mode existed.
    if "rowMouse" in widget and "onClicked" in widget and "onDoubleClicked" in widget:
        ok("Files row keeps click-to-select and double-click-to-open")
    else:
        bad("Files row keeps click-to-select and double-click-to-open")

    # The guard must run before the table is consulted, not after a movement.
    guard = re.search(r"function dispatchVim[\s\S]*?if \(!root\.vimEnabled \|\| root\.textEditing", widget)
    if guard:
        ok("Vim bindings stop while a text editor has focus")
    else:
        bad("Vim bindings stop while a text editor has focus")

    # The old contract: a single key never deletes, moves or renames a file.
    for marker in ("Qt.Key_Delete", "Qt.Key_DeletePressed", "deleteFile", "moveFile", "renameFile", "trashFile"):
        if marker in widget:
            bad(f"Files tab has no single-key destructive action ({marker})")
        else:
            ok(f"Files tab has no single-key destructive action ({marker})")

    destructive_commands = re.findall(r'command:\s*\[[^\]]*\b(?:rm|mv|trash|unlink|shred)\b', widget)
    if destructive_commands:
        bad("Files tab spawns no destructive process", ", ".join(destructive_commands))
    else:
        ok("Files tab spawns no destructive process")

    # A future destructive binding must carry the confirmation flag.
    if "requiresConfirm" in keys and "destructiveActions" in keys:
        ok("binding table has an explicit confirmation hook")
    else:
        bad("binding table has an explicit confirmation hook")

    filedialog = text(FILEDIALOG / "FileDialog.qml")
    sidebar = text(FILEDIALOG / "Sidebar.qml")
    header = text(FILEDIALOG / "HeaderBar.qml")
    contents = text(FILEDIALOG / "FolderContents.qml")

    require(filedialog, "FileDialog.qml", (
        "Shortcut {",
        'sequence: "Ctrl+L"',
        'sequence: "Ctrl+B"',
        'sequence: "Alt+Up"',
        'sequence: "F6"',
        "function focusSidebar(",
        "function focusAddressBar(",
        "function focusContents(",
    ))
    require(sidebar, "Sidebar.qml", (
        "objectName: \"fileDialogSidebar\"",
        "function focusSelectedPlace(",
        "activeFocusOnTab: true",
        "border.width: place.activeFocus",
        "Keys.onReturnPressed: place.activate()",
        "Keys.onSpacePressed: place.activate()",
        "onClicked: {",
    ))
    require(header, "HeaderBar.qml", (
        "objectName: \"fileDialogHeaderBar\"",
        "objectName: \"fileDialogAddressBar\"",
        "function focusAddressBar(",
        "activeFocusOnTab: true",
        "border.width: crumb.activeFocus",
        "Keys.onReturnPressed: activate()",
        "Keys.onLeftPressed:",
        "Keys.onRightPressed:",
    ))
    require(contents, "FolderContents.qml", (
        "function focusView(",
        "objectName: \"fileDialogFocusRing\"",
        "border.width: view.activeFocus",
        "onClicked: view.currentIndex = item.index",
        "onDoubleClicked: {",
    ))

    checklist = text(CHECKLIST)
    require(checklist, "files keyboard checklist", (
        "Vim mode",
        "Ctrl + L",
        "Ctrl + B",
        "Alt + Up",
        "Ctrl + d",
        "Ctrl + u",
        "No single key deletes",
        "double-click",
    ))

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
