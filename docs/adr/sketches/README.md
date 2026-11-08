# ADR 0001 sketches

These files are review aids, not implementation.

- They are **not** installed by `install.sh` or the package.
- They are **not** imported by `shell.qml` or any QML module.
- They contain **no real credential**; the only key-shaped strings are
  placeholders and test patterns.
- The path sketch assumes an already canonical path and implements only the
  last-line checks. The real implementation must use `openat2(2)` or the
  stricter component walk described in the ADR.

| File | What it illustrates |
| --- | --- |
| `ai.lua.example` | The configuration shape, credential-store references, and read-only roots. |
| `policy.lua` | Root/deny decisions over a canonical path, including component-boundary checks. |
| `assistant-panel.qml` | The panel skeleton: header, transcript, composer, confirmation card. |
| `protocol.jsonl` | The JSON-lines messages between QML and `padilha-ai --stdio`. |

The sketches deliberately omit provider HTTP, credential lookup, audit writes,
and file I/O. Those are the parts that need tests and review before any of this
is wired into the shell.
