"""The home-access broker.

Everything the assistant can touch goes through this object.  It reads only
regular UTF-8 files inside an approved root, redacts secrets before returning
content, and records metadata-only audit entries.  Writes are two-step: a
request returns an opaque one-time confirmation token; only a separate confirm
call can apply it.
"""

from __future__ import annotations

import base64
import difflib
import errno
import hashlib
import json
import os
import re
import secrets
import stat
import time
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .audit import Audit
from .config import Config, default_legacy_config_path, load_config, load_roots_file
from .policy import (
    Decision,
    PathError,
    Root,
    canonicalize,
    decide,
    display_path,
    expand_denies,
    expand_path,
    home_from_environment,
    is_denied,
    is_under,
    normalize_roots,
)
from .redact import looks_binary, redact, strip_control_sequences

MAX_LINE_LENGTH = 8192
MAX_SEARCH_HITS = 100
PENDING_TTL_SECONDS = 300
TOKEN_RE = re.compile(r"^[A-Za-z0-9_-]{20,128}$")


class BrokerError(Exception):
    """A safe error for the CLI/protocol.  It never carries file content."""

    code = "broker_error"

    def __init__(self, message: str, *, code: str | None = None, **details: Any) -> None:
        super().__init__(message)
        if code:
            self.code = code
        self.details = details

    def as_dict(self) -> dict[str, Any]:
        out = {"code": self.code, "message": str(self)}
        out.update(self.details)
        return out


class Denied(BrokerError):
    code = "denied"

    def __init__(self, decision: Decision) -> None:
        super().__init__("access denied", code="denied", reason=decision.reason)
        self.decision = decision

    def as_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "message": f"access denied: {self.decision.reason}",
            "decision": "deny",
            "reason": self.decision.reason,
            "path": self.decision.display,
            "operation": self.decision.operation,
        }


class AuditUnavailable(BrokerError):
    code = "audit_unavailable"

    def __init__(self, detail: str | None = None) -> None:
        super().__init__(
            "audit is unavailable; file access is disabled",
            code="audit_unavailable",
            detail=detail,
        )


class ConfirmationRequired(BrokerError):
    code = "confirmation_required"

    def __init__(self, pending: PendingWrite) -> None:
        super().__init__(
            "write requires a separate confirmation",
            code="confirmation_required",
            confirm_token=pending.token,
            path=pending.display,
            bytes=pending.bytes,
            old_sha256=pending.old_sha256,
            new_sha256=pending.new_sha256,
            diff=pending.diff,
        )
        self.pending = pending


class ConfirmationError(BrokerError):
    code = "confirmation_invalid"


class UnsafePath(BrokerError):
    code = "unsafe_path"


class TooLarge(BrokerError):
    code = "too_large"


class BinaryFile(BrokerError):
    code = "binary_file"


@dataclass
class FileResult:
    path: str
    canonical: str
    root: str
    text: str
    bytes: int
    sha256: str
    redactions: int
    read_id: str
    offset: int = 1
    limit: int | None = None

    def as_dict(self, *, include_text: bool = True) -> dict[str, Any]:
        out: dict[str, Any] = {
            "path": self.path,
            "canonical": self.canonical,
            "root": self.root,
            "bytes": self.bytes,
            "sha256": self.sha256,
            "redactions": self.redactions,
            "read_id": self.read_id,
            "offset": self.offset,
            "limit": self.limit,
        }
        if include_text:
            out["text"] = self.text
        return out


@dataclass
class ListEntry:
    path: str
    name: str
    kind: str
    size: int | None = None

    def as_dict(self) -> dict[str, Any]:
        return {"path": self.path, "name": self.name, "type": self.kind, "size": self.size}


@dataclass
class ListResult:
    path: str
    canonical: str
    root: str
    entries: list[ListEntry]
    truncated: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "canonical": self.canonical,
            "root": self.root,
            "entries": [entry.as_dict() for entry in self.entries],
            "truncated": self.truncated,
        }


@dataclass
class SearchResult:
    path: str
    query: str
    hits: list[dict[str, Any]]
    truncated: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "query": self.query,
            "hits": self.hits,
            "truncated": self.truncated,
        }


@dataclass
class PendingWrite:
    token: str
    path: str
    canonical: str
    root: str
    old_sha256: str | None
    new_sha256: str
    bytes: int
    diff: str
    created: float
    read_id: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "status": "confirmation_required",
            "confirm_token": self.token,
            "token": self.token,
            "path": self.path,
            "canonical": self.canonical,
            "root": self.root,
            "old_sha256": self.old_sha256,
            "new_sha256": self.new_sha256,
            "bytes": self.bytes,
            "diff": self.diff,
            "expires_in": PENDING_TTL_SECONDS,
        }


@dataclass
class WriteResult:
    path: str
    canonical: str
    root: str
    bytes: int
    old_sha256: str | None
    new_sha256: str
    confirm_id: str
    created: bool

    def as_dict(self) -> dict[str, Any]:
        return {
            "status": "written",
            "path": self.path,
            "canonical": self.canonical,
            "root": self.root,
            "bytes": self.bytes,
            "old_sha256": self.old_sha256,
            "new_sha256": self.new_sha256,
            "confirm_id": self.confirm_id,
            "created": self.created,
        }


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _lua_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def _read_all(fd: int, cap: int) -> bytes:
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = os.read(fd, min(65536, cap + 1 - total))
        if not chunk:
            break
        chunks.append(chunk)
        total += len(chunk)
        if total > cap:
            raise TooLarge("file is too large; request a smaller range")
    return b"".join(chunks)


