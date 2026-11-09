"""Best-effort secret redaction for assistant content.

The deny list and the approved roots are the primary controls.  Redaction is a
second line of defence: it is deliberately conservative, may over-redact, and
never promises that unknown secret formats are caught.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class Redaction:
    text: str
    count: int
    kinds: tuple[str, ...]


# Patterns are applied in order.  A later pattern must not see a raw value left
# behind by an earlier one.
_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "private_key",
        re.compile(
            r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?"
            r"(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|\Z)",
            re.DOTALL,
        ),
    ),
    (
        "authorization",
        re.compile(
            r"(?im)^([ \t]*(?:proxy-)?authorization[ \t]*:[ \t]*)"
            r"[^\r\n]*"
        ),
    ),
    (
        "url_userinfo",
        re.compile(
            r"(?i)\b([a-z][a-z0-9+.-]*://)"
            r"[^/\s:@]+(?::[^/\s@]*)?@"
        ),
    ),
    (
        "provider_key",
        re.compile(
            r"\b(?:sk|rk)-[A-Za-z0-9_-]{16,}\b"
            r"|\bgh[pousr]_[A-Za-z0-9]{20,}\b"
            r"|\bgithub_pat_[A-Za-z0-9_]{20,}\b"
            r"|\bxox[baprs]-[A-Za-z0-9-]{10,}\b"
            r"|\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"
            r"|\bAIza[0-9A-Za-z_-]{35}\b"
            r"|\bSG\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
            r"|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"
        ),
    ),
    (
        "assignment",
        re.compile(
            r"(?im)(\b(?:password|passwd|pwd|token|secret|api[_-]?key|"
            r"access[_-]?key|client[_-]?secret|private[_-]?key|"
            r"auth[_-]?token)\b[ \t]*[:=][ \t]*)"
            r"(?!\[REDACTED:)(?:\"[^\"\r\n]*\"|'[^'\r\n]*'|[^\s,;]+)"
        ),
    ),
    (
        "env_assignment",
        re.compile(
            r"(?im)^([ \t]*(?:export[ \t]+)?"
            r"[A-Z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|PASSWD)[A-Z0-9_]*"
            r"[ \t]*=[ \t]*)"
            r"(?!\[REDACTED:)(?:\"[^\"\r\n]*\"|'[^'\r\n]*'|[^\s#]+)"
        ),
    ),
)


def redact(text: str) -> Redaction:
    """Return *text* with known secret shapes replaced by markers."""

    if not isinstance(text, str):
        text = str(text)

    total = 0
    kinds: list[str] = []
    for kind, pattern in _PATTERNS:
        if kind == "private_key":
            replacement = "[REDACTED:private_key]"
        elif kind == "authorization":
            replacement = r"\1[REDACTED:authorization]"
        elif kind == "url_userinfo":
            replacement = r"\1[REDACTED:url_userinfo]@"
        elif kind == "provider_key":
            replacement = "[REDACTED:provider_key]"
        elif kind == "assignment":
            replacement = r"\1[REDACTED:assignment]"
        else:
            replacement = r"\1[REDACTED:env_assignment]"

        text, found = pattern.subn(replacement, text)
        if found:
            total += found
            kinds.append(kind)

    return Redaction(text=text, count=total, kinds=tuple(kinds))


_ANSI = re.compile(
    r"\x1b(?:"
    r"\[[0-?]*[ -/]*[@-~]"  # CSI
    r"|\][^\x07]*(?:\x07|\x1b\\)"  # OSC
    r"|[@-_]"  # two-byte escapes
    r")"
)
# Keep tabs, newlines and carriage returns; drop every other C0/C1 control.
_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]")


def strip_control_sequences(text: str) -> str:
    """Remove terminal control sequences before text is displayed or sent."""

    return _CONTROL.sub("", _ANSI.sub("", text))


def looks_binary(prefix: bytes) -> bool:
    """The ADR's cheap binary check: NUL bytes or invalid UTF-8."""

    if b"\x00" in prefix:
        return True
    try:
        prefix.decode("utf-8")
    except UnicodeDecodeError:
        return True
    return False
