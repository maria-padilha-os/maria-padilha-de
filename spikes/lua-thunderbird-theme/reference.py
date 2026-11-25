#!/usr/bin/env python3
"""Write the current Material You palette into the Thunderbird profile.

This exists because an older installed padilha-theme may not know about the
Thunderbird integration. It is safe to run repeatedly and is also usable as a
theme postHook; it only rewrites chrome/padilha.css.
"""
import json
import os
import re
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", Path.home()))
SCHEME = HOME / ".local/state/caelestia/scheme.json"
TEMPLATE = Path(__file__).resolve().parent.parent / "share/templates/thunderbird.css"


def profiles(root: Path):
    ini = root / "profiles.ini"
    if not ini.is_file():
        return []
    sections = {}
    current = None
    for raw in ini.read_text(errors="replace").splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections[current] = {}
        elif current and "=" in line and not line.startswith(("#", ";")):
            key, value = line.split("=", 1)
            sections[current][key.strip().lower()] = value.strip()
    install_default = None
    for name, values in sections.items():
        if name.startswith("Install") and values.get("default"):
            install_default = values["default"]
    if install_default:
        path = Path(install_default)
        if not path.is_absolute():
            path = root / path
        if path.is_dir():
            return [(True, path)]
    out = []
    for name, values in sections.items():
        if name.startswith("Profile") and values.get("path"):
            path = Path(values["path"])
            if not path.is_absolute():
                path = root / path
            if path.is_dir():
                out.append((values.get("default") == "1", path))
    return out


def profile_dir():
    roots = [
        Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "thunderbird",
        HOME / ".thunderbird",
        HOME / ".var/app/org.mozilla.Thunderbird/.thunderbird",
        HOME / "snap/thunderbird/common/.thunderbird",
    ]
    for root in roots:
        found = profiles(root)
        if found:
            return next((p for default, p in found if default), found[0][1])
    return None


def main():
    profile = profile_dir()
    if profile is None:
        return 0
    scheme = json.loads(SCHEME.read_text())
    template = TEMPLATE.read_text()
    colours = scheme["colours"]
    mode = scheme.get("mode", "dark")

    def replace(match):
        name = match.group(1)
        if name == "mode":
            return mode
        if name not in colours:
            raise SystemExit("missing palette role: " + name)
        return "#" + colours[name].lstrip("#")

    rendered = re.sub(r"\{\{\s*\$(\w+)\s*\}\}", replace, template)
    dest = profile / "chrome/padilha.css"
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_text(rendered)
    tmp.replace(dest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
