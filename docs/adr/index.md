---
layout: default
title: Architecture decisions
---

# Architecture decisions

Architecture decision records (ADRs) capture a design and its trade-offs
before the code exists. They are dated and immutable in intent: a later ADR
supersedes an earlier one rather than rewriting it.

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-built-in-ai-assistant.html) | Accepted (broker implemented) | A separate assistant panel and backend process, a provider-agnostic chat service, and a permissioned, read-only-by-default home-folder policy. |

The sketches beside ADR 0001 are non-normative. They show the shape of the
config, the last-line path checks, the wire protocol, and the panel layout; they
are not installed, imported, or executed by the shell.

See `ARCHITECTURE.md` in the repository root for the layers this decision sits
on, and `CONFIG.md` for why `ai.lua` is deliberately not part of `shell.json`.
