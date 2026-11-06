#!/usr/bin/env python3
"""Contract checks for the bundled extensions.

Run from tests/extensions/run.sh. It parses every manifest in the checkout's
extension catalog, checks the shortcut names and the settings wiring, and
audits the extensions that persist data so they only write under their own
~/.local/share/padilha state directory.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
CATALOG_ROOTS = (ROOT / "extensions", ROOT / "share" / "extensions")
NETWORK_MARKERS = (
    "http://",
    "https://",
    "XMLHttpRequest",
    "WebSocket",
    "fetch(",
    "curl ",
    "wget ",
    "telnet ",
    "nc ",
)
STATE_EXTENSIONS = {
    "notes": "padilha/notes",
    "calendar": "padilha/calendar",
}

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


def source_files(extension_dir: Path) -> list[Path]:
    return sorted(path for path in extension_dir.rglob("*") if path.is_file() and path.suffix in {".qml", ".js"})


def main() -> int:
    found = manifests()
    if not found:
        bad("the extension catalog is not empty")
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    ok(f"found {len(found)} extension manifests")

    shortcuts: dict[str, str] = {}
    ids: set[str] = set()
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

        if extension_id in ids:
            bad(f"extension id {extension_id!r} is unique")
        else:
            ids.add(extension_id)

        for key in ("name", "description", "version", "icon", "tab"):
            value = data.get(key)
            if not isinstance(value, str) or not value.strip():
                bad(f"{label} has a non-empty {key!r}")

        tab = data.get("tab")
        if isinstance(tab, str) and tab:
            tab_path = extension_dir / tab
            if tab_path.is_file():
                ok(f"{label} tab exists")
            else:
                bad(f"{label} tab exists", str(tab_path))

        shortcut = data.get("shortcut", "")
        if shortcut:
            if not isinstance(shortcut, str):
                bad(f"{label} shortcut is a string")
            else:
                normalised = " ".join(shortcut.lower().split())
                if normalised in shortcuts:
                    bad(f"{label} shortcut is unique", f"{shortcut} is also used by {shortcuts[normalised]}")
                else:
                    shortcuts[normalised] = str(manifest_path.relative_to(ROOT))
                    ok(f"{label} shortcut is unique ({shortcut})")

    shortcuts_qml = (ROOT / "shell" / "modules" / "Shortcuts.qml").read_text(encoding="utf-8")
    for manifest_path in found:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
        extension_id = manifest_path.parent.name
        if data.get("shortcut"):
            call = f'root.openExtension("{extension_id}")'
            if call in shortcuts_qml:
                ok(f"{extension_id} shortcut is wired into the shell")
            else:
                bad(f"{extension_id} shortcut is wired into the shell", call)

    extensions_page = (ROOT / "shell" / "modules" / "nexus" / "pages" / "ExtensionsPage.qml").read_text(encoding="utf-8")
    if "modelData.shortcut" in extensions_page:
        ok("the settings page shows manifest shortcuts")
    else:
        bad("the settings page shows manifest shortcuts")

    service = (ROOT / "shell" / "services" / "Extensions.qml").read_text(encoding="utf-8")
    if "share/extensions" in service and "extension.json" in service:
        ok("the extension service discovers share/extensions")
    else:
        bad("the extension service discovers share/extensions")

    for extension_id, state_suffix in STATE_EXTENSIONS.items():
        extension_dir = ROOT / "share" / "extensions" / extension_id
        if not extension_dir.is_dir():
            bad(f"{extension_id} lives in share/extensions")
            continue
        ok(f"{extension_id} lives in share/extensions")

        sources = source_files(extension_dir)
        text = "\n".join(path.read_text(encoding="utf-8") for path in sources)
        if state_suffix in text and "XDG_DATA_HOME" in text and ".local/share" in text:
            ok(f"{extension_id} uses its padilha state directory")
        else:
            bad(f"{extension_id} uses its padilha state directory", state_suffix)

        network = [marker for marker in NETWORK_MARKERS if marker in text]
        if network:
            bad(f"{extension_id} makes no network calls", ", ".join(network))
        else:
            ok(f"{extension_id} makes no network calls")

        outside = [
            marker
            for marker in ("/tmp/", "/etc/", "/usr/", "/home/", "XDG_CONFIG_HOME", "~/.config")
            if marker in text
        ]
        if outside:
            bad(f"{extension_id} has no hard-coded outside paths", ", ".join(outside))
        else:
            ok(f"{extension_id} has no hard-coded outside paths")

        # File-mutating shell commands must operate on the $1 state directory or
        # the $2 note/event path passed by QML, never a literal path.
        commands = re.findall(r'`([^`]*(?:mkdir|cp |mv |rm |printf|cat >)[^`]*)`', text)
        if not commands:
            bad(f"{extension_id} file writes are explicit")
            continue
        unsafe = [
            command
            for command in commands
            if "$1" not in command and "$2" not in command
        ]
        if unsafe:
            bad(f"{extension_id} only writes through its state path", unsafe[0])
        else:
            ok(f"{extension_id} only writes through its state path")

    converter_dir = ROOT / "share" / "extensions" / "unit-converter"
    converter = "\n".join(path.read_text(encoding="utf-8") for path in source_files(converter_dir))
    if all(marker not in converter for marker in ("Process", "FileView", "XMLHttpRequest", "http://", "https://")):
        ok("unit-converter has no processes, files, or network")
    else:
        bad("unit-converter has no processes, files, or network")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
