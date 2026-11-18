#!/usr/bin/env python3
"""Localization contract: catalogs cover every extracted string and stay valid.

The source tree is the single source of truth. This test regenerates the POT
with the same `trs.fish` extractor the build uses, then checks both catalogs
against it. It also checks desktop-entry locales and the bundled extension
manifests, which are data files rather than calls xgettext can see.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SHELL = ROOT / "shell"
I18N = SHELL / "plugin" / "src" / "Caelestia" / "I18n"
TRS = I18N / "trs"
CATALOGS = ("en", "pt_BR")

failures: list[str] = []
checks = 0

_PLACEHOLDER_RE = re.compile(r"%(?:L?[0-9]+|L?n|%)")
_FIELD_RE = re.compile(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+"(.*)"$')


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


def unescape(value: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(value):
        char = value[i]
        if char != "\\" or i + 1 >= len(value):
            out.append(char)
            i += 1
            continue
        nxt = value[i + 1]
        mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\",
                   "a": "\a", "b": "\b", "f": "\f", "v": "\v", "0": "\0"}
        if nxt in mapping:
            out.append(mapping[nxt])
            i += 2
        elif nxt == "x" and i + 3 < len(value):
            out.append(chr(int(value[i + 2 : i + 4], 16)))
            i += 4
        elif nxt in "01234567":
            end = i + 2
            while end < len(value) and end < i + 4 and value[end] in "01234567":
                end += 1
            out.append(chr(int(value[i + 1 : end], 8)))
            i = end
        else:
            out.append(nxt)
            i += 2
    return "".join(out)


def parse_block(lines: list[str]) -> dict:
    entry: dict = {"comments": [], "refs": [], "flags": [], "ctx": "", "msgid": "",
                   "plural": "", "msgstr": "", "msgstrs": []}
    field = None
    for line in lines:
        if line.startswith("#."):
            entry["comments"].append(line[2:].strip())
        elif line.startswith("#:"):
            entry["refs"].extend(line[2:].strip().split())
        elif line.startswith("#,"):
            entry["flags"].extend(part.strip() for part in line[2:].split(",") if part.strip())
        elif line.startswith("#"):
            continue
        else:
            match = _FIELD_RE.match(line)
            if match:
                field = match.group(1)
                value = unescape(match.group(3))
                index = match.group(2)
                if field == "msgctxt":
                    entry["ctx"] = value
                elif field == "msgid":
                    entry["msgid"] = value
                elif field == "msgid_plural":
                    entry["plural"] = value
                elif field == "msgstr":
                    entry["msgstr"] = value
                elif field.startswith("msgstr["):
                    while len(entry["msgstrs"]) <= int(index):
                        entry["msgstrs"].append("")
                    entry["msgstrs"][int(index)] = value
            elif field and line.strip().startswith('"'):
                value = unescape(line.strip()[1:-1])
                if field == "msgctxt":
                    entry["ctx"] += value
                elif field == "msgid":
                    entry["msgid"] += value
                elif field == "msgid_plural":
                    entry["plural"] += value
                elif field == "msgstr":
                    entry["msgstr"] += value
                elif field.startswith("msgstr["):
                    index = int(field[len("msgstr["):-1])
                    while len(entry["msgstrs"]) <= index:
                        entry["msgstrs"].append("")
                    entry["msgstrs"][index] += value
    return entry


def read_po(path: Path) -> list[dict]:
    entries: list[dict] = []
    block: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines() + [""]:
        if line.strip() == "":
            if block:
                entries.append(parse_block(block))
                block = []
            continue
        block.append(line)
    if block:
        entries.append(parse_block(block))
    return entries


def key(entry: dict) -> tuple[str, str, str]:
    return (entry["ctx"], entry["msgid"], entry["plural"])


def placeholders(text: str) -> list[str]:
    return sorted(_PLACEHOLDER_RE.findall(text))


def generate_pot(tmp: Path) -> Path:
    env = os.environ.copy()
    env["PADILHA_TRS_DIR"] = str(tmp)
    result = subprocess.run(
        ["fish", str(SHELL / "scripts" / "trs.fish"), "raw"],
        cwd=SHELL,
        env=env,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout).strip())
    return tmp / "raw.pot"


def check_catalog(language: str, pot: list[dict], po: list[dict]) -> None:
    path = TRS / f"{language}.po"
    header = next((e for e in po if e["msgid"] == ""), None)
    if header is None:
        bad(f"{language}.po has a catalog header")
        return
    ok(f"{language}.po has a catalog header")

    plural_forms = re.search(r"Plural-Forms:\s*nplurals=(\d+);\s*plural=([^\\\n]+)", header["msgstr"])
    if plural_forms:
        ok(f"{language}.po declares a plural rule")
    else:
        bad(f"{language}.po declares a plural rule")

    pot_map = {key(e): e for e in pot}
    po_map = {key(e): e for e in po if e["msgid"]}
    missing = sorted(set(pot_map) - set(po_map), key=lambda item: item[1])
    extra = sorted(set(po_map) - set(pot_map), key=lambda item: item[1])
    if missing:
        bad(f"{language}.po covers every extracted string",
            ", ".join(repr(item[1]) for item in missing[:8]))
    else:
        ok(f"{language}.po covers all {len(pot_map)} extracted strings")
    if extra:
        bad(f"{language}.po has no stale strings",
            ", ".join(repr(item[1]) for item in extra[:8]))
    else:
        ok(f"{language}.po has no stale strings")

    empty: list[str] = []
    fuzzy: list[str] = []
    broken_plural: list[str] = []
    placeholder_issues: list[str] = []
    for entry_key, pot_entry in pot_map.items():
        entry = po_map.get(entry_key)
        if entry is None:
            continue
        if "fuzzy" in entry["flags"]:
            fuzzy.append(pot_entry["msgid"])
        if pot_entry["plural"]:
            forms = entry["msgstrs"]
            if plural_forms and len(forms) != int(plural_forms.group(1)):
                broken_plural.append(pot_entry["msgid"])
                continue
            if any(not form for form in forms):
                empty.append(pot_entry["msgid"])
                continue
            sources = (pot_entry["msgid"], pot_entry["plural"])
            for index, form in enumerate(forms):
                if placeholders(form) != placeholders(sources[min(index, 1)]):
                    placeholder_issues.append(f"{pot_entry['msgid']} -> {form}")
                if ("%n" in sources[min(index, 1)] or "%Ln" in sources[min(index, 1)]) and \
                        "%n" not in form and "%Ln" not in form:
                    placeholder_issues.append(f"{pot_entry['msgid']} lost %n in {form}")
        else:
            if not entry["msgstr"]:
                empty.append(pot_entry["msgid"])
            elif placeholders(entry["msgstr"]) != placeholders(pot_entry["msgid"]):
                placeholder_issues.append(f"{pot_entry['msgid']} -> {entry['msgstr']}")

    if empty:
        bad(f"{language}.po has no empty translations", ", ".join(repr(item) for item in empty[:8]))
    else:
        ok(f"{language}.po has no empty translations")
    if fuzzy:
        bad(f"{language}.po has no fuzzy entries", ", ".join(repr(item) for item in fuzzy[:8]))
    else:
        ok(f"{language}.po has no fuzzy entries")
    if broken_plural:
        bad(f"{language}.po has the declared number of plural forms",
            ", ".join(repr(item) for item in broken_plural[:8]))
    else:
        ok(f"{language}.po follows the declared plural rule")
    if placeholder_issues:
        bad(f"{language}.po preserves placeholders",
            "; ".join(placeholder_issues[:5]))
    else:
        ok(f"{language}.po preserves placeholders")

    result = subprocess.run(
        ["msgfmt", "--check-format", "-o", os.devnull, str(path)],
        text=True,
        capture_output=True,
    )
    if result.returncode == 0:
        ok(f"msgfmt accepts {language}.po")
    else:
        bad(f"msgfmt accepts {language}.po", (result.stderr or result.stdout).strip())


def main() -> int:
    if not TRS.is_dir():
        bad("the translation directory exists", str(TRS))
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    for language in CATALOGS:
        if (TRS / f"{language}.po").is_file():
            ok(f"{language}.po exists")
        else:
            bad(f"{language}.po exists")

    cmake = (I18N / "CMakeLists.txt").read_text(encoding="utf-8")
    for language in CATALOGS:
        if f"trs/{language}.po" in cmake:
            ok(f"CMake compiles {language}.po")
        else:
            bad(f"CMake compiles {language}.po")

    for tool in ("fish", "xgettext", "msgfmt"):
        if subprocess.run(["sh", "-c", f"command -v {tool}"], capture_output=True).returncode == 0:
            ok(f"{tool} is available")
        else:
            bad(f"{tool} is available for localization tests")

    if not all((TRS / f"{language}.po").is_file() for language in CATALOGS):
        print(f"\n{checks} checks, {len(failures)} failed")
        return 1

    with tempfile.TemporaryDirectory() as tmp_name:
        try:
            pot_path = generate_pot(Path(tmp_name))
        except (OSError, RuntimeError) as error:
            bad("trs.fish regenerates the translation template", str(error))
            print(f"\n{checks} checks, {len(failures)} failed")
            return 1
        ok("trs.fish regenerates the translation template")
        pot = [e for e in read_po(pot_path) if e["msgid"]]
        if pot:
            ok(f"the template contains {len(pot)} translatable strings")
        else:
            bad("the template contains translatable strings")

    for language in CATALOGS:
        check_catalog(language, pot, read_po(TRS / f"{language}.po"))

    # Every bundled manifest name and description must be extractable and
    # translated. The extractor above appends these as Tr.tr calls.
    pot_ids = {entry["msgid"] for entry in pot}
    po_by_language = {
        language: {entry["msgid"]: entry for entry in read_po(TRS / f"{language}.po")}
        for language in CATALOGS
    }
    manifests = sorted((ROOT / "extensions").glob("*/extension.json")) + \
        sorted((ROOT / "share" / "extensions").glob("*/extension.json"))
    manifest_missing: list[str] = []
    for manifest in manifests:
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            bad(f"{manifest.relative_to(ROOT)} is valid JSON", str(error))
            continue
        for field in ("name", "description"):
            value = data.get(field)
            if not isinstance(value, str) or not value:
                continue
            if value not in pot_ids:
                manifest_missing.append(f"{manifest.parent.name}: {field}")
            for language in CATALOGS:
                entry = po_by_language[language].get(value)
                translated = ""
                if entry is not None:
                    translated = entry["msgstrs"][0] if entry["plural"] else entry["msgstr"]
                if not translated:
                    manifest_missing.append(f"{manifest.parent.name}: {field} ({language})")
    if manifest_missing:
        bad("extension manifest labels are in every catalog", ", ".join(manifest_missing[:8]))
    else:
        ok(f"all {len(manifests)} extension manifests have translated labels")

    desktop_checks = (
        (ROOT / "session" / "maria-padilha.desktop", ("Name", "Comment")),
        (ROOT / "share" / "applications" / "padilha-mail.desktop",
         ("Name", "GenericName", "Comment", "Keywords")),
    )
    desktop_issues: list[str] = []
    for path, fields in desktop_checks:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as error:
            desktop_issues.append(f"{path.relative_to(ROOT)}: {error}")
            continue
        for field in fields:
            if not re.search(rf"^{re.escape(field)}\[pt_BR\]=", text, re.M):
                desktop_issues.append(f"{path.name}: {field}[pt_BR]")
    if desktop_issues:
        bad("desktop files declare pt_BR labels", ", ".join(desktop_issues))
    else:
        ok("desktop files declare pt_BR labels")

    missing_imports: list[str] = []
    for base in (ROOT / "extensions", ROOT / "share" / "extensions"):
        for qml in sorted(base.rglob("*.qml")):
            text = qml.read_text(encoding="utf-8", errors="replace")
            if re.search(r"\bTr\.", text) and "import Caelestia.I18n" not in text:
                missing_imports.append(str(qml.relative_to(ROOT)))
    if missing_imports:
        bad("extension QML using Tr imports Caelestia.I18n", ", ".join(missing_imports[:8]))
    else:
        ok("extension QML using Tr imports Caelestia.I18n")

    # The existing source checker catches arity, empty sources, extra .arg
    # calls and QML using Tr without importing it.
    result = subprocess.run(
        [sys.executable, str(SHELL / "scripts" / "trs-check.py")],
        cwd=SHELL,
        text=True,
        capture_output=True,
    )
    if result.returncode == 0:
        ok("trs-check.py finds no translation-source issues")
    else:
        bad("trs-check.py finds no translation-source issues",
            (result.stderr or result.stdout).strip().splitlines()[-1] if (result.stderr or result.stdout) else "")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
