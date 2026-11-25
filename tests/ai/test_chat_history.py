#!/usr/bin/env python3
"""Contract tests for the persisted assistant transcript (ADR 0001)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

from ai import history


class HistoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.path = history.path_for(Path(self.tmp.name))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_roundtrip_keeps_private_modes(self):
        self.assertTrue(
            history.save(
                self.path,
                [
                    {"role": "user", "text": "hi"},
                    {"role": "assistant", "text": "hello"},
                ],
            )
        )
        self.assertEqual(
            history.load(self.path),
            [{"role": "user", "text": "hi"}, {"role": "assistant", "text": "hello"}],
        )
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.path.parent.stat().st_mode & 0o777, 0o700)

    def test_malformed_and_unknown_entries_are_skipped(self):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.path.write_text(
            'not json\n{"role": "tool", "text": "x"}\n{"role": "assistant", "text": "ok"}\n',
            encoding="utf-8",
        )
        self.assertEqual(history.load(self.path), [{"role": "assistant", "text": "ok"}])

    def test_empty_text_is_not_stored(self):
        self.assertTrue(history.save(self.path, [{"role": "assistant", "text": "  "}]))
        self.assertEqual(history.load(self.path), [])

    def test_clear_is_idempotent(self):
        self.assertTrue(history.clear(self.path))
        self.assertTrue(history.save(self.path, [{"role": "user", "text": "x"}]))
        self.assertTrue(history.clear(self.path))
        self.assertFalse(self.path.exists())
        self.assertTrue(history.clear(self.path))


if __name__ == "__main__":
    unittest.main(verbosity=2)
