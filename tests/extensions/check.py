#!/usr/bin/env python3
"""Contract checks for the bundled dashboard extensions.

Run from tests/extensions/run.sh. The checker parses every manifest in the
checkout catalog, then verifies the promises the dashboard relies on: unique
ids and shortcuts, resolvable tab URLs, wired shortcuts and settings text, and
theme colours that work in both light and dark schemes without hard-coded
palette values.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
CATALOG_ROOTS = (ROOT / "extensions", ROOT / "share" / "extensions")
NEW_EXTENSIONS = {"system-monitor", "pomodoro", "disk-usage"}
REQUIRED_KEYS = ("name", "description", "version", "icon", "tab")
FORBIDDEN_COMMANDS = (
    "sudo",
    "pkexec",
    "systemctl",
    "pacman",
    "mkfs",
    "wipefs",
    "fdisk",
    "parted",
    "shred",
    "dd if=",
)
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


def manifests() -> list[Path]:
    found: list[Path] = []
    for base in CATALOG_ROOTS:
        if not base.is_dir():
            continue
        found.extend(sorted(base.glob("*/extension.json")))
    return found


def qml_files(extension_dir: Path) -> list[Path]:
    return sorted(path for path in extension_dir.rglob("*.qml") if path.is_file())


def source_text(extension_dir: Path) -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in qml_files(extension_dir))


def main() -> int:
    found = manifests()
    if not found:
        bad("the extension catalog is not empty")
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    ok(f"found {len(found)} extension manifests")

    ids: dict[str, str] = {}
    shortcuts: dict[str, str] = {}
    tab_urls: dict[str, str] = {}
    catalog: list[tuple[str, Path, dict[str, object]]] = []

    for manifest_path in found:
        extension_dir = manifest_path.parent
        extension_id = extension_dir.name
        label = str(manifest_path.relative_to(ROOT))

        try:
            data = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            bad(f"{label} parses as JSON", str(error))
            continue

        ok(f"{label} parses as JSON")

        if not isinstance(data, dict):
            bad(f"{label} is an object")
            continue

        catalog.append((extension_id, extension_dir, data))

        if extension_id in ids:
            bad(f"extension id {extension_id!r} is unique", f"also in {ids[extension_id]}")
        else:
            ids[extension_id] = label

        for key in REQUIRED_KEYS:
            value = data.get(key)
            if not isinstance(value, str) or not value.strip():
                bad(f"{label} has a non-empty {key!r}")

        tab = data.get("tab")
        if isinstance(tab, str) and tab:
            tab_path = (extension_dir / tab).resolve()
            try:
                inside = tab_path.is_relative_to(extension_dir.resolve())
            except AttributeError:  # Python < 3.9
                inside = extension_dir.resolve() in tab_path.parents
            if inside and tab_path.is_file() and tab_path.suffix == ".qml":
                ok(f"{label} tab resolves inside its extension")
                tab_url = f"file://{tab_path}"
                if tab_url in tab_urls:
                    bad(f"{label} tab URL is unique", f"also used by {tab_urls[tab_url]}")
                else:
                    tab_urls[tab_url] = label
                    ok(f"{label} tab URL is unique")
            else:
                bad(f"{label} tab resolves inside its extension", str(tab_path))

        shortcut = data.get("shortcut", "")
        if extension_id in NEW_EXTENSIONS and (not isinstance(shortcut, str) or not shortcut.strip()):
            bad(f"{label} declares a shortcut")
        if isinstance(shortcut, str) and shortcut.strip():
            normalised = " ".join(shortcut.lower().split())
            if normalised in shortcuts:
                bad(f"{label} shortcut is unique ({shortcut})", f"also used by {shortcuts[normalised]}")
            else:
                shortcuts[normalised] = label
                ok(f"{label} shortcut is unique ({shortcut})")
        elif shortcut not in ("", None):
            bad(f"{label} shortcut is a string")

    missing = sorted(NEW_EXTENSIONS - ids.keys())
    if missing:
        bad("system-monitor, pomodoro and disk-usage are present", ", ".join(missing))
    else:
        ok("system-monitor, pomodoro and disk-usage are present")

    shortcuts_qml = (ROOT / "shell" / "modules" / "Shortcuts.qml").read_text(encoding="utf-8")
    for extension_id, _extension_dir, data in catalog:
        shortcut = data.get("shortcut", "")
        if isinstance(shortcut, str) and shortcut.strip():
            call = f'root.openExtension("{extension_id}")'
            if call in shortcuts_qml:
                ok(f"{extension_id} shortcut is wired into the shell")
            else:
                bad(f"{extension_id} shortcut is wired into the shell", call)

    extensions_page = (ROOT / "shell" / "modules" / "nexus" / "pages" / "ExtensionsPage.qml").read_text(encoding="utf-8")
    if "modelData.shortcut" in extensions_page and "modelData.description" in extensions_page:
        ok("the settings page shows manifest descriptions and shortcuts")
    else:
        bad("the settings page shows manifest descriptions and shortcuts")

    service = (ROOT / "shell" / "services" / "Extensions.qml").read_text(encoding="utf-8")
    if "tabUrl" in service and "extension.json" in service and "manifest.tab" in service:
        ok("the extension service builds tab URLs from the manifest")
    else:
        bad("the extension service builds tab URLs from the manifest")

    by_id = {extension_id: (extension_dir, data) for extension_id, extension_dir, data in catalog}

    system_dir = by_id.get("system-monitor", (None, {}))[0]
    if system_dir is not None:
        system = source_text(system_dir)
        for marker in ("Cpu.percentage", "Memory.percentage", "/proc/loadavg", "ServiceRef"):
            if marker in system:
                ok(f"system-monitor uses {marker}")
            else:
                bad(f"system-monitor uses {marker}")
        if "Process {" not in system:
            ok("system-monitor does not spawn a polling process")
        else:
            bad("system-monitor does not spawn a polling process")

    pomodoro_dir = by_id.get("pomodoro", (None, {}))[0]
    if pomodoro_dir is not None:
        pomodoro = source_text(pomodoro_dir)
        for marker in ("notify-send", "Quickshell.execDetached", "focusMinutes", "breakMinutes", "function reset"):
            if marker in pomodoro:
                ok(f"pomodoro provides {marker}")
            else:
                bad(f"pomodoro provides {marker}")
        if "running: root.active && root.running" in pomodoro:
            ok("pomodoro stops its timer when the tab is inactive")
        else:
            bad("pomodoro stops its timer when the tab is inactive")
        if "Process {" not in pomodoro:
            ok("pomodoro leaves no background process")
        else:
            bad("pomodoro leaves no background process")

    disk_dir = by_id.get("disk-usage", (None, {}))[0]
    if disk_dir is not None:
        disk = source_text(disk_dir)
        for marker in ("Storage.disks", "ServiceRef", "read-only"):
            if marker in disk:
                ok(f"disk-usage uses {marker}")
            else:
                bad(f"disk-usage uses {marker}")
        for marker in ("FolderListModel", "Process {", "api.paths.home"):
            if marker in disk:
                bad(f"disk-usage does not scan the home directory ({marker})")
            else:
                ok(f"disk-usage does not scan the home directory ({marker})")

    for extension_id in sorted(NEW_EXTENSIONS):
        entry = by_id.get(extension_id)
        if entry is None:
            continue
        extension_dir, _data = entry
        text = source_text(extension_dir)
        found_commands = [command for command in FORBIDDEN_COMMANDS if re.search(rf"\b{re.escape(command)}\b", text)]
        if found_commands:
            bad(f"{extension_id} adds no privileged or destructive commands", ", ".join(found_commands))
        else:
            ok(f"{extension_id} adds no privileged or destructive commands")

    # Both modes come from the same M3 roles; a raw hex or CSS name is a
    # palette that will not follow the wallpaper and will fail one of them.
    for extension_id, extension_dir, _data in catalog:
        sources = qml_files(extension_dir)
        text = "\n".join(path.read_text(encoding="utf-8") for path in sources)
        raw = HEX_COLOUR.findall(text)
        named = NAMED_COLOUR.findall(text)
        if raw or named:
            bad(f"{extension_id} uses palette colours in both modes", ", ".join(raw + named))
        else:
            ok(f"{extension_id} uses palette colours in both modes")

        widget = extension_dir / "Widget.qml"
        if not widget.is_file():
            bad(f"{extension_id} has a Widget.qml")
            continue
        widget_source = widget.read_text(encoding="utf-8")
        has_foreground = "m3onSurface" in widget_source or "m3onSurfaceVariant" in widget_source
        has_surface = any(token in widget_source for token in ("m3surface", "m3primary", "m3secondary", "m3tertiary", "m3error"))
        has_api = "api.colours" in widget_source or "api && root.api.colours" in widget_source
        if has_foreground and has_surface and has_api:
            ok(f"{extension_id} derives foreground and surface from api.colours")
        else:
            bad(
                f"{extension_id} derives foreground and surface from api.colours",
                f"foreground={has_foreground} surface={has_surface} api={has_api}",
            )

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
