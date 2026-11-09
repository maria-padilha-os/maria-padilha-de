---
layout: default
title: Assistant home access
---

# Assistant home access

The assistant's home-folder broker, `padilha-ai`, is the permission boundary
from [ADR 0001](adr/0001-built-in-ai-assistant.md). It exposes only the
directories the user approves, reads text files by default, redacts
secret-shaped content before returning it, and writes only after a separate
one-operation confirmation. It is not a shell.

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
