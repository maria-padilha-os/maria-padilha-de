#!/usr/bin/env python3
"""Small fake greetd server for the greeter auth-flow test."""

from __future__ import annotations

import json
import os
import socket
import struct
import sys


def send(conn: socket.socket, payload: dict) -> None:
    data = json.dumps(payload, separators=(",", ":")).encode()
    conn.sendall(struct.pack("<I", len(data)) + data)


def main() -> int:
    path, transcript = sys.argv[1], sys.argv[2]
    if os.path.exists(path):
        os.unlink(path)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(path)
    server.listen(1)
    with open(transcript, "w", encoding="utf-8") as log:
        conn, _ = server.accept()
        while True:
            header = conn.recv(4)
            if len(header) != 4:
                break
            length = struct.unpack("<I", header)[0]
            payload = b""
            while len(payload) < length:
                chunk = conn.recv(length - len(payload))
                if not chunk:
                    return 0
                payload += chunk
            message = json.loads(payload)
            log.write(json.dumps(message) + "\n")
            log.flush()
            kind = message.get("type")
            if kind == "create_session":
                send(conn, {"type": "auth_message", "auth_message": "Password:", "auth_message_type": "secret"})
            elif kind == "post_auth_message_response":
                if message.get("response") == "secret":
                    send(conn, {"type": "success"})
                else:
                    send(conn, {"type": "error", "error_type": "auth_error", "description": "bad password"})
            elif kind == "start_session":
                send(conn, {"type": "success"})
                return 0
            elif kind == "cancel_session":
                send(conn, {"type": "success"})
                return 0
            else:
                send(conn, {"type": "error", "error_type": "error", "description": "unknown request"})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