class Broker:
    def __init__(
        self,
        *,
        home: str | Path | None = None,
        config_path: str | Path | None = None,
        state_dir: str | Path | None = None,
    ) -> None:
        self.home = str(
            Path(home).expanduser().resolve()
            if home is not None
            else home_from_environment()
        )
        self.config: Config = load_config(Path(self.home), config_path)
        self.config_path = self.config.path
        self._config_argument = config_path
        self.roots_path = Path(self.config.roots_path)

        if state_dir is not None:
            self.state_dir = Path(state_dir).expanduser()
        else:
            override = os.environ.get("PADILHA_AI_STATE") or os.environ.get(
                "PADILHA_AI_STATE_DIR"
            )
            if override:
                self.state_dir = Path(override).expanduser()
            else:
                base = Path(
                    os.environ.get("XDG_STATE_HOME")
                    or str(Path(self.home) / ".local" / "state")
                )
                self.state_dir = base / "padilha" / "ai"

        self.deny = self._effective_denies()
        config_roots, warnings = normalize_roots(
            self.config.roots, self.home, self.deny, source="config"
        )
        generated_entries = load_roots_file(self.roots_path)
        generated_roots, generated_warnings = normalize_roots(
            generated_entries, self.home, self.deny, source="grant"
        )
        self.warnings = warnings + generated_warnings
        self._config_warnings = warnings
        self.config_roots = config_roots
        self.generated_roots = generated_roots
        self.roots = self._merge_roots(config_roots, generated_roots)
        self.generation = 0

        self.audit = Audit(self.state_dir)
        self.pending_dir = self.state_dir / "pending"
        self.reads_path = self.state_dir / "reads.json"
        self._denied_inode_cache: set[tuple[int, int]] | None = None

    def _effective_denies(self) -> list[str]:
        """The configured denies plus the broker's own config/state paths."""

        values = list(expand_denies(self.config.deny, self.home))
        protected = [
            self.config_path,
            self.roots_path,
            default_legacy_config_path(Path(self.home)),
            self.state_dir,
        ]
        # A custom XDG_CONFIG_HOME may put the assistant config somewhere such
        # as ~/config/padilha.  Deny that directory, not just ai.lua and
        # ai.roots.lua, so sibling state cannot be read through an approved
        # parent.  A deliberately unusual single-file config location is left
        # as just the file deny.
        for path in (self.config_path, self.roots_path):
            if path is not None and Path(path).parent.name in ("padilha", "lilith"):
                protected.append(Path(path).parent)
        for item in protected:
            if item is None:
                continue
            text = os.path.normpath(str(item))
            values.append(text)
            try:
                values.append(os.path.realpath(text, strict=False))
            except (OSError, ValueError):
                pass
        return sorted(set(values))

    @staticmethod
    def _merge_roots(config_roots: Iterable[Root], grants: Iterable[Root]) -> list[Root]:
        merged: dict[str, Root] = {}
        for root in list(config_roots) + list(grants):
            previous = merged.get(root.path)
            if previous is None:
                merged[root.path] = root
                continue
            source = "config" if "config" in (previous.source, root.source) else "grant"
            mode = "rw" if previous.mode == "rw" and root.mode == "rw" else "ro"
            merged[root.path] = Root(root.path, mode, source)
        return sorted(merged.values(), key=lambda item: (len(item.path), item.path))

    # ------------------------------------------------------------------ state

    def _reload_roots(self) -> None:
        generated_entries = load_roots_file(self.roots_path)
        generated_roots, warnings = normalize_roots(
            generated_entries, self.home, self.deny, source="grant"
        )
        self.generated_roots = generated_roots
        self.roots = self._merge_roots(self.config_roots, generated_roots)
        self.warnings = list(self._config_warnings) + warnings
        self.generation += 1

    def reload(self) -> dict[str, Any]:
        """Reload ai.lua too, incrementing the policy generation."""

        self.config = load_config(Path(self.home), self._config_argument)
        self.config_path = self.config.path
        self.roots_path = Path(self.config.roots_path)
        self.deny = self._effective_denies()
        config_roots, warnings = normalize_roots(
            self.config.roots, self.home, self.deny, source="config"
        )
        self._config_warnings = warnings
        self.config_roots = config_roots
        self._reload_roots()
        self._audit_or_raise(
            "policy.reload",
            decision="allow",
            reason="explicit_reload",
            roots=len(self.roots),
        )
        return self.status()

    def _root_display(self, root: Root | None) -> str | None:
        if root is None:
            return None
        return display_path(root.path, self.home)

    def list_roots(self) -> dict[str, Any]:
        roots = [
            {
                "path": display_path(root.path, self.home),
                "canonical": root.path,
                "mode": root.mode,
                "source": root.source,
            }
            for root in self.roots
        ]
        return {
            "v": 1,
            "roots": roots,
            "write": self.config.write_enabled,
            "exec": False,
            "state": "no_roots" if not roots else "ready",
            "message": "no roots approved" if not roots else None,
            "warnings": self.warnings,
        }

    def status(self) -> dict[str, Any]:
        data = self.list_roots()
        data["config"] = str(self.config_path) if self.config_path else None
        data["roots_file"] = str(self.roots_path)
        data["audit"] = str(self.audit.path)
        return data

    def grant_root(self, raw: str, mode: str = "ro") -> dict[str, Any]:
        try:
            canonical = canonicalize(raw, self.home, must_exist=True)
        except PathError as exc:
            raise BrokerError(
                f"cannot approve root: {exc.reason}", code="invalid_root"
            ) from None
        if canonical == self.home:
            raise BrokerError(
                "the home directory itself cannot be a root", code="invalid_root"
            )
        if not is_under(canonical, self.home):
            raise BrokerError("roots must be under the home directory", code="invalid_root")
        if not os.path.isdir(canonical):
            raise BrokerError("the root must be a directory", code="invalid_root")
        try:
            expanded = expand_path(raw, self.home)
        except PathError as exc:
            raise BrokerError(
                f"cannot approve root: {exc.reason}", code="invalid_root"
            ) from None
        denied, reason = is_denied(expanded, self.home, self.deny)
        if not denied:
            denied, reason = is_denied(canonical, self.home, self.deny)
        if denied:
            raise BrokerError(
                f"that directory is denied ({reason})", code="denied_root"
            )
        normalized_mode = (
            "rw"
            if isinstance(mode, str) and mode.lower() in ("rw", "read-write", "readwrite")
            else "ro"
        )

        entries = {root.path: root for root in self.generated_roots}
        entries[canonical] = Root(canonical, normalized_mode, "grant")
        roots = sorted(entries.values(), key=lambda item: item.path)
        self._write_roots_file(roots)
        self._reload_roots()
        audited = self.audit.record(
            "root.grant",
            path=display_path(canonical, self.home),
            root=display_path(canonical, self.home),
            mode=normalized_mode,
            decision="allow",
            reason="explicit_approval",
        )
        result = {
            "status": "approved",
            "path": display_path(canonical, self.home),
            "canonical": canonical,
            "mode": normalized_mode,
            "audited": audited,
        }
        if not audited:
            result["warning"] = "the grant is active but the audit entry could not be written"
        return result

    def approve_root(self, raw: str, mode: str = "ro") -> dict[str, Any]:
        return self.grant_root(raw, mode)

    def revoke(self, raw: str) -> dict[str, Any]:
        return self.revoke_root(raw)

    def revoke_root(self, raw: str) -> dict[str, Any]:
        wanted: set[str] = set()
        try:
            wanted.add(expand_path(raw, self.home))
        except PathError:
            pass
        try:
            wanted.add(canonicalize(raw, self.home, must_exist=False))
        except PathError:
            pass

        remaining = [
            root
            for root in self.generated_roots
            if root.path not in wanted
            and display_path(root.path, self.home) != str(raw)
            and root.path != str(raw)
        ]
        removed = [root for root in self.generated_roots if root not in remaining]
        still = [
            root
            for root in self.roots
            if root.path in wanted or display_path(root.path, self.home) == str(raw)
        ]

        if not removed:
            if still:
                self.audit.record(
                    "root.revoke",
                    path=str(raw),
                    decision="deny",
                    reason="declared_in_config",
                )
                return {
                    "status": "declared_in_config",
                    "message": "root is declared in ai.lua; edit that file to remove it",
                    "path": str(raw),
                }
            self.audit.record(
                "root.revoke",
                path=str(raw),
                decision="deny",
                reason="root_not_found",
            )
            raise BrokerError("no such approved root", code="root_not_found")

        self._write_roots_file(sorted(remaining, key=lambda item: item.path))
        self._reload_roots()
        audited = self.audit.record(
            "root.revoke",
            path=str(raw),
            decision="allow",
            reason="explicit_revocation",
        )
        result = {"status": "revoked", "path": str(raw), "audited": audited}
        if not audited:
            result["warning"] = "the revocation is active but the audit entry could not be written"
        if still:
            result["still_configured"] = True
            result["message"] = "the root is still declared in ai.lua"
        return result

    def _write_roots_file(self, roots: Iterable[Root]) -> None:
        lines = [
            "-- Generated by padilha-ai. Revoke with: padilha-ai roots revoke PATH",
            "return {",
            "    roots = {",
        ]
        for root in roots:
            shown = display_path(root.path, self.home)
            lines.append(
                f"        {{ path = {_lua_string(shown)}, "
                f"mode = {_lua_string(root.mode)} }},"
            )
        lines.extend(["    },", "}", ""])
        self._write_private_atomic(self.roots_path, "\n".join(lines).encode("utf-8"))

    def _write_private_atomic(self, path: Path, data: bytes, *, mode: int = 0o600) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        try:
            parent_info = path.parent.lstat()
            if not stat.S_ISDIR(parent_info.st_mode):
                raise OSError("parent is not a directory")
            if parent_info.st_uid != os.geteuid():
                raise OSError("parent is not owned by the current user")
        except OSError as exc:
            raise BrokerError(
                f"cannot prepare {path.name}: {exc.strerror or exc}", code="write_failed"
            ) from None

        token = secrets.token_hex(8)
        temp = path.parent / f".{path.name}.{token}.tmp"
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW
        try:
            fd = os.open(temp, flags, mode)
            try:
                written = 0
                while written < len(data):
                    written += os.write(fd, data[written:])
                os.fsync(fd)
                os.fchmod(fd, mode)
            finally:
                os.close(fd)
            os.replace(temp, path)
            os.chmod(path, mode)
            try:
                dir_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
                try:
                    os.fsync(dir_fd)
                finally:
                    os.close(dir_fd)
            except OSError:
                pass
        except OSError as exc:
            try:
                os.unlink(temp)
            except OSError:
                pass
            raise BrokerError(
                f"cannot write {path.name}: {exc.strerror or exc}", code="write_failed"
            ) from None

    # ------------------------------------------------------------------ audit

    def _audit_or_raise(self, event: str, **fields: Any) -> None:
        if not self.audit.record(event, **fields):
            raise AuditUnavailable(self.audit.last_error)

    def _audit_denial(self, event: str, decision: Decision, **fields: Any) -> None:
        self.audit.record(
            event,
            path=decision.display,
            canonical=decision.canonical,
            root=self._root_display(decision.root),
            decision="deny",
            reason=decision.reason,
            operation=decision.operation,
            **fields,
        )

    # ------------------------------------------------------------- file opens

    def _open_beneath(self, root: str, target: str, flags: int) -> int:
        if not is_under(target, root):
            raise UnsafePath("path is outside the approved root")
        try:
            dir_fd = os.open(
                root,
                os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            )
        except OSError as exc:
            raise UnsafePath(f"cannot open root: {exc.strerror}") from None

        opened: list[int] = [dir_fd]
        try:
            relative = os.path.relpath(target, root)
            parts = [] if relative == "." else relative.split(os.sep)
            current = dir_fd
            for part in parts[:-1]:
                current = os.open(
                    part,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                    dir_fd=current,
                )
                opened.append(current)
            if parts:
                final_flags = flags | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
                final = os.open(parts[-1], final_flags, dir_fd=current)
                opened.append(final)
                for descriptor in opened[:-1]:
                    os.close(descriptor)
                return final
            # target is the root directory itself
            return dir_fd
        except OSError as exc:
            for descriptor in opened:
                try:
                    os.close(descriptor)
                except OSError:
                    pass
            if exc.errno in (errno.ELOOP, errno.ENOTDIR):
                raise UnsafePath("symlink or non-directory in path") from None
            raise UnsafePath(f"cannot open path: {exc.strerror}") from None

    def _check_regular(self, info: os.stat_result, *, what: str = "file") -> None:
        if not stat.S_ISREG(info.st_mode):
            raise UnsafePath(f"{what} is not a regular file")
        if info.st_uid != os.geteuid():
            raise UnsafePath(f"{what} is not owned by the current user")
        if info.st_nlink > 1:
            raise UnsafePath("hard-linked files require an explicit confirmation")

    def _denied_inodes(self) -> set[tuple[int, int]]:
        """Device/inode identity for obvious credential files.

        This catches the common hard-link alias to a denied file without
        walking the whole home directory.  It is a second line; the path deny
        list is the primary control.
        """

        if self._denied_inode_cache is not None:
            return self._denied_inode_cache
        candidates = [
            ".ssh",
            ".gnupg",
            ".dsh",
            ".aws",
            ".kube",
            ".password-store",
            ".config/padilha",
            ".config/lilith",
            ".config/google-chrome",
            ".config/chromium",
            ".config/BraveSoftware",
            ".config/microsoft-edge",
            ".config/vivaldi",
            ".config/opera",
            ".mozilla",
            ".var/app/org.mozilla.firefox",
            ".var/app/com.google.Chrome",
            ".var/app/com.brave.Browser",
            ".config/git/credentials",
            ".config/gh/hosts.yml",
            ".docker/config.json",
            ".config/gcloud",
            ".netrc",
            ".git-credentials",
            ".npmrc",
            ".pypirc",
        ]
        found: set[tuple[int, int]] = set()
        seen = 0
        for relative in candidates:
            base = os.path.join(self.home, relative)
            try:
                info = os.lstat(base)
            except OSError:
                continue
            if stat.S_ISLNK(info.st_mode):
                continue
            if stat.S_ISREG(info.st_mode):
                found.add((info.st_dev, info.st_ino))
                seen += 1
                continue
            if not stat.S_ISDIR(info.st_mode):
                continue
            for dirpath, dirnames, filenames in os.walk(base, followlinks=False):
                dirnames[:] = [name for name in dirnames if name != ".git"]
                for name in filenames:
                    if seen >= 5000:
                        break
                    try:
                        child = os.lstat(os.path.join(dirpath, name))
                    except OSError:
                        continue
                    if stat.S_ISREG(child.st_mode):
                        found.add((child.st_dev, child.st_ino))
                        seen += 1
                if seen >= 5000:
                    break
        self._denied_inode_cache = found
        return found

    def _check_generation(self, generation: int) -> None:
        if generation != self.generation:
            raise Denied(
                Decision(
                    False,
                    "revoked",
                    None,
                    "",
                    None,
                    "read",
                )
            )

    # ------------------------------------------------------------------- read

    def read_file(
        self,
        raw: str,
        *,
        offset: int | None = None,
        limit: int | None = None,
        allow_hard_link: bool = False,
    ) -> FileResult:
        if offset is not None and (not isinstance(offset, int) or offset < 1):
            raise BrokerError("offset must be a positive line number", code="bad_request")
        if limit is not None and (not isinstance(limit, int) or limit < 1):
            raise BrokerError("limit must be a positive line count", code="bad_request")

        decision = decide(
            raw,
            self.roots,
            self.home,
            "read",
            self.config.write_enabled,
            self.deny,
            must_exist=True,
        )
        if not decision.allowed:
            self._audit_denial("file.read", decision, bytes=0, sha256=None, redactions=0)
            raise Denied(decision)

        generation = self.generation
        fd = self._open_beneath(decision.root.path, decision.canonical, os.O_RDONLY)
        try:
            info = os.fstat(fd)
            if allow_hard_link and stat.S_ISREG(info.st_mode):
                if info.st_uid != os.geteuid():
                    raise UnsafePath("file is not owned by the current user")
                if (info.st_dev, info.st_ino) in self._denied_inodes():
                    raise UnsafePath("hard link to a denied file")
            else:
                self._check_regular(info)
            self._check_generation(generation)

            prefix = os.pread(fd, min(MAX_LINE_LENGTH, max(info.st_size, 1)), 0)
            if looks_binary(prefix):
                raise BinaryFile("not a text file")
            try:
                prefix.decode("utf-8")
            except UnicodeDecodeError:
                raise BinaryFile("not a text file") from None

            cap = self.config.max_file_bytes
            if offset is None and limit is None:
                if info.st_size > cap:
                    raise TooLarge("file is too large; request a smaller range")
                os.lseek(fd, 0, os.SEEK_SET)
                data = _read_all(fd, cap)
            else:
                data = self._read_line_range(fd, offset or 1, limit, cap)

            after = os.fstat(fd)
            if (
                after.st_dev != info.st_dev
                or after.st_ino != info.st_ino
                or after.st_size != info.st_size
                or after.st_mtime_ns != info.st_mtime_ns
            ):
                raise BrokerError(
                    "the file changed during the read; retry", code="file_changed"
                )

            try:
                text = data.decode("utf-8")
            except UnicodeDecodeError:
                raise BinaryFile("not a text file") from None
            if "\x00" in text:
                raise BinaryFile("not a text file")
            text = strip_control_sequences(text)
            cleaned = redact(text)
            digest = _sha256(data)
            read_id = "read-" + secrets.token_urlsafe(18)
            self._audit_or_raise(
                "file.read",
                path=decision.display,
                canonical=decision.canonical,
                root=self._root_display(decision.root),
                decision="allow",
                reason="in_root",
                bytes=len(data),
                sha256=digest,
                redactions=cleaned.count,
            )
            self._save_read_token(read_id, decision.canonical, digest)
            return FileResult(
                path=decision.display,
                canonical=decision.canonical,
                root=decision.root.path,
                text=cleaned.text,
                bytes=len(data),
                sha256=digest,
                redactions=cleaned.count,
                read_id=read_id,
                offset=offset or 1,
                limit=limit,
            )
        finally:
            os.close(fd)

    def _read_line_range(self, fd: int, offset: int, limit: int | None, cap: int) -> bytes:
        collected: list[bytes] = []
        total = 0
        stop = None if limit is None else offset + limit - 1
        fd_copy = os.dup(fd)
        with os.fdopen(fd_copy, "rb", closefd=True) as handle:
            for number, line in enumerate(handle, start=1):
                if number < offset:
                    continue
                if stop is not None and number > stop:
                    break
                total += len(line)
                if total > cap:
                    raise TooLarge("range is too large; request a smaller range")
                collected.append(line)
        return b"".join(collected)

    def _save_read_token(self, read_id: str, canonical: str, digest: str) -> None:
        try:
            state = self._load_reads()
            state[read_id] = {
                "path": canonical,
                "sha256": digest,
                "created": time.time(),
            }
            # Keep this file small; stale read tokens are not useful.
            if len(state) > 200:
                ordered = sorted(state.items(), key=lambda item: item[1]["created"])
                state = dict(ordered[-200:])
            self._write_private_atomic(
                self.reads_path,
                json.dumps(state, sort_keys=True).encode("utf-8"),
            )
        except (BrokerError, OSError, ValueError, TypeError):
            # Audit is the security control; a read token is only a write
            # convenience.  A failure here must not leak file content.
            return

    def _load_reads(self) -> dict[str, Any]:
        try:
            info = self.reads_path.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_size > 1024 * 1024:
                return {}
            raw = self.reads_path.read_text(encoding="utf-8")
            data = json.loads(raw)
            return data if isinstance(data, dict) else {}
        except (OSError, ValueError, TypeError):
            return {}

    def _verify_read_token(self, read_id: str | None, canonical: str, digest: str | None) -> None:
        if not read_id:
            return
        state = self._load_reads()
        entry = state.get(read_id)
        if not isinstance(entry, dict):
            raise BrokerError("read_id is not known; read the file again", code="stale_read")
        if entry.get("path") != canonical:
            raise BrokerError("read_id belongs to a different file", code="stale_read")
        if digest is not None and entry.get("sha256") != digest:
            raise BrokerError(
                "the file changed since it was read; read it again", code="file_changed"
            )

    # ------------------------------------------------------------------- list

    def list_dir(self, raw: str) -> ListResult:
        decision = decide(
            raw,
            self.roots,
            self.home,
            "list",
            self.config.write_enabled,
            self.deny,
            must_exist=True,
        )
        if not decision.allowed:
            self._audit_denial("dir.list", decision, entries=0)
            raise Denied(decision)
        if not os.path.isdir(decision.canonical):
            raise UnsafePath("not a directory")

        generation = self.generation
        fd = self._open_beneath(
            decision.root.path, decision.canonical, os.O_RDONLY | os.O_DIRECTORY
        )
        try:
            info = os.fstat(fd)
            if not stat.S_ISDIR(info.st_mode):
                raise UnsafePath("not a directory")
            if info.st_uid != os.geteuid():
                raise UnsafePath("directory is not owned by the current user")
            self._check_generation(generation)
            names = os.listdir(fd)
            entries: list[ListEntry] = []
            truncated = False
            for name in sorted(names):
                if len(entries) >= 2000:
                    truncated = True
                    break
                entry_path = os.path.join(decision.canonical, name)
                denied, _reason = is_denied(entry_path, self.home, self.deny)
                if denied:
                    continue
                try:
                    entry_info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                except OSError:
                    continue
                kind = _kind(entry_info.st_mode)
                if kind == "symlink":
                    try:
                        target = os.path.realpath(entry_path, strict=True)
                    except OSError:
                        continue
                    if not is_under(target, decision.root.path):
                        continue
                    denied, _reason = is_denied(target, self.home, self.deny)
                    if denied:
                        continue
                entries.append(
                    ListEntry(
                        path=display_path(entry_path, self.home),
                        name=name,
                        kind=kind,
                        size=entry_info.st_size if kind == "file" else None,
                    )
                )
            self._audit_or_raise(
                "dir.list",
                path=decision.display,
                canonical=decision.canonical,
                root=self._root_display(decision.root),
                decision="allow",
                reason="in_root",
                entries=len(entries),
            )
            return ListResult(
                path=decision.display,
                canonical=decision.canonical,
                root=decision.root.path,
                entries=entries,
                truncated=truncated,
            )
        finally:
            os.close(fd)

    # ----------------------------------------------------------------- search

    def search_text(
        self,
        query: str,
        raw: str,
        *,
        max_hits: int = MAX_SEARCH_HITS,
    ) -> SearchResult:
        if not isinstance(query, str) or not query:
            raise BrokerError("search needs a non-empty query", code="bad_request")
        if len(query) > 1024:
            raise BrokerError("search query is too long", code="bad_request")
        max_hits = max(1, min(int(max_hits), MAX_SEARCH_HITS))
        decision = decide(
            raw,
            self.roots,
            self.home,
            "search",
            self.config.write_enabled,
            self.deny,
            must_exist=True,
        )
        if not decision.allowed:
            self._audit_denial("file.search", decision, hits=0)
            raise Denied(decision)

        needle = query.lower()
        hits: list[dict[str, Any]] = []
        truncated = False
        candidates: list[str] = []
        if os.path.isdir(decision.canonical):
            for dirpath, dirnames, filenames in os.walk(decision.canonical, followlinks=False):
                dirnames[:] = sorted(
                    name
                    for name in dirnames
                    if not is_denied(os.path.join(dirpath, name), self.home, self.deny)[0]
                )
                for name in sorted(filenames):
                    candidates.append(os.path.join(dirpath, name))
                    if len(candidates) > 5000:
                        truncated = True
                        break
                if truncated:
                    break
        else:
            candidates = [decision.canonical]

        for candidate in candidates:
            if len(hits) >= max_hits:
                truncated = True
                break
            try:
                result = self.read_file(candidate)
            except (Denied, BinaryFile, TooLarge, UnsafePath):
                continue
            for number, line in enumerate(result.text.splitlines(), start=1):
                if needle in line.lower():
                    snippet = line.strip()
                    if len(snippet) > MAX_LINE_LENGTH:
                        snippet = snippet[:MAX_LINE_LENGTH]
                    hits.append(
                        {
                            "path": result.path,
                            "line": number,
                            "text": snippet,
                            "redactions": result.redactions,
                        }
                    )
                    if len(hits) >= max_hits:
                        truncated = True
                        break
            if truncated:
                break

        self._audit_or_raise(
            "file.search",
            path=decision.display,
            canonical=decision.canonical,
            root=self._root_display(decision.root),
            decision="allow",
            reason="in_root",
            hits=len(hits),
        )
        return SearchResult(
            path=decision.display,
            query=query,
            hits=hits,
            truncated=truncated,
        )

    # ------------------------------------------------------------------ write

    def write_file(
        self,
        raw: str,
        content: str | bytes,
        *,
        read_id: str | None = None,
    ) -> PendingWrite:
        """Request a write; this deliberately does not write anything yet."""

        return self.request_write(raw, content, read_id=read_id)

    def request_write(
        self,
        raw: str,
        content: str | bytes,
        *,
        read_id: str | None = None,
    ) -> PendingWrite:
        data, target, decision, old_data = self._prepare_write(raw, content, read_id)
        old_sha = _sha256(old_data) if old_data is not None else None
        new_sha = _sha256(data)
        display = decision.display

        old_text = ""
        if old_data is not None:
            try:
                old_text = old_data.decode("utf-8")
            except UnicodeDecodeError:
                raise BrokerError(
                    "the existing file is not a text file", code="binary_file"
                ) from None
        try:
            new_text = data.decode("utf-8")
        except UnicodeDecodeError:
            raise BrokerError("new content is not valid UTF-8", code="bad_request") from None

        diff_lines = difflib.unified_diff(
            old_text.splitlines(keepends=True),
            new_text.splitlines(keepends=True),
            fromfile=display,
            tofile=display,
            n=3,
        )
        diff = "".join(diff_lines)
        if len(diff) > 65536:
            diff = diff[:65536] + "\n[diff truncated]"
        diff = redact(diff).text

        token = "confirm-" + secrets.token_urlsafe(24)
        pending = PendingWrite(
            token=token,
            path=display,
            canonical=target,
            root=decision.root.path,
            old_sha256=old_sha,
            new_sha256=new_sha,
            bytes=len(data),
            diff=diff,
            created=time.time(),
            read_id=read_id,
        )
        record = {
            "v": 1,
            "token": token,
            "created": pending.created,
            "path": display,
            "canonical": target,
            "root": decision.root.path,
            "old_sha256": old_sha,
            "new_sha256": new_sha,
            "bytes": len(data),
            "read_id": read_id,
            "content": base64.b64encode(data).decode("ascii"),
        }
        pending_path = self.pending_dir / f"{token}.json"
        self._write_private_atomic(
            pending_path,
            json.dumps(record, sort_keys=True).encode("utf-8"),
        )
        try:
            self._audit_or_raise(
                "file.write",
                path=display,
                canonical=target,
                root=self._root_display(decision.root),
                decision="confirm",
                reason="confirmation_required",
                bytes=len(data),
                old_sha256=old_sha,
                new_sha256=new_sha,
                confirm_id=token,
            )
        except Exception:
            self._remove_quietly(pending_path)
            raise
        return pending

    def _prepare_write(
        self,
        raw: str,
        content: str | bytes,
        read_id: str | None,
    ) -> tuple[bytes, str, Decision, bytes | None]:
        if isinstance(content, str):
            data = content.encode("utf-8")
        elif isinstance(content, bytes):
            data = content
        else:
            raise BrokerError("content must be text or bytes", code="bad_request")
        if b"\x00" in data:
            raise BrokerError("new content contains NUL", code="bad_request")
        try:
            data.decode("utf-8")
        except UnicodeDecodeError:
            raise BrokerError("new content is not valid UTF-8", code="bad_request") from None
        if len(data) > self.config.max_file_bytes:
            raise TooLarge("new content is larger than the file limit")

        try:
            expanded = expand_path(raw, self.home)
        except PathError as exc:
            raise BrokerError(exc.reason, code="invalid_path") from None

        if os.path.lexists(expanded):
            try:
                existing = os.lstat(expanded)
            except OSError as exc:
                raise BrokerError(exc.strerror or str(exc), code="unsafe_path") from None
            if stat.S_ISLNK(existing.st_mode):
                raise BrokerError("refusing to write through a symlink", code="symlink")
            if not stat.S_ISREG(existing.st_mode):
                raise BrokerError("target is not a regular file", code="unsafe_path")
            expanded_path = Path(expanded)
            parent = expanded_path.parent
            try:
                parent_real = os.path.realpath(parent, strict=True)
            except OSError as exc:
                raise BrokerError(exc.strerror or str(exc), code="invalid_path") from None
            target = os.path.join(parent_real, expanded_path.name)
        else:
            expanded_path = Path(expanded)
            parent = expanded_path.parent
            try:
                parent_real = os.path.realpath(parent, strict=True)
            except OSError:
                raise BrokerError(
                    "parent directory does not exist", code="invalid_path"
                ) from None
            if not os.path.isdir(parent_real):
                raise BrokerError("parent is not a directory", code="invalid_path")
            target = os.path.join(parent_real, expanded_path.name)

        decision = decide(
            target,
            self.roots,
            self.home,
            "write",
            self.config.write_enabled,
            self.deny,
            must_exist=False,
        )
        if not decision.allowed:
            self._audit_denial("file.write", decision, bytes=len(data))
            raise Denied(decision)
        if not is_under(target, decision.root.path):
            raise Denied(Decision(False, "outside_root", target, decision.display, decision.root, "write"))

        old_data: bytes | None = None
        if os.path.lexists(target):
            generation = self.generation
            fd = self._open_beneath(decision.root.path, target, os.O_RDONLY)
            try:
                info = os.fstat(fd)
                self._check_regular(info)
                self._check_generation(generation)
                if info.st_size > self.config.max_file_bytes:
                    raise TooLarge("the existing file is too large")
                os.lseek(fd, 0, os.SEEK_SET)
                old_data = _read_all(fd, self.config.max_file_bytes)
            finally:
                os.close(fd)
            if looks_binary(old_data[:MAX_LINE_LENGTH]):
                raise BinaryFile("the existing file is not a text file")
            self._verify_read_token(read_id, target, _sha256(old_data))
        return data, target, decision, old_data

    def confirm_write(self, token: str, *, allow: bool = True) -> WriteResult:
        if not isinstance(token, str) or not TOKEN_RE.match(token):
            raise ConfirmationError("invalid confirmation token")
        pending_path = self.pending_dir / f"{token}.json"
        record = self._load_pending(pending_path)
        if record is None:
            raise ConfirmationError("confirmation token is unknown or already used")
        if time.time() - float(record.get("created", 0)) > PENDING_TTL_SECONDS:
            self._remove_quietly(pending_path)
            self._audit_or_raise(
                "file.write",
                path=str(record.get("path", "")),
                canonical=str(record.get("canonical", "")),
                decision="deny",
                reason="confirmation_expired",
                bytes=0,
                confirm_id=token,
            )
            raise ConfirmationError("confirmation token has expired")

        if not allow:
            self._remove_quietly(pending_path)
            self._audit_or_raise(
                "file.write",
                path=str(record.get("path", "")),
                canonical=str(record.get("canonical", "")),
                decision="deny",
                reason="user_denied",
                bytes=0,
                confirm_id=token,
            )
            raise ConfirmationError("write declined")

        content = self._pending_content(record)
        canonical = str(record.get("canonical", ""))
        decision = decide(
            canonical,
            self.roots,
            self.home,
            "write",
            self.config.write_enabled,
            self.deny,
            must_exist=False,
        )
        if not decision.allowed:
            self._remove_quietly(pending_path)
            self._audit_denial("file.write", decision, bytes=len(content), confirm_id=token)
            raise Denied(decision)

        expected_old = record.get("old_sha256")
        old_data, old_info = self._current_target(canonical, decision.root.path)
        current_old = _sha256(old_data) if old_data is not None else None
        if current_old != expected_old:
            self._remove_quietly(pending_path)
            self._audit_or_raise(
                "file.write",
                path=decision.display,
                canonical=canonical,
                root=self._root_display(decision.root),
                decision="deny",
                reason="file_changed",
                bytes=len(content),
                old_sha256=current_old,
                new_sha256=_sha256(content),
                confirm_id=token,
            )
            raise ConfirmationError("the file changed after the confirmation was requested")

        new_sha = _sha256(content)
        # Consume the token before touching the target: a failure must not
        # leave a replayable confirmation behind.
        self._remove_quietly(pending_path)
        # Fail closed if the audit trail cannot accept the confirmation.  The
        # final allow entry is written after the atomic rename, but this
        # preflight means an unavailable audit never lets a write start.
        self._audit_or_raise(
            "file.write",
            path=decision.display,
            canonical=canonical,
            root=self._root_display(decision.root),
            decision="confirm",
            reason="applying_confirmed",
            bytes=len(content),
            old_sha256=current_old,
            new_sha256=new_sha,
            confirm_id=token,
        )
        try:
            self._apply_write(canonical, content, decision, old_info, token)
        except Exception as exc:
            self.audit.record(
                "file.write",
                path=decision.display,
                canonical=canonical,
                root=self._root_display(decision.root),
                decision="deny",
                reason="write_failed",
                bytes=len(content),
                old_sha256=current_old,
                new_sha256=new_sha,
                confirm_id=token,
            )
            if isinstance(exc, BrokerError):
                raise
            raise BrokerError("write failed; the original is unchanged", code="write_failed") from None

        self._audit_or_raise(
            "file.write",
            path=decision.display,
            canonical=canonical,
            root=self._root_display(decision.root),
            decision="allow",
            reason="confirmed",
            bytes=len(content),
            old_sha256=current_old,
            new_sha256=new_sha,
            confirm_id=token,
        )
        return WriteResult(
            path=decision.display,
            canonical=canonical,
            root=decision.root.path,
            bytes=len(content),
            old_sha256=current_old,
            new_sha256=new_sha,
            confirm_id=token,
            created=old_data is None,
        )

    def deny_write(self, token: str) -> None:
        self.confirm_write(token, allow=False)

    def _load_pending(self, path: Path) -> dict[str, Any] | None:
        try:
            info = path.lstat()
        except OSError:
            return None
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid():
            return None
        max_pending = (self.config.max_file_bytes * 4 // 3) + 65536
        if info.st_mode & 0o077 or info.st_size > max_pending:
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError, TypeError):
            return None
        return data if isinstance(data, dict) else None

    @staticmethod
    def _remove_quietly(path: Path) -> None:
        try:
            path.unlink()
        except OSError:
            pass

    def _pending_content(self, record: dict[str, Any]) -> bytes:
        try:
            content = base64.b64decode(str(record.get("content", "")), validate=True)
        except (ValueError, TypeError):
            raise ConfirmationError("confirmation payload is invalid") from None
        if _sha256(content) != record.get("new_sha256"):
            raise ConfirmationError("confirmation payload was modified")
        if len(content) > self.config.max_file_bytes:
            raise TooLarge("new content is larger than the file limit")
        return content

    def _current_target(
        self, canonical: str, root: str
    ) -> tuple[bytes | None, os.stat_result | None]:
        try:
            info = os.lstat(canonical)
        except FileNotFoundError:
            return None, None
        except OSError as exc:
            raise BrokerError(exc.strerror or str(exc), code="unsafe_path") from None
        if stat.S_ISLNK(info.st_mode):
            raise BrokerError("refusing to write through a symlink", code="symlink")
        if not stat.S_ISREG(info.st_mode):
            raise BrokerError("target is not a regular file", code="unsafe_path")
        fd = self._open_beneath(root, canonical, os.O_RDONLY)
        try:
            opened = os.fstat(fd)
            self._check_regular(opened)
            if opened.st_size > self.config.max_file_bytes:
                raise TooLarge("the existing file is too large")
            os.lseek(fd, 0, os.SEEK_SET)
            data = _read_all(fd, self.config.max_file_bytes)
            return data, opened
        finally:
            os.close(fd)

    def _apply_write(
        self,
        canonical: str,
        content: bytes,
        decision: Decision,
        old_info: os.stat_result | None,
        token: str,
    ) -> None:
        root = decision.root.path
        parent = os.path.dirname(canonical)
        name = os.path.basename(canonical)
        if name in ("", ".", ".."):
            raise BrokerError("invalid target name", code="invalid_path")
        parent_fd = self._open_beneath(root, parent, os.O_RDONLY | os.O_DIRECTORY)
        temp_name = f".padilha-ai-{token[-16:]}.tmp"
        temp_created = False
        try:
            mode = 0o600
            try:
                existing = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except FileNotFoundError:
                existing = None
            if existing is not None:
                if stat.S_ISLNK(existing.st_mode) or not stat.S_ISREG(existing.st_mode):
                    raise BrokerError("refusing to replace a non-regular file", code="unsafe_path")
                if old_info is not None and (
                    existing.st_dev != old_info.st_dev or existing.st_ino != old_info.st_ino
                ):
                    raise ConfirmationError("the target changed before the write")
                mode = stat.S_IMODE(existing.st_mode)

            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW
            temp_fd = os.open(temp_name, flags, 0o600, dir_fd=parent_fd)
            temp_created = True
            try:
                written = 0
                while written < len(content):
                    written += os.write(temp_fd, content[written:])
                os.fsync(temp_fd)
                os.fchmod(temp_fd, mode)
            finally:
                os.close(temp_fd)

            # Re-check the target immediately before the atomic rename.
            try:
                after = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            except FileNotFoundError:
                after = None
            if existing is None:
                if after is not None:
                    raise ConfirmationError("the target appeared before the write")
            else:
                if after is None or after.st_dev != existing.st_dev or after.st_ino != existing.st_ino:
                    raise ConfirmationError("the target changed before the write")

            os.rename(temp_name, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
            temp_created = False
            try:
                os.fsync(parent_fd)
            except OSError:
                pass
        finally:
            if temp_created:
                try:
                    os.unlink(temp_name, dir_fd=parent_fd)
                except OSError:
                    pass
            os.close(parent_fd)

    # ---------------------------------------------------------------- command

    def propose_command(self, command: str) -> dict[str, Any]:
        if not isinstance(command, str) or not command.strip():
            raise BrokerError("command is empty", code="bad_request")
        text = redact(command).text
        self._audit_or_raise(
            "command.propose",
            decision="allow",
            reason="text_only",
            argv_hash=_sha256(command.encode("utf-8")),
        )
        return {
            "status": "proposed",
            "command": text,
            "executed": False,
            "message": "command execution is not implemented; copy it and run it yourself",
        }

    def execute_command(self, command: str) -> dict[str, Any]:
        self._audit_or_raise(
            "command.exec",
            decision="deny",
            reason="command_disabled",
            argv_hash=_sha256(str(command).encode("utf-8")),
        )
        raise BrokerError(
            "command execution is not available; the broker is not a shell",
            code="command_disabled",
        )

    # ----------------------------------------------------------------- helpers


def _kind(mode: int) -> str:
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISDIR(mode):
        return "directory"
    if stat.S_ISLNK(mode):
        return "symlink"
    if stat.S_ISFIFO(mode):
        return "fifo"
    if stat.S_ISSOCK(mode):
        return "socket"
    if stat.S_ISCHR(mode) or stat.S_ISBLK(mode):
        return "device"
    return "other"
