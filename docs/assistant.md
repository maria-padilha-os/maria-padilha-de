---
layout: default
title: Assistant and DSH
---

The **Assistant** drawer is now a native front-end to DeepSeek Harness. It
reads DSH session history from `~/.dsh/sessions`, lets you switch between
sessions, and sends new prompts through `dsh sdk`. It does not see the DSH
provider key. Toggle it with `Super + A` or the sparkle button in the bar.

The older home-folder broker, `padilha-ai`, remains available as a CLI
permission boundary from [ADR 0001](adr/0001-built-in-ai-assistant.md). It
exposes only the directories the user approves, reads text files by default,
redacts secret-shaped content before returning it, and writes only after a
separate one-operation confirmation. It is not a shell, and it is no longer
the drawer's chat backend.

## Default OS-maintenance session

The drawer remembers a fixed default session in
`~/.config/padilha/dsh-default-session` and selects it on startup. The current
default is titled **OS maintenance** and was primed to keep the Arch
installation clean, look for duplicate files and stale caches, and report
risky changes before deleting personal data. Its DSH log is the memory: it
survives restarts and is never silently replaced.

`padilha-dsh` launches its SDK child with
`DSH_PERMISSION_MODE=danger-full-access` unless the environment already sets a
mode, so the maintenance session runs with the high-permission, approvals-off
policy. This applies to sessions created by the widget, so use it
deliberately.

## DSH sessions and the single-writer rule

History is read directly from the compressed DSH session logs; the widget's
session button lists recent sessions with their timestamps. A live DSH session
has one writer: while `dsh-tui` owns a session, the widget can display its
history but a prompt returns “already owned by an active write handle.” Close
the TUI session or start a new chat in the widget to send.

DSH needs its own model credential. Store it through the DSH web Models page,
or keep it in a private `~/.config/padilha/dsh-key` file (mode `0600`).
`padilha-dsh` loads that file only into its SDK child; the value is never
printed, passed on a command line, or committed. Exporting
`DEEPSEEK_API_KEY` in the launching environment also works.

## Voice input

The experimental voice-input bundle is installed in the DSH **web** profile
and composed by `dsh web`; its microphone lives in the browser UI. The native
Assistant drawer does not consume browser plugins, so it has no microphone
button from that bundle yet.

## File tools in chat

A model declared with `tools = true` in `ai.lua` can call three read-only tools
while answering: `read_file`, `list_dir`, and `search_text`. Every call goes
through the same broker checks — approved roots, built-in denies, redaction and
audit — and after `permissions.max_tool_calls` (8 by default) the panel asks for
one final answer without tools, so a long exploration still ends with a summary
instead of an error.
Writes are not part of the chat loop yet: `write_file` stays behind the CLI's
two-step `write`/`confirm` flow until the panel has its confirmation card.

## Session history

The drawer's history is DSH's own session log, so it survives shell restarts,
TUI restarts and reboots without a separate transcript. The old
`padilha-ai` opt-in transcript (`history = "persist"` in `ai.lua`,
`~/.local/state/padilha/ai/transcript.jsonl`) still belongs to the broker CLI;
the panel no longer writes or restores it.

## No roots approved

A fresh install has no access at all. There is no implicit `$HOME`, current
directory, or `/` root.

```sh
$ padilha-ai roots list
no roots approved
approve one with: padilha-ai roots approve ~/Documents
```

## Approve and revoke

```sh
padilha-ai roots approve ~/Documents          # read-only (the default)
padilha-ai roots approve ~/Projects --rw      # still needs permissions.write
padilha-ai roots list
padilha-ai roots revoke ~/Projects
```

Approvals are written to `~/.config/padilha/ai.roots.lua` with mode `0600`;
hand-written roots in `~/.config/padilha/ai.lua` are never rewritten. The
longest matching root decides the mode. Revocation takes effect on the next
request and is audited.

`~/Documents/.ssh`, `~/.gnupg`, `~/.dsh`, `~/.config/padilha`, browser
profiles, `env.local.lua`, credential files, and paths outside `$HOME` are
denied even when their parent is approved. A symlink that resolves outside the
root is denied too.

## Read, list, and search

```sh
padilha-ai read ~/Documents/notes.md
padilha-ai read ~/Documents/notes.md --offset 20 --limit 40
padilha-ai list ~/Documents
padilha-ai search "project name" ~/Documents
```

Only regular UTF-8 text is returned. Binary files, FIFOs, devices, hard links,
files above the configured size cap, and paths that changed during the read are
refused. Terminal escape sequences are stripped and known secrets are replaced
with `[REDACTED:<kind>]`.

## Writes are two-step

```sh
$ padilha-ai write ~/Projects/notes.md --content 'new text'
confirmation required for ~/Projects/notes.md
...
confirm with: padilha-ai confirm confirm-...
$ padilha-ai confirm confirm-...
```

A write request never touches the target. The confirmation token is opaque,
expires, is bound to the path and file hash, and works once. The broker also
requires the root to be `rw` and `permissions.write = true` in `ai.lua`; even
then there is no "always allow" switch. Existing files are replaced atomically
and a file that changed after the request is refused.

## Commands are never executed

`padilha-ai command ...` is refused. `padilha-ai propose-command ...` returns
text for the user to copy, but it never runs it. There is no unrestricted
shell.

## Audit

Every file decision and chat turn appends a metadata-only JSON line to
`$XDG_STATE_HOME/padilha/ai/audit.jsonl` (mode `0600`). Entries contain the
path, root, decision, byte count, hash, and redaction count, never file
content or a secret value.

```sh
padilha-ai audit tail -n 20
```

## Configuration is data

`~/.config/padilha/ai.lua` must be a user-owned regular file with mode `0600`;
symlinks are refused. It is loaded in a restricted Lua environment without
`os`, `io`, `require`, `load`, or `dofile`, so the file cannot run code. See
`share/ai.lua.example` for the shape.

## Chat transport

The v1 transport supports OpenAI-compatible `/chat/completions` endpoints.
Declare a model and provider in `ai.lua`:

```lua
return {
    default_model = "local",
    models = {
        ["local"] = {
            provider = "local",
            model = "qwen2.5-coder:7b",
            context = 32768,
        },
    },
    providers = {
        ["local"] = {
            kind = "openai-compatible",
            base_url = "http://127.0.0.1:11434/v1",
        },
    },
    network = { allow_insecure_loopback = true },
}
```

Remote providers use HTTPS and either an inline `api_key` in the `0600`
`ai.lua` file or a `credential = { store = "file", path = "~/.config/..." }`
file (also `0600`). The `secret-service` and `pass` stores are not implemented
in this build; the request fails with `credential_unavailable` instead of
falling back to an insecure source.

`padilha-dsh --stdio` emits a `ready` event with recent DSH sessions and the
latest session history. `load` switches sessions, `new_chat` creates a fresh
DSH id, and `chat` forwards the prompt to `dsh sdk`; its session events are
translated back to the panel as assistant text and a final `done`.

The old `padilha-ai --stdio` chat transport remains for the broker CLI. It is
non-streaming and returns a single `done` event.
