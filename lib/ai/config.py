"""Load assistant configuration without executing user Lua."""

from __future__ import annotations

import json
import os
import re
import shutil
import stat
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

MAX_CONFIG_BYTES = 1024 * 1024


class ConfigError(Exception):
    """A safe, user-facing configuration error.

    The message never contains a value from the file: the dumper reports only
    line numbers and type/shape errors.
    """


def _config_home(home: Path) -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or str(home / ".config"))


def default_config_path(home: Path) -> Path:
    return _config_home(home) / "padilha" / "ai.lua"


def default_legacy_config_path(home: Path) -> Path:
    return _config_home(home) / "lilith" / "ai.lua"


def default_roots_path(home: Path, config_path: Path | None = None) -> Path:
    explicit = os.environ.get("PADILHA_AI_ROOTS")
    if explicit:
        return Path(explicit).expanduser()
    if config_path is not None:
        return config_path.parent / "ai.roots.lua"
    return _config_home(home) / "padilha" / "ai.roots.lua"


def _secure_file(path: Path, *, what: str) -> None:
    """Require a user-owned regular 0600 file that is not a symlink."""

    try:
        info = path.lstat()
    except FileNotFoundError:
        raise
    except OSError as exc:
        raise ConfigError(f"cannot inspect {what}: {exc.strerror}") from None

    if stat.S_ISLNK(info.st_mode):
        raise ConfigError(f"{what} must not be a symlink")
    if not stat.S_ISREG(info.st_mode):
        raise ConfigError(f"{what} must be a regular file")
    if info.st_uid != os.geteuid():
        raise ConfigError(f"{what} must be owned by the current user")
    if info.st_mode & 0o077:
        raise ConfigError(f"{what} must have mode 0600")
    if info.st_size > MAX_CONFIG_BYTES:
        raise ConfigError(f"{what} is larger than 1 MiB")


def _lua_binary() -> str:
    for name in ("lua", "lua5.5", "lua5.4", "luajit"):
        found = shutil.which(name)
        if found:
            return found
    raise ConfigError("lua is not installed")


def _run_dumper(path: Path) -> Any:
    dumper = Path(__file__).resolve().parent / "config.lua"
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", str(Path.home())),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "LC_ALL": os.environ.get("LC_ALL", "C.UTF-8"),
    }
    # LUA_INIT/LUA_PATH/LUA_CPATH can execute or replace modules.  The dumper
    # sets its own package.path and must not inherit them.
    try:
        result = subprocess.run(
            [_lua_binary(), str(dumper), str(path)],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=10,
            env=env,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ConfigError(f"cannot load {path.name}: {exc}") from None

    if result.returncode != 0:
        message = (result.stderr or "").strip().splitlines()
        detail = message[-1] if message else "invalid configuration"
        detail = detail.replace(str(path), path.name)
        # Syntax errors can quote the offending token.  Keep the line number
        # and shape, never the value.
        detail = re.sub(r"near '[^']*'", "near <token>", detail)
        detail = re.sub(r"near \"[^\"]*\"", "near <token>", detail)
        raise ConfigError(detail[:500])
    try:
        data = json.loads(result.stdout)
    except (json.JSONDecodeError, ValueError):
        raise ConfigError(f"{path.name} did not produce a valid table") from None
    if not isinstance(data, (dict, list)):
        raise ConfigError(f"{path.name} must return a table")
    return data


def _load_file(path: Path, *, what: str) -> Any | None:
    try:
        _secure_file(path, what=what)
    except FileNotFoundError:
        return None
    return _run_dumper(path)


@dataclass
class Config:
    path: Path | None
    roots_path: Path
    data: dict[str, Any] = field(default_factory=dict)

    @property
    def permissions(self) -> dict[str, Any]:
        value = self.data.get("permissions")
        return value if isinstance(value, dict) else {}

    @property
    def write_enabled(self) -> bool:
        return self.permissions.get("write") is True

    @property
    def exec_requested(self) -> bool:
        return self.permissions.get("exec") is True

    @property
    def roots(self) -> list[Any]:
        value = self.permissions.get("roots")
        if value is None:
            value = self.data.get("roots")
        return value if isinstance(value, list) else []

    @property
    def deny(self) -> list[Any]:
        value = self.permissions.get("deny")
        return value if isinstance(value, list) else []

    @property
    def max_file_bytes(self) -> int:
        value = self.permissions.get("max_file_bytes")
        if isinstance(value, int) and not isinstance(value, bool) and value > 0:
            return min(value, 4 * 1024 * 1024)
        return 256 * 1024

    @property
    def max_request_bytes(self) -> int:
        value = self.permissions.get("max_request_bytes")
        if isinstance(value, int) and not isinstance(value, bool) and value > 0:
            return min(value, 64 * 1024 * 1024)
        return 4 * 1024 * 1024

    @property
    def max_tool_calls(self) -> int:
        value = self.permissions.get("max_tool_calls")
        if isinstance(value, int) and not isinstance(value, bool) and value > 0:
            return min(value, 100)
        return 8


def load_config(home: Path, config_path: str | Path | None = None) -> Config:
    home = Path(home).resolve()
    explicit = config_path or os.environ.get("PADILHA_AI_CONFIG")

    path: Path | None
    if explicit:
        path = Path(explicit).expanduser()
        if not path.is_absolute():
            path = (Path.cwd() / path).resolve()
        data = _load_file(path, what="ai.lua")
        if data is None:
            # An explicitly named missing config is an empty policy, not a
            # reason to fall back to a different file.
            data = {}
        if isinstance(data, list):
            if data:
                raise ConfigError(f"{path.name} must return a table")
            data = {}
        roots_path = default_roots_path(home, path)
        return Config(path=path, roots_path=roots_path, data=data)

    primary = default_config_path(home)
    legacy = default_legacy_config_path(home)
    data = _load_file(primary, what="ai.lua")
    if data is None:
        data = _load_file(legacy, what="lilith ai.lua")
        path = legacy if data is not None else primary
    else:
        path = primary

    if isinstance(data, list):
        if data:
            raise ConfigError(f"{path.name} must return a table")
        data = {}
    return Config(
        path=path,
        roots_path=default_roots_path(home),
        data=data or {},
    )


def load_roots_file(path: Path) -> list[Any]:
    data = _load_file(path, what="ai.roots.lua")
    if data is None:
        return []
    if isinstance(data, list):
        return data
    roots = data.get("roots")
    if roots is None and isinstance(data, list):
        return data
    return roots if isinstance(roots, list) else []
