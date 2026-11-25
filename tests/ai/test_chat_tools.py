#!/usr/bin/env python3
"""Contract tests for the assistant's read-only chat tool loop.

The provider is stubbed at ``chat._post_provider``; no network is touched.  The
runner is stubbed too, so these tests describe the loop contract while
tests/ai/run.sh covers the real broker behind it.
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

from ai import chat
from ai.chat import ChatError, complete
from ai.config import Config


class FakeRunner:
    def __init__(self, result: dict | None = None) -> None:
        self.calls: list[tuple[str, dict]] = []
        self.result = result or {"path": "~/Documents/a.txt", "text": "hello"}

    def call(self, name: str, arguments: dict) -> dict:
        self.calls.append((name, arguments))
        return self.result


def make_config(*, tools: bool = True, permissions: dict | None = None) -> Config:
    model: dict = {"provider": "p", "model": "m", "context": 4096}
    if tools:
        model["tools"] = True
    data: dict = {
        "default_model": "test",
        "models": {"test": model},
        "providers": {
            "p": {
                "kind": "openai-compatible",
                "base_url": "https://example.invalid/v1",
                "api_key": "test-key",
            }
        },
    }
    if permissions:
        data["permissions"] = permissions
    return Config(path=None, roots_path=Path("/nonexistent/roots.lua"), data=data)


def reply(message: dict, usage: dict | None = None) -> dict:
    return {"choices": [{"message": message}], "usage": usage or {"total_tokens": 1}}


def tool_call(name: str = "read_file", arguments: dict | None = None, call_id: str = "call-1") -> dict:
    return {
        "id": call_id,
        "type": "function",
        "function": {
            "name": name,
            "arguments": json.dumps(arguments or {"path": "~/Documents/a.txt"}),
        },
    }


class ToolLoopTests(unittest.TestCase):
    def run_complete(self, responses: list[dict], runner: FakeRunner, cfg: Config | None = None):
        payloads: list[dict] = []
        iterator = iter(responses)

        def fake_post(config, provider, payload):
            payloads.append(payload)
            return next(iterator)

        with mock.patch.object(chat, "_post_provider", side_effect=fake_post):
            result = complete(
                cfg or make_config(),
                None,
                [{"role": "user", "content": "hi"}],
                runner=runner,
            )
        return result, payloads

    def test_runs_read_tool_and_returns_final_answer(self):
        runner = FakeRunner({"path": "~/Documents/a.txt", "text": "hello"})
        result, payloads = self.run_complete(
            [
                reply({"content": None, "tool_calls": [tool_call()]}),
                reply({"content": "The file says hello."}, {"total_tokens": 7}),
            ],
            runner,
        )
        self.assertEqual(result["text"], "The file says hello.")
        self.assertEqual(result["tool_calls"], 1)
        self.assertEqual(runner.calls, [("read_file", {"path": "~/Documents/a.txt"})])
        self.assertIn("tools", payloads[0])
        tool_message = payloads[1]["messages"][-1]
        self.assertEqual(tool_message["role"], "tool")
        self.assertIn("hello", tool_message["content"])

    def test_rejects_tool_call_without_declared_capability(self):
        runner = FakeRunner()
        with self.assertRaises(ChatError) as ctx:
            self.run_complete(
                [reply({"content": None, "tool_calls": [tool_call()]})],
                runner,
                cfg=make_config(tools=False),
            )
        self.assertEqual(ctx.exception.code, "unexpected_tool_call")
        self.assertEqual(runner.calls, [])

    def test_stops_at_the_tool_call_limit(self):
        runner = FakeRunner()
        with self.assertRaises(ChatError) as ctx:
            self.run_complete(
                [
                    reply({"content": None, "tool_calls": [tool_call(call_id="a")]}),
                    reply({"content": None, "tool_calls": [tool_call(call_id="b")]}),
                ],
                runner,
                cfg=make_config(permissions={"max_tool_calls": 1}),
            )
        self.assertEqual(ctx.exception.code, "tool_limit")

    def test_malformed_arguments_become_a_tool_error(self):
        call = {
            "id": "c",
            "type": "function",
            "function": {"name": "read_file", "arguments": "not json"},
        }
        runner = FakeRunner()
        result, payloads = self.run_complete(
            [reply({"content": None, "tool_calls": [call]}), reply({"content": "ok"})],
            runner,
        )
        self.assertEqual(result["text"], "ok")
        self.assertEqual(runner.calls, [])
        self.assertIn("invalid_arguments", payloads[1]["messages"][-1]["content"])

    def test_tool_output_is_redacted(self):
        secret = "sk-" + "a" * 48
        runner = FakeRunner({"path": "~/x", "text": f"key {secret}"})
        result, payloads = self.run_complete(
            [reply({"content": None, "tool_calls": [tool_call()]}), reply({"content": "done"})],
            runner,
        )
        self.assertGreater(result["redactions"], 0)
        tool_message = payloads[1]["messages"][-1]["content"]
        self.assertNotIn(secret, tool_message)
        self.assertIn("REDACTED", tool_message)


if __name__ == "__main__":
    unittest.main(verbosity=2)
