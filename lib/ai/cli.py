"""Command-line and JSON-lines front end for the home-access broker."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

from .broker import (
    AuditUnavailable,
    BinaryFile,
    Broker,
    BrokerError,
    ConfirmationError,
    ConfirmationRequired,
    Denied,
    TooLarge,
    UnsafePath,
)
from .chat import ChatError, chat_models, complete
from .config import ConfigError
from .policy import home_from_environment
from .redact import redact

VERSION = "0.1.0"
MAX_PROTOCOL_LINE = 1024 * 1024


def _emit_json(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, sort_keys=True))


def _error_dict(exc: BaseException) -> dict[str, Any]:
    if isinstance(exc, BrokerError):
        return exc.as_dict()
    if isinstance(exc, ChatError):
        return exc.as_dict()
    if isinstance(exc, ConfigError):
        return {"code": "config_error", "message": str(exc)}
    return {"code": "error", "message": str(exc)}


def _extract_globals(argv: list[str]) -> tuple[list[str], dict[str, Any]]:
    globals_: dict[str, Any] = {
        "config": None,
        "state_dir": None,
        "home": None,
        "roots_file": None,
        "json": False,
        "stdio": False,
    }
    rest: list[str] = []
    index = 0
    while index < len(argv):
        arg = argv[index]
        matched = False
        for name, key in (
            ("--config", "config"),
            ("--state-dir", "state_dir"),
            ("--home", "home"),
            ("--roots-file", "roots_file"),
        ):
            if arg == name:
                if index + 1 >= len(argv):
                    raise SystemExit(f"padilha-ai: {name} needs a value")
                globals_[key] = argv[index + 1]
                index += 2
                matched = True
                break
            if arg.startswith(name + "="):
                globals_[key] = arg.split("=", 1)[1]
                index += 1
                matched = True
                break
        if matched:
            continue
        if arg == "--json":
            globals_["json"] = True
            index += 1
            continue
        if arg == "--stdio":
            globals_["stdio"] = True
            index += 1
            continue
        rest.append(arg)
        index += 1
    return rest, globals_


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="padilha-ai",
        description=(
            "Permissioned home-folder broker: approved roots, read-only by "
            "default, redacted output, metadata-only audit."
        ),
    )
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("status", help="show roots, write switch and policy state")

    roots = sub.add_parser("roots", help="list, approve or revoke home roots")
    roots.set_defaults(roots_command="list")
    roots_sub = roots.add_subparsers(dest="roots_command")
    roots_list = roots_sub.add_parser("list", aliases=["status"], help="list approved roots")
    roots_list.add_argument("--json", action="store_true")
    roots_approve = roots_sub.add_parser(
        "approve", aliases=["add", "grant"], help="approve a directory"
    )
    roots_approve.add_argument("path", nargs="?")
    roots_approve.add_argument("--path", dest="path_option")
    roots_approve.add_argument("--mode", default="ro", help="ro (default) or rw")
    roots_approve.add_argument(
        "--rw", "--read-write", action="store_true", help="alias for --mode rw"
    )
    roots_approve.add_argument("--ro", action="store_true", help="alias for --mode ro")
    roots_approve.add_argument("--json", action="store_true")
    roots_revoke = roots_sub.add_parser(
        "revoke", aliases=["remove"], help="revoke a generated grant"
    )
    roots_revoke.add_argument("path", nargs="?")
    roots_revoke.add_argument("--path", dest="path_option")
    roots_revoke.add_argument("--json", action="store_true")

    approve = sub.add_parser("approve", help="approve a root (alias for roots approve)")
    approve.add_argument("path")
    approve.add_argument("--mode", default="ro")
    approve.add_argument("--rw", "--read-write", action="store_true")
    approve.add_argument("--ro", action="store_true")
    approve.add_argument("--json", action="store_true")

    revoke = sub.add_parser("revoke", help="revoke a root (alias for roots revoke)")
    revoke.add_argument("path")
    revoke.add_argument("--json", action="store_true")

    read = sub.add_parser(
        "read", aliases=["read_file", "cat"], help="read a text file inside an approved root"
    )
    read.add_argument("path", nargs="?")
    read.add_argument("--path", dest="path_option")
    read.add_argument("--offset", type=int)
    read.add_argument("--limit", type=int)
    read.add_argument("--allow-hard-link", action="store_true")
    read.add_argument("--json", action="store_true")

    listing = sub.add_parser(
        "list", aliases=["list_dir", "ls"], help="list a directory inside an approved root"
    )
    listing.add_argument("path", nargs="?")
    listing.add_argument("--path", dest="path_option")
    listing.add_argument("--json", action="store_true")

    search = sub.add_parser(
        "search", aliases=["search_text", "grep"], help="literal case-insensitive text search"
    )
    search.add_argument("query", nargs="?")
    search.add_argument("path", nargs="?")
    search.add_argument("--query", dest="query_option")
    search.add_argument("--path", dest="path_option")
    search.add_argument("--max-hits", type=int, default=100)
    search.add_argument("--json", action="store_true")

    write = sub.add_parser(
        "write", aliases=["write_file"], help="request or confirm a file write"
    )
    write.add_argument("path", nargs="?")
    write.add_argument("--path", dest="path_option")
    write.add_argument("--content", default=None)
    write.add_argument("--content-file", default=None)
    write.add_argument("--stdin", action="store_true")
    write.add_argument("--read-id", default=None)
    write.add_argument(
        "--confirm", "--confirm-token", dest="confirm_token", default=None
    )
    write.add_argument("--json", action="store_true")

    confirm = sub.add_parser("confirm", help="apply a pending write confirmation")
    confirm.add_argument("token")
    confirm.add_argument("--allow", action="store_true", help="explicitly allow")
    confirm.add_argument("--deny", action="store_true")
    confirm.add_argument("--json", action="store_true")

    deny = sub.add_parser("deny", help="decline a pending write confirmation")
    deny.add_argument("token")
    deny.add_argument("--json", action="store_true")

    audit = sub.add_parser("audit", help="read the local metadata-only audit log")
    audit.set_defaults(audit_command="tail", lines=50)
    audit_sub = audit.add_subparsers(dest="audit_command")
    audit_tail = audit_sub.add_parser("tail", help="show the newest audit entries")
    audit_tail.add_argument("-n", "--lines", type=int, default=50)
    audit_tail.add_argument("--json", action="store_true")
    audit_sub.add_parser("path", help="print the audit file path")

    config = sub.add_parser("config", help="show or check the configuration")
    config.set_defaults(config_command="path")
    config_sub = config.add_subparsers(dest="config_command")
    config_sub.add_parser("path", help="print the ai.lua and ai.roots.lua paths")
    config_sub.add_parser("check", help="validate ai.lua without running it")

    redact_cmd = sub.add_parser("redact", help="redact secret-shaped text")
    redact_cmd.add_argument("--text", default=None)
    redact_cmd.add_argument("--json", action="store_true")

    propose = sub.add_parser(
        "propose-command", aliases=["propose_command"], help="show a command, never run it"
    )
    propose.add_argument("argv", nargs=argparse.REMAINDER)
    propose.add_argument("--json", action="store_true")

    for name in ("command", "exec", "run", "shell"):
        disabled = sub.add_parser(name, help="refused: the broker is not a shell")
        disabled.add_argument("argv", nargs=argparse.REMAINDER)
        disabled.add_argument("--json", action="store_true")

    return parser


def _path_arg(args: argparse.Namespace) -> str:
    path = getattr(args, "path", None) or getattr(args, "path_option", None)
    if not path:
        raise BrokerError("a path is required", code="bad_request")
    return path


def _roots_human(data: dict[str, Any]) -> None:
    roots = data.get("roots") or []
    if not roots:
        print("no roots approved")
        print("approve one with: padilha-ai roots approve ~/Documents")
        return
    for root in roots:
        print(f"{root['mode']:<2}  {root['source']:<6}  {root['path']}")


def _print_result(args: argparse.Namespace, value: Any, human: str | None = None) -> None:
    if getattr(args, "json", False):
        _emit_json(value)
    elif human is not None:
        print(human)
    else:
        if isinstance(value, str):
            print(value)
        else:
            _emit_json(value)


def _write_content(broker: Broker, args: argparse.Namespace) -> str:
    if args.stdin:
        return sys.stdin.read()
    if args.content_file:
        # The broker decides whether the source is readable, so a shell
        # convenience cannot bypass the approved roots or the deny list.
        return broker.read_file(args.content_file).text
    if args.content is None:
        raise BrokerError(
            "write needs --content, --content-file or --stdin", code="bad_request"
        )
    if args.content == "-":
        return sys.stdin.read()
    return args.content


_COMMAND_ALIASES = {
    "read_file": "read",
    "cat": "read",
    "list_dir": "list",
    "ls": "list",
    "search_text": "search",
    "grep": "search",
    "write_file": "write",
    "propose_command": "propose-command",
}


def _run_cli(broker: Broker, args: argparse.Namespace) -> int:
    command = _COMMAND_ALIASES.get(args.command, args.command)

    if command == "status":
        data = broker.status()
        if args.json:
            _emit_json(data)
        else:
            print(f"state: {data['state']}")
            if data.get("message"):
                print(data["message"])
            print(f"write: {'enabled' if data['write'] else 'disabled'}")
            print(f"config: {data.get('config')}")
            print(f"roots file: {data['roots_file']}")
            print(f"audit: {data['audit']}")
            _roots_human(data)
        return 0

    if command == "roots":
        action = getattr(args, "roots_command", None) or "list"
        if action in ("list", "status"):
            data = broker.list_roots()
            if args.json:
                _emit_json(data)
            else:
                _roots_human(data)
                if data.get("warnings"):
                    for warning in data["warnings"]:
                        print(f"warning: {warning}", file=sys.stderr)
            return 0
        if action in ("approve", "add", "grant"):
            root_path = args.path or args.path_option
            if not root_path:
                raise BrokerError("root approval needs a path", code="bad_request")
            mode = "ro" if args.ro else ("rw" if args.rw else args.mode)
            data = broker.grant_root(root_path, mode)
            if args.json:
                _emit_json(data)
            else:
                print(f"approved {data['mode']} root {data['path']}")
            return 0
        if action in ("revoke", "remove"):
            root_path = args.path or args.path_option
            if not root_path:
                raise BrokerError("root revocation needs a path", code="bad_request")
            data = broker.revoke_root(root_path)
            if args.json:
                _emit_json(data)
            else:
                print(f"{data['status']}: {data.get('path', args.path)}")
                if data.get("message"):
                    print(data["message"])
            return 0
        raise BrokerError("unknown roots command", code="bad_request")

    if command in ("approve", "revoke"):
        if command == "approve":
            mode = "ro" if args.ro else ("rw" if args.rw else args.mode)
            data = broker.grant_root(args.path, mode)
            if args.json:
                _emit_json(data)
            else:
                print(f"approved {data['mode']} root {data['path']}")
        else:
            data = broker.revoke_root(args.path)
            if args.json:
                _emit_json(data)
            else:
                print(f"{data['status']}: {data.get('path', args.path)}")
                if data.get("message"):
                    print(data["message"])
        return 0

    if command == "read":
        result = broker.read_file(
            _path_arg(args),
            offset=args.offset,
            limit=args.limit,
            allow_hard_link=args.allow_hard_link,
        )
        if args.json:
            _emit_json(result.as_dict())
        else:
            sys.stdout.write(result.text)
            if result.text and not result.text.endswith("\n"):
                sys.stdout.write("\n")
        return 0

    if command == "list":
        result = broker.list_dir(_path_arg(args))
        if args.json:
            _emit_json(result.as_dict())
        else:
            if not result.entries:
                print("(empty)" if not result.truncated else "(truncated)")
            for entry in result.entries:
                size = "" if entry.size is None else str(entry.size)
                print(f"{entry.kind:<9} {size:>10}  {entry.path}")
            if result.truncated:
                print("(truncated)")
        return 0

    if command == "search":
        query = args.query_option or args.query
        path = args.path_option or args.path
        if not query:
            raise BrokerError("search needs a query", code="bad_request")
        if not path:
            raise BrokerError("search needs a path", code="bad_request")
        result = broker.search_text(query, path, max_hits=args.max_hits)
        if args.json:
            _emit_json(result.as_dict())
        else:
            for hit in result.hits:
                print(f"{hit['path']}:{hit['line']}: {hit['text']}")
            if not result.hits:
                print("no matches")
            if result.truncated:
                print("(truncated)")
        return 0

    if command == "write":
        if args.confirm_token:
            result = broker.confirm_write(args.confirm_token)
            if args.json:
                _emit_json(result.as_dict())
            else:
                print(f"wrote {result.path} ({result.bytes} bytes)")
            return 0
        path = _path_arg(args)
        pending = broker.request_write(
            path, _write_content(broker, args), read_id=args.read_id
        )
        if args.json:
            _emit_json(pending.as_dict())
        else:
            print(f"confirmation required for {pending.path}")
            print(f"bytes: {pending.bytes}")
            print(f"old sha256: {pending.old_sha256}")
            print(f"new sha256: {pending.new_sha256}")
            print(f"confirm with: padilha-ai confirm {pending.token}")
            if pending.diff:
                print("--- diff ---")
                print(pending.diff)
        return 4

    if command == "confirm":
        if args.deny:
            broker.deny_write(args.token)
            data = {"status": "denied", "token": args.token}
        else:
            result = broker.confirm_write(args.token)
            data = result.as_dict()
        if args.json:
            _emit_json(data)
        else:
            print(data["status"])
        return 0

    if command == "deny":
        broker.deny_write(args.token)
        data = {"status": "denied", "token": args.token}
        if args.json:
            _emit_json(data)
        else:
            print("denied")
        return 0

    if command == "audit":
        action = getattr(args, "audit_command", None) or "tail"
        if action == "path":
            print(broker.audit.path)
            return 0
        entries = broker.audit.tail(args.lines)
        if args.json:
            _emit_json(entries)
        else:
            for entry in entries:
                print(json.dumps(entry, ensure_ascii=False, sort_keys=True))
        return 0

    if command == "config":
        action = getattr(args, "config_command", None) or "path"
        if action == "path":
            print(f"config: {broker.config_path}")
            print(f"roots: {broker.roots_path}")
            print(f"state: {broker.state_dir}")
            return 0
        # Loading the broker already ran the restricted dumper and validated
        # the file mode and shape.
        print("ai.lua is valid")
        return 0

    if command == "redact":
        text = args.text
        if text is None:
            text = sys.stdin.read()
        result = redact(text)
        if args.json:
            _emit_json(
                {
                    "text": result.text,
                    "redactions": result.count,
                    "kinds": list(result.kinds),
                }
            )
        else:
            sys.stdout.write(result.text)
            if result.text and not result.text.endswith("\n"):
                sys.stdout.write("\n")
        return 0

    if command == "propose-command":
        data = broker.propose_command(" ".join(args.argv))
        if args.json:
            _emit_json(data)
        else:
            print(data["command"])
            print("not executed; copy it and run it yourself", file=sys.stderr)
        return 0

    if command in ("command", "exec", "run", "shell"):
        broker.execute_command(" ".join(args.argv))
        return 0

    raise BrokerError("unknown command", code="bad_request")


def _protocol_error(request: Any, exc: BaseException) -> dict[str, Any]:
    out = {"v": 1, "type": "error", **_error_dict(exc)}
    if isinstance(request, dict):
        if "id" in request:
            out["id"] = request["id"]
        out["request"] = request.get("cmd")
    return out


def _run_stdio(broker: Broker) -> int:
    ready = {
        "v": 1,
        "type": "ready",
        "backend": "padilha-ai",
        "version": VERSION,
        "state": "no_roots" if not broker.roots else "ready",
        "roots": [_display_root(broker, root.path) for root in broker.roots],
        "root_entries": [
            {
                "path": root.path,
                "display": _display_root(broker, root.path),
                "mode": root.mode,
                "source": root.source,
            }
            for root in broker.roots
        ],
        "write": broker.config.write_enabled,
        "exec": False,
        "audit": str(broker.audit.path),
        "models": chat_models(broker.config),
        "chat": bool(chat_models(broker.config)),
    }
    _emit_json(ready)
    sys.stdout.flush()

    for line in sys.stdin:
        if len(line) > MAX_PROTOCOL_LINE:
            _emit_json(
                {
                    "v": 1,
                    "type": "error",
                    "code": "line_too_long",
                    "message": "protocol line is larger than 1 MiB",
                }
            )
            sys.stdout.flush()
            continue
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            _emit_json(
                {
                    "v": 1,
                    "type": "error",
                    "code": "bad_json",
                    "message": "expected one JSON object per line",
                }
            )
            sys.stdout.flush()
            continue
        if not isinstance(request, dict):
            _emit_json(
                {
                    "v": 1,
                    "type": "error",
                    "code": "bad_request",
                    "message": "expected a JSON object",
                }
            )
            sys.stdout.flush()
            continue

        command = request.get("cmd") or request.get("command") or ""
        request_id = request.get("id")
        if command == "shutdown":
            _emit_json({"v": 1, "type": "done", "id": request_id, "stop": "shutdown"})
            sys.stdout.flush()
            return 0
        try:
            event = _dispatch_protocol(broker, command, request)
            if event is not None:
                if request_id is not None:
                    event.setdefault("id", request_id)
                event.setdefault("v", 1)
                _emit_json(event)
                sys.stdout.flush()
        except (
            BrokerError,
            ChatError,
            ConfigError,
            OSError,
            ValueError,
            TypeError,
            KeyError,
            AttributeError,
        ) as exc:
            _emit_json(_protocol_error(request, exc))
            sys.stdout.flush()
    return 0


def _display_root(broker: Broker, path: str) -> str:
    from .policy import display_path

    return display_path(path, broker.home)


def _dispatch_protocol(
    broker: Broker, command: str, request: dict[str, Any]
) -> dict[str, Any] | None:
    if command in ("read", "read_file", "cat"):
        raw = request.get("path") or request.get("file")
        if not raw:
            raise BrokerError("read needs a path", code="bad_request")
        result = broker.read_file(
            str(raw),
            offset=request.get("offset"),
            limit=request.get("limit"),
            allow_hard_link=bool(request.get("allow_hard_link", False)),
        )
        return {
            "type": "tool",
            "name": "read_file",
            "decision": "allow",
            "reason": "in_root",
            **result.as_dict(),
        }

    if command in ("list", "list_dir", "ls"):
        raw = request.get("path") or request.get("dir")
        if not raw:
            raise BrokerError("list needs a path", code="bad_request")
        result = broker.list_dir(str(raw))
        return {
            "type": "tool",
            "name": "list_dir",
            "decision": "allow",
            "reason": "in_root",
            **result.as_dict(),
        }

    if command in ("search", "search_text"):
        query = request.get("query") or request.get("text")
        raw = request.get("path") or request.get("dir")
        if not query or not raw:
            raise BrokerError("search needs a query and a path", code="bad_request")
        result = broker.search_text(
            str(query), str(raw), max_hits=int(request.get("max_hits", 100))
        )
        return {
            "type": "tool",
            "name": "search_text",
            "decision": "allow",
            "reason": "in_root",
            **result.as_dict(),
        }

    if command in ("write", "write_file"):
        token = request.get("confirm_token") or request.get("token")
        confirm = request.get("confirm")
        if isinstance(confirm, str) and not token:
            token = confirm
        if token and (
            confirm is True
            or isinstance(confirm, str)
            or ("content" not in request and "text" not in request)
        ):
            result = broker.confirm_write(str(token))
            return {"type": "done", "name": "write_file", **result.as_dict()}
        raw = request.get("path") or request.get("file")
        if not raw:
            raise BrokerError("write needs a path", code="bad_request")
        content = request.get("content")
        if content is None:
            content = request.get("text")
        if not isinstance(content, (str, bytes)):
            raise BrokerError("write needs text content", code="bad_request")
        pending = broker.request_write(
            str(raw), content, read_id=request.get("read_id")
        )
        return {
            "type": "confirm",
            "operation": "write_file",
            **pending.as_dict(),
        }

    if command == "confirm":
        token = request.get("token") or request.get("confirm_token")
        if not token:
            raise BrokerError("confirm needs a token", code="bad_request")
        if request.get("allow") is False:
            broker.deny_write(str(token))
            return {"type": "done", "stop": "denied"}
        result = broker.confirm_write(str(token))
        return {"type": "done", "stop": "complete", **result.as_dict()}

    if command == "deny":
        token = request.get("token")
        if not token:
            raise BrokerError("deny needs a token", code="bad_request")
        broker.deny_write(str(token))
        return {"type": "done", "stop": "denied"}

    if command in ("roots", "root"):
        action = request.get("action") or "list"
        if action in ("list", ""):
            return {"type": "roots", **broker.list_roots()}
        if action in ("approve", "grant", "add"):
            raw = request.get("path")
            if not raw:
                raise BrokerError("root approval needs a path", code="bad_request")
            mode = "rw" if request.get("rw") else request.get("mode", "ro")
            return {
                "type": "roots",
                "action": "approved",
                **broker.grant_root(str(raw), str(mode)),
            }
        if action in ("revoke", "remove"):
            raw = request.get("path")
            if not raw:
                raise BrokerError("root revocation needs a path", code="bad_request")
            return {
                "type": "roots",
                "action": "revoked",
                **broker.revoke_root(str(raw)),
            }
        raise BrokerError("unknown roots action", code="bad_request")

    if command in ("roots.approve", "roots.grant"):
        raw = request.get("path")
        if not raw:
            raise BrokerError("root approval needs a path", code="bad_request")
        mode = "rw" if request.get("rw") else request.get("mode", "ro")
        return {"type": "roots", "action": "approved", **broker.grant_root(str(raw), str(mode))}

    if command in ("roots.revoke", "roots.remove"):
        raw = request.get("path")
        if not raw:
            raise BrokerError("root revocation needs a path", code="bad_request")
        return {"type": "roots", "action": "revoked", **broker.revoke_root(str(raw))}

    if command == "status":
        return {"type": "status", **broker.status()}

    if command == "reload":
        return {"type": "status", **broker.reload()}

    if command == "cancel":
        return {"type": "done", "stop": "cancelled"}

    if command in ("propose_command", "propose-command"):
        raw = request.get("command") or request.get("text")
        if not raw:
            raise BrokerError("propose_command needs a command", code="bad_request")
        return {"type": "tool", "name": "propose_command", **broker.propose_command(str(raw))}

    if command in ("command", "exec", "run", "shell"):
        broker.execute_command(str(request.get("command", "")))
        return None

    if command in ("chat", "start"):
        if command == "start":
            return None
        result = complete(
            broker.config,
            request.get("model"),
            request.get("messages"),
        )
        broker.audit.record(
            "chat_turn",
            model=result.get("model"),
            provider=result.get("provider"),
            messages=len(request.get("messages") or []),
            answer_bytes=len(result.get("text", "")),
            redactions=result.get("redactions", 0),
        )
        return {"type": "done", "stop": "complete", **result}

    raise BrokerError("unknown command", code="unknown_command")


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if "--version" in argv or "-V" in argv:
        print(f"padilha-ai {VERSION}")
        return 0

    try:
        rest, globals_ = _extract_globals(argv)
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 2

    if globals_["roots_file"]:
        os.environ["PADILHA_AI_ROOTS"] = globals_["roots_file"]

    home = globals_["home"] or str(home_from_environment())
    try:
        broker = Broker(
            home=home,
            config_path=globals_["config"],
            state_dir=globals_["state_dir"],
        )
    except ConfigError as exc:
        print(f"padilha-ai: {exc}", file=sys.stderr)
        return 2

    if globals_["stdio"]:
        try:
            return _run_stdio(broker)
        except KeyboardInterrupt:
            return 0

    parser = _build_parser()
    if not rest or rest[0] in ("help", "-h", "--help"):
        parser.print_help()
        return 0
    args = parser.parse_args(rest)
    if not getattr(args, "command", None):
        parser.print_help()
        return 0
    args.json = bool(getattr(args, "json", False) or globals_["json"])

    try:
        return _run_cli(broker, args)
    except ConfirmationRequired as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(f"padilha-ai: {exc}", file=sys.stderr)
        return 4
    except Denied as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(
                f"padilha-ai: denied ({exc.decision.reason}): {exc.decision.display}",
                file=sys.stderr,
            )
        return 3
    except AuditUnavailable as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(f"padilha-ai: {exc}", file=sys.stderr)
        return 5
    except ConfirmationError as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(f"padilha-ai: {exc}", file=sys.stderr)
        return 6
    except (BinaryFile, TooLarge, UnsafePath) as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(f"padilha-ai: {exc}", file=sys.stderr)
        return 3
    except BrokerError as exc:
        if globals_["json"]:
            _emit_json(exc.as_dict())
        else:
            print(f"padilha-ai: {exc}", file=sys.stderr)
        return 2
    except (OSError, ValueError, TypeError) as exc:
        if globals_["json"]:
            _emit_json(_error_dict(exc))
        else:
            print(f"padilha-ai: {redact(str(exc)).text}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130
