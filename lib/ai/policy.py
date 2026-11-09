"""Canonical path, approved-root and built-in deny policy.

This module makes decisions only.  The broker does the descriptor-relative open
and re-checks the policy immediately before it touches a file.
"""

from __future__ import annotations

import os
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DENY_SEGMENTS = frozenset(
    {
        ".ssh",
        ".gnupg",
        ".dsh",
        ".aws",
        ".kube",
        ".password-store",
        ".mozilla",
    }
)

DENY_BASENAMES = frozenset(
    {
        "known_hosts",
        "authorized_keys",
        ".netrc",
        ".git-credentials",
        ".npmrc",
        ".pypirc",
        ".bash_history",
        ".zsh_history",
        "fish_history",
        "logins.json",
        "key4.db",
        "cert9.db",
        "Cookies",
        "Login Data",
        "env.local.lua",
        "ai.lua",
        "ai.roots.lua",
        "ai.key",
        "id_rsa",
        "id_ed25519",
        "id_ecdsa",
        "credentials.toml",
        "hosts.yml",
        ".env",
    }
)

DENY_SUFFIXES = (".pem", ".key", ".p12", ".pfx", ".gpg", ".asc", ".kdbx")

# Paths relative to $HOME.  A deny directory covers everything below it.
DENY_HOME_PREFIXES = (
    ".config/padilha",
    ".config/lilith",
    ".config/mozilla",
    ".cache/mozilla",
    ".config/google-chrome",
    ".config/chromium",
    ".config/BraveSoftware",
    ".config/microsoft-edge",
    ".config/vivaldi",
    ".config/opera",
    ".var/app/org.mozilla.firefox",
    ".var/app/com.google.Chrome",
    ".var/app/com.brave.Browser",
    ".config/git/credentials",
    ".config/gh/hosts.yml",
    ".docker/config.json",
    ".config/gcloud",
    ".local/share/fish/fish_history",
    ".local/state/padilha/ai",
    ".local/state/lilith/ai",
)

SYSTEM_PREFIXES = ("/proc", "/sys", "/dev", "/run")


class PathError(ValueError):
    """A path was refused before any filesystem access."""

    def __init__(self, reason: str, message: str | None = None) -> None:
        super().__init__(message or reason)
        self.reason = reason


@dataclass(frozen=True)
class Root:
    path: str
    mode: str
    source: str = "config"

    @property
    def display(self) -> str:
        return self.path

    def as_dict(self) -> dict[str, str]:
        return {"path": self.path, "mode": self.mode, "source": self.source}


@dataclass(frozen=True)
class Decision:
    allowed: bool
    reason: str
    canonical: str | None
    display: str
    root: Root | None
    operation: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "allowed": self.allowed,
            "reason": self.reason,
            "path": self.display,
            "canonical": self.canonical,
            "root": self.root.display if self.root else None,
            "operation": self.operation,
        }


def is_under(path: str, root: str) -> bool:
    """Component-boundary prefix check: /home/u/Doc is not /home/u/Documents."""

    if path == root:
        return True
    if root == os.sep:
        return path.startswith(os.sep)
    try:
        return os.path.commonpath((path, root)) == root
    except ValueError:
        return False


def expand_path(raw: Any, home: str) -> str:
    if isinstance(raw, os.PathLike):
        raw = os.fspath(raw)
    if not isinstance(raw, str):
        raise PathError("invalid_path", "path must be a string")
    if raw == "" or "\x00" in raw:
        raise PathError("invalid_path", "path is empty or contains NUL")
    if raw.startswith("~") and not raw.startswith("~/"):
        raise PathError("tilde_user", "only a leading ~/ is expanded")
    if raw.startswith("~/"):
        expanded = os.path.join(home, raw[2:])
    elif os.path.isabs(raw):
        expanded = raw
    else:
        raise PathError("not_absolute", "path must be absolute or start with ~/")

    parts = [part for part in expanded.split(os.sep) if part not in ("", ".")]
    if any(part == ".." for part in parts):
        raise PathError("dotdot", "parent traversal is refused")
    if not expanded.startswith(os.sep):
        raise PathError("not_absolute", "path must be absolute")
    return os.path.normpath(expanded)


def canonicalize(raw: Any, home: str, *, must_exist: bool = True) -> str:
    expanded = expand_path(raw, home)
    if expanded == os.sep:
        raise PathError("invalid_root", "the filesystem root is not allowed")
    try:
        if must_exist:
            resolved = os.path.realpath(expanded, strict=True)
        else:
            resolved = os.path.realpath(expanded, strict=False)
    except (OSError, ValueError) as exc:
        reason = "not_found" if isinstance(exc, FileNotFoundError) else "invalid_path"
        raise PathError(reason, str(exc)) from None
    if not os.path.isabs(resolved):
        raise PathError("not_absolute", "canonical path is not absolute")
    return resolved


def display_path(canonical: str, home: str) -> str:
    if canonical == home:
        return "~"
    if is_under(canonical, home):
        relative = os.path.relpath(canonical, home)
        return "~/" + relative
    return canonical


def _deny_reason(path: str, home: str, extra_denies: Iterable[str]) -> str | None:
    if not is_under(path, home):
        return "outside_home"
    if path == home:
        return "home_root"
    for prefix in SYSTEM_PREFIXES:
        if is_under(path, prefix):
            return "system_path"

    relative = os.path.relpath(path, home)
    for prefix in DENY_HOME_PREFIXES:
        if relative == prefix or relative.startswith(prefix + os.sep):
            return "denied_prefix"

    for part in path.split(os.sep):
        if part in DENY_SEGMENTS:
            return "denied_component"
        if part in DENY_BASENAMES:
            return "denied_basename"
        if part.endswith(DENY_SUFFIXES):
            return "denied_suffix"
        if part.startswith(".env.") or part.endswith(".env"):
            return "denied_env"

    for deny in extra_denies:
        if is_under(path, deny):
            return "user_deny"
    return None


