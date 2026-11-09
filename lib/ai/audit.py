"""Metadata-only audit trail for the home-access broker."""

from __future__ import annotations

import json
import os
import stat
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .redact import redact

MAX_AUDIT_BYTES = 10 * 1024 * 1024
KEEP = 5
_FORBIDDEN_FIELDS = frozenset(
    {"content", "file_content", "body", "prompt", "response", "text", "data"}
)


class Audit:
    def __init__(self, directory: Path) -> None:
        self.directory = directory
        self.path = directory / "audit.jsonl"
        self.last_error: str | None = None

    def _prepare(self) -> bool:
        try:
            self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            info = self.directory.lstat()
            if not stat.S_ISDIR(info.st_mode):
                raise OSError("audit directory is not a directory")
            if info.st_uid != os.geteuid():
                raise OSError("audit directory is not owned by the current user")
            if info.st_mode & 0o077:
                os.chmod(self.directory, 0o700)
            self._rotate()
            return True
        except OSError as exc:
            self.last_error = exc.strerror or str(exc)
            return False

    def _rotate(self) -> None:
        try:
            size = self.path.lstat().st_size
        except FileNotFoundError:
            return
        if size < MAX_AUDIT_BYTES:
            return
        for number in range(KEEP - 1, 0, -1):
            source = Path(f"{self.path}.{number}")
            target = Path(f"{self.path}.{number + 1}")
            if source.exists():
                os.replace(source, target)
        os.replace(self.path, Path(f"{self.path}.1"))

    def record(self, event: str, **fields: Any) -> bool:
        if not self._prepare():
            return False

        entry: dict[str, Any] = {
            "v": 1,
            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "event": redact(str(event)).text,
        }
        for key, value in fields.items():
            if key in _FORBIDDEN_FIELDS:
                continue
            if value is None:
                continue
            if isinstance(value, (bool, int, float)):
                entry[str(key)] = value
            elif isinstance(value, str):
                entry[str(key)] = redact(value).text
            elif isinstance(value, (list, tuple)):
                entry[str(key)] = [
                    redact(str(item)).text if isinstance(item, str) else item
                    for item in value
                ]
            else:
                entry[str(key)] = redact(str(value)).text

        line = json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n"
        flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW
        try:
            fd = os.open(self.path, flags, 0o600)
        except OSError as exc:
            self.last_error = exc.strerror or str(exc)
            return False
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid():
                self.last_error = "audit file is not a user-owned regular file"
                return False
            if info.st_mode & 0o077:
                os.fchmod(fd, 0o600)
            os.write(fd, line.encode("utf-8"))
            os.fsync(fd)
            return True
        except OSError as exc:
            self.last_error = exc.strerror or str(exc)
            return False
        finally:
            os.close(fd)

    def tail(self, limit: int = 50) -> list[dict[str, Any]]:
        if limit < 1:
            return []
        try:
            fd = os.open(self.path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
        except FileNotFoundError:
            return []
        try:
            with os.fdopen(fd, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.readlines()
        except OSError:
            return []
        out: list[dict[str, Any]] = []
        for line in lines[-limit:]:
            try:
                value = json.loads(line)
            except (json.JSONDecodeError, ValueError):
                continue
            if isinstance(value, dict):
                out.append(value)
        return out
