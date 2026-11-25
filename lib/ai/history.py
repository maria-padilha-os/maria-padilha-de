"""Opt-in transcript persistence for the assistant (ADR 0001).

``history = "persist"`` keeps the conversation in a JSONL file under the
broker's state directory, mode 0600.  There is no automatic pruning: the
transcript survives every shell restart and reboot until the user starts a new
chat or deletes the file.
"""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any, Iterable

ROLES = ("user", "assistant", "system")


def path_for(state_dir: Path) -> Path:
    return Path(state_dir) / "transcript.jsonl"


def load(path: Path) -> list[dict[str, str]]:
    """Return the stored messages, ignoring malformed lines."""

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return []
    except OSError:
        return []

    out: list[dict[str, str]] = []
    for line in lines:
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict):
            continue
        role = entry.get("role")
        text = entry.get("text")
        if role in ROLES and isinstance(text, str) and text.strip():
            out.append({"role": role, "text": text})
    return out


def save(path: Path, messages: Iterable[Any]) -> bool:
    """Atomically replace the transcript; returns False when it cannot write."""

    rows: list[dict[str, str]] = []
    for item in messages:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        text = item.get("text")
        if role in ROLES and isinstance(text, str) and text.strip():
            rows.append({"role": role, "text": text})

    try:
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".transcript.")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                for row in rows:
                    handle.write(json.dumps(row, ensure_ascii=False) + "\n")
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)
        except OSError:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
        return True
    except OSError:
        return False


def clear(path: Path) -> bool:
    try:
        path.unlink()
        return True
    except FileNotFoundError:
        return True
    except OSError:
        return False