def is_denied(path: str, home: str, extra_denies: Iterable[str] = ()) -> tuple[bool, str]:
    reason = _deny_reason(path, home, extra_denies)
    return reason is not None, reason or "allow"


def expand_denies(entries: Iterable[Any], home: str) -> list[str]:
    out: list[str] = []
    for raw in entries:
        if not isinstance(raw, str):
            continue
        try:
            expanded = expand_path(raw, home)
        except PathError:
            continue
        # A deny need not exist.  Compare the lexical path and, when it exists,
        # the canonical target so a symlinked deny cannot be bypassed by path.
        values = {os.path.normpath(expanded)}
        try:
            values.add(canonicalize(raw, home, must_exist=False))
        except PathError:
            pass
        out.extend(sorted(values))
    return out


def _mode(value: Any) -> str:
    if isinstance(value, str) and value.lower() in ("rw", "read-write", "readwrite"):
        return "rw"
    return "ro"


def normalize_roots(
    entries: Iterable[Any],
    home: str,
    deny: Iterable[str],
    *,
    source: str = "config",
) -> tuple[list[Root], list[str]]:
    roots: dict[str, Root] = {}
    warnings: list[str] = []
    for item in entries:
        if isinstance(item, str):
            raw, mode = item, "ro"
        elif isinstance(item, dict):
            raw = item.get("path")
            mode = _mode(item.get("mode", "ro"))
        else:
            warnings.append("ignored a root that is not a path")
            continue
        try:
            expanded = expand_path(raw, home)
            canonical = canonicalize(raw, home, must_exist=True)
        except PathError as exc:
            warnings.append(f"ignored invalid root: {exc.reason}")
            continue
        lexical_denied, _lexical_reason = is_denied(expanded, home, deny)
        if lexical_denied:
            warnings.append("ignored denied root")
            continue
        if canonical == home:
            warnings.append("ignored the home directory as a root")
            continue
        if not is_under(canonical, home):
            warnings.append("ignored a root outside the home directory")
            continue
        if not os.path.isdir(canonical):
            warnings.append("ignored a root that is not a directory")
            continue
        denied, reason = is_denied(canonical, home, deny)
        if denied:
            warnings.append(f"ignored denied root ({reason})")
            continue

        previous = roots.get(canonical)
        if previous is not None:
            # The union is deliberately stricter on a mode conflict.
            combined = "rw" if previous.mode == "rw" and mode == "rw" else "ro"
            roots[canonical] = Root(canonical, combined, previous.source)
        else:
            roots[canonical] = Root(canonical, mode, source)

    ordered = sorted(roots.values(), key=lambda root: (len(root.path), root.path))
    return ordered, warnings


def choose_root(path: str, roots: Iterable[Root]) -> Root | None:
    best: Root | None = None
    for root in roots:
        if not is_under(path, root.path):
            continue
        if best is None or len(root.path) > len(best.path):
            best = root
        elif len(root.path) == len(best.path) and root.mode == "ro":
            # A duplicate path with conflicting modes stays read-only.
            best = root
    return best


def decide(
    raw: Any,
    roots: Iterable[Root],
    home: str,
    operation: str,
    global_write: bool = False,
    deny: Iterable[str] = (),
    *,
    must_exist: bool = True,
) -> Decision:
    try:
        expanded = expand_path(raw, home)
        canonical = canonicalize(raw, home, must_exist=must_exist)
    except PathError as exc:
        return Decision(False, exc.reason, None, str(raw), None, operation)

    display = display_path(canonical, home)
    # Check both the requested components and the resolved target.  A symlink
    # named .ssh must not become readable merely because it points at a public
    # file, and a harmless name must not hide a denied target.
    lexical_denied, lexical_reason = is_denied(
        os.path.normpath(expanded), home, deny
    )
    if lexical_denied:
        return Decision(False, lexical_reason, canonical, display, None, operation)
    denied, reason = is_denied(canonical, home, deny)
    if denied:
        return Decision(False, reason, canonical, display, None, operation)

    roots = list(roots)
    if not roots:
        return Decision(False, "no_roots", canonical, display, None, operation)

    root = choose_root(canonical, roots)
    if root is None:
        return Decision(False, "outside_root", canonical, display, None, operation)

    if operation in ("read", "list", "search"):
        return Decision(True, "in_root", canonical, display, root, operation)

    if operation == "write":
        if root.mode != "rw":
            return Decision(False, "read_only", canonical, display, root, operation)
        if not global_write:
            return Decision(False, "write_disabled", canonical, display, root, operation)
        return Decision(True, "write_allowed", canonical, display, root, operation)

    if operation in ("command", "exec"):
        return Decision(False, "command_disabled", canonical, display, root, operation)

    return Decision(False, "unknown_operation", canonical, display, root, operation)


def root_for_display(root: Root, home: str) -> Root:
    return Root(display_path(root.path, home), root.mode, root.source)


def home_from_environment() -> Path:
    override = os.environ.get("PADILHA_AI_HOME")
    if override:
        return Path(override).expanduser().resolve()
    return Path.home().resolve()


# The ADR sketch used this name; keep it for callers that read the sketch.
under = is_under
