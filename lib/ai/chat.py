"""Small provider-agnostic chat transport for the assistant.

The broker remains the security boundary.  This module only turns a validated
model configuration into one HTTPS request and one reply; it never reads files,
runs commands, or logs message content.
"""

from __future__ import annotations

import json
import os
import stat
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import Config
from .redact import redact


class ChatError(Exception):
    def __init__(self, message: str, *, code: str = "chat_error") -> None:
        super().__init__(message)
        self.code = code

    def as_dict(self) -> dict[str, str]:
        return {"code": self.code, "message": str(self)}


@dataclass(frozen=True)
class Model:
    id: str
    name: str
    provider: str
    model: str
    context: int


@dataclass(frozen=True)
class Provider:
    id: str
    kind: str
    base_url: str
    api_key: str | None


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def models(config: Config) -> list[Model]:
    entries = _as_dict(config.data.get("models"))
    out: list[Model] = []
    for ident, raw in entries.items():
        item = _as_dict(raw)
        provider = item.get("provider")
        model = item.get("model")
        if not isinstance(ident, str) or not isinstance(provider, str) or not isinstance(model, str):
            continue
        context = item.get("context")
        if not isinstance(context, int) or isinstance(context, bool) or context <= 0:
            context = 0
        out.append(
            Model(
                id=ident,
                name=str(item.get("name") or ident),
                provider=provider,
                model=model,
                context=context,
            )
        )
    return out


def _read_key_file(path: Path) -> str:
    path = path.expanduser()
    if not path.is_absolute():
        raise ChatError("credential file must be an absolute path")
    try:
        info = path.lstat()
    except OSError as exc:
        raise ChatError(f"cannot read credential file: {exc.strerror}") from None
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
        raise ChatError("credential file must be a regular file, not a symlink")
    if info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise ChatError("credential file must be owned by you with mode 0600")
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise ChatError(f"cannot read credential file: {exc.strerror}") from None


def _credential(provider: dict[str, Any]) -> str | None:
    inline = provider.get("api_key")
    if isinstance(inline, str):
        return inline.strip() or None
    credential = _as_dict(provider.get("credential"))
    store = credential.get("store")
    if store == "file":
        name = credential.get("path") or credential.get("file")
        if not isinstance(name, str):
            raise ChatError("credential.file needs a path")
        return _read_key_file(Path(name))
    if store in ("secret-service", "pass"):
        raise ChatError(
            f"credential store {store!r} is not available in this build; use a 0600 file or inline key",
            code="credential_unavailable",
        )
    return None


def provider_for(config: Config, model: Model) -> Provider:
    providers = _as_dict(config.data.get("providers"))
    raw = providers.get(model.provider)
    if not isinstance(raw, dict):
        raise ChatError(f"model {model.id!r} names unknown provider {model.provider!r}", code="bad_model")
    kind = raw.get("kind")
    base_url = raw.get("base_url")
    if kind != "openai-compatible":
        raise ChatError(
            f"provider {model.provider!r} uses unsupported kind {kind!r}",
            code="unsupported_provider",
        )
    if not isinstance(base_url, str):
        raise ChatError(f"provider {model.provider!r} has no base_url", code="bad_provider")
    parsed = urllib.parse.urlparse(base_url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ChatError("provider base_url must be an http(s) URL", code="bad_provider")
    if parsed.scheme == "http":
        host = parsed.hostname or ""
        loopback = host in ("127.0.0.1", "::1", "localhost")
        network = _as_dict(config.data.get("network"))
        if not loopback or network.get("allow_insecure_loopback") is not True:
            raise ChatError(
                "plain HTTP is only allowed for loopback with network.allow_insecure_loopback = true",
                code="insecure_provider",
            )
    return Provider(
        id=model.provider,
        kind=kind,
        base_url=base_url.rstrip("/"),
        api_key=_credential(raw),
    )


def _timeout(config: Config) -> float:
    network = _as_dict(config.data.get("network"))
    value = network.get("timeout_ms")
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return min(value, 600_000) / 1000
    return 120.0


def _validate_messages(messages: Any) -> list[dict[str, str]]:
    if not isinstance(messages, list) or not messages:
        raise ChatError("chat needs a non-empty messages list", code="bad_request")
    out: list[dict[str, str]] = []
    for raw in messages[-80:]:
        item = _as_dict(raw)
        role = item.get("role")
        content = item.get("content", item.get("text"))
        if role not in ("user", "assistant", "system") or not isinstance(content, str):
            continue
        if not content.strip():
            continue
        out.append({"role": role, "content": content})
    if not out:
        raise ChatError("chat has no non-empty messages", code="bad_request")
    total = sum(len(item["content"]) for item in out)
    if total > 4 * 1024 * 1024:
        raise ChatError("chat messages are too large", code="too_large")
    return out


def complete(config: Config, model_id: str | None, messages: Any) -> dict[str, Any]:
    """Return one assistant reply.  The caller supplies the audit sink."""

    available = models(config)
    if not available:
        raise ChatError(
            "chat providers are not configured; add models and providers to ai.lua",
            code="chat_not_configured",
        )
    chosen = model_id or config.data.get("default_model")
    model = next((entry for entry in available if entry.id == chosen), None)
    if model is None:
        model = available[0]

    cleaned = _validate_messages(messages)
    redacted = 0
    safe: list[dict[str, str]] = []
    for message in cleaned:
        result = redact(message["content"])
        if result.count:
            raise ChatError(
                "message contains a secret-shaped value; remove it before sending",
                code="secret_in_message",
            )
        safe.append({"role": message["role"], "content": result.text})

    provider = provider_for(config, model)
    if not provider.api_key and not provider.base_url.startswith("http://127.0.0.1") and not provider.base_url.startswith("http://[::1]"):
        raise ChatError(
            f"provider {provider.id!r} has no api_key or credential",
            code="missing_credential",
        )

    payload = json.dumps(
        {"model": model.model, "messages": safe, "stream": False},
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if provider.api_key:
        headers["Authorization"] = f"Bearer {provider.api_key}"
    request = urllib.request.Request(
        provider.base_url + "/chat/completions",
        data=payload,
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=_timeout(config)) as response:
            body = response.read(4 * 1024 * 1024)
    except urllib.error.HTTPError as exc:
        raise ChatError(f"provider returned HTTP {exc.code}", code="provider_http") from None
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ChatError(f"provider request failed: {exc.reason if hasattr(exc, 'reason') else exc}", code="provider_unreachable") from None
    try:
        data = json.loads(body.decode("utf-8"))
        choice = data["choices"][0]
        content = choice["message"]["content"]
    except (ValueError, KeyError, IndexError, TypeError):
        raise ChatError("provider returned an invalid response", code="provider_response") from None
    if isinstance(content, list):
        content = "".join(str(part.get("text", "")) for part in content if isinstance(part, dict))
    if not isinstance(content, str) or not content.strip():
        raise ChatError("provider returned an empty answer", code="provider_response")
    return {
        "text": content,
        "model": model.id,
        "provider": model.provider,
        "redactions": redacted,
        "usage": data.get("usage") if isinstance(data.get("usage"), dict) else {},
    }


def chat_models(config: Config) -> list[dict[str, Any]]:
    return [
        {
            "id": model.id,
            "name": model.name,
            "provider": model.provider,
            "context": model.context,
        }
        for model in models(config)
    ]
