#!/usr/bin/env python3
"""Static contract for the Nexus search and keyboard-navigation surface."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
NEXUS = ROOT / "shell" / "modules" / "nexus"
COMPONENTS = ROOT / "shell" / "components"

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


def require(path: Path, markers: tuple[str, ...]) -> None:
    text = read(path)
    for marker in markers:
        if marker in text:
            ok(f"{path.relative_to(ROOT)} keeps {marker}")
        else:
            bad(f"{path.relative_to(ROOT)} keeps {marker}")


def main() -> int:
    require(NEXUS / "search" / "SearchRanking.js", (
        "function rank(",
        "function scoreEntry(",
        "function matchRanges(",
        "module.exports",
    ))
    require(NEXUS / "search" / "FocusNavigation.js", (
        "function clamp(",
        "function step(",
        "function stepInList(",
        "module.exports",
    ))
    require(NEXUS / "SettingsSearch.qml", (
        "pragma Singleton",
        "SettingsCatalog.settings",
        "SettingsCatalog.subPages",
        "Ranking.rank",
        "function search(",
    ))
    require(NEXUS / "SettingsCatalog.qml", (
        "pragma Singleton",
        "readonly property list<var> settings",
        "readonly property list<var> subPages",
        "Tr.tr(",
        "Night light",
        "Action prefix",
        "UI language",
        "Hostname",
        "Display wallpaper",
        "Show in fullscreen",
    ))
    require(NEXUS / "NexusState.qml", (
        "property string searchQuery",
        "property var searchTarget",
        "function setSearchQuery(",
        "function clearSearch(",
        "function navigateToSearchResult(",
        "signal pageResetRequested",
    ))
    require(NEXUS / "NavPane.qml", (
        'objectName: "nexusSearchField"',
        "function focusSearch(): void",
        "Keys.onDownPressed",
        "Keys.onEscapePressed",
        "onAccepted",
        "Accessible.name",
    ))
    require(NEXUS / "navpane" / "NavLocations.qml", (
        "searchMode",
        "SettingsSearch.search",
        "nexusSearchResult_",
        "nexusNoResults",
        "Keys.onUpPressed",
        "Keys.onDownPressed",
        "Keys.onReturnPressed",
        "Keys.onEscapePressed",
        "FocusRing {",
        "elide: Text.ElideRight",
        "maximumLineCount: 1",
        "Tr.tr(\"No settings found\")",
    ))
    require(NEXUS / "common" / "PageBase.qml", (
        "function moveFocus(",
        "function findSetting(",
        "function applySearchTarget(",
        "nexusSearchHighlight",
        "Keys.onUpPressed",
        "Keys.onDownPressed",
        "FocusNavigation.stepInList",
        "maximumLineCount: 1",
    ))
    require(COMPONENTS / "FocusRing.qml", (
        'objectName: "settingsFocusRing"',
        "target.activeFocus",
        "border.width: shown ? 2 : 0",
    ))
    require(COMPONENTS / "controls" / "SearchBar.qml", (
        "elide: Text.ElideRight",
        "maximumLineCount: 1",
    ))

    row_markers = {
        "ToggleRow.qml": ("settingsRow: true", "FocusRing {", "toggleFromKeyboard", "Keys.onReturnPressed"),
        "SelectRow.qml": ("settingsRow: true", "FocusRing {", "function openMenu", "Keys.onReturnPressed"),
        "SliderRow.qml": ("settingsRow: true", "FocusRing {", "Keys.onLeftPressed", "Keys.onRightPressed"),
        "TextFieldRow.qml": ("settingsRow: true", "FocusRing {", "function commit", "errorText", "wrapMode: Text.WordWrap"),
        "StepperRow.qml": ("settingsRow: true", "FocusRing {", "function activate", "Keys.onReturnPressed"),
        "RowButton.qml": ("settingsRow: true", "FocusRing {", "root.clicked(null)", "Keys.onReturnPressed"),
        "InfoRow.qml": ("settingsRow: true", "settingsInteractive: false"),
        "PopupRow.qml": ("settingsRow: true", "FocusRing {", "function openPopup", "Keys.onReturnPressed"),
    }
    for name, markers in row_markers.items():
        require(NEXUS / "common" / name, markers)

    # Every top-level page title should still be discoverable through the page
    # registry; the settings catalog adds the rows inside each page.
    page_registry = read(NEXUS / "PageRegistry.qml")
    catalog = read(NEXUS / "SettingsCatalog.qml")
    titles = re.findall(r'label:\s*Tr\.tr\("([^"]+)"\)', page_registry)
    search_text = read(NEXUS / "SettingsSearch.qml")
    missing = [title for title in titles if title not in catalog and title not in search_text and f'"{title}"' not in page_registry]
    if missing:
        bad("every page title is searchable", ", ".join(missing))
    else:
        ok(f"all {len(titles)} page titles are searchable")

    # Long translations must be handled by elision or wrapping at every text
    # surface added for search.
    nav = read(NEXUS / "navpane" / "NavLocations.qml")
    if nav.count("elide: Text.ElideRight") >= 5 and "wrapMode: Text.WordWrap" not in nav.split("nexusNoResults")[0]:
        ok("search rows elide long labels instead of clipping")
    else:
        bad("search rows elide long labels instead of clipping")

    # New QML should use the palette, not fixed colours.
    hardcoded = []
    for relative in (
        "SettingsSearch.qml",
        "SettingsCatalog.qml",
        "NavPane.qml",
        "navpane/NavLocations.qml",
        "common/PageBase.qml",
        "Nexus.qml",
        "NexusState.qml",
    ):
        text = read(NEXUS / relative)
        for match in re.findall(r"#[0-9a-fA-F]{3,8}\b", text):
            hardcoded.append(f"{relative}: {match}")
    if hardcoded:
        bad("new Nexus QML uses the palette", ", ".join(hardcoded))
    else:
        ok("new Nexus QML uses the palette")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
