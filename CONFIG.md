# Configuring Padilha

One file, one language. The compositor is already configured in Lua; the
shell should not require a different language and a different mental model.

`~/.config/padilha/init.lua` returns a table. The compiler merges it over the
shell's built-in defaults and writes the JSON the shell reads. Nothing
downstream knows Lua exists.

## Files

| path | role |
| --- | --- |
| `~/.config/padilha/init.lua` | your config — the source |
| `~/.config/padilha/local.lua` | per-machine overrides, same shape, wins over `init.lua` |
| `~/.config/caelestia/shell.json` | generated — never edit by hand |

## Precedence

```
shell defaults (C++)  <  init.lua  <  local.lua
```

`local.lua` is for what differs per machine (a laptop with a different bar
height, a desktop with no battery). It is gitignored, the same pattern as
`hypr/hyprland/env.local.lua`.

## What you can write

Data only:

- booleans, numbers, strings, tables
- `padilha.array {}` when you need an empty **list** — Lua cannot tell an
  empty list from an empty map, and the schema can
- anything Lua can compute: a loop that builds per-monitor entries, a table
  built from another table, `if` on hostname

Keys are checked against the shell's own schema — the `caelestia-config.qmltypes`
that `qmltyperegistrar` writes next to the module. An unknown key is an error
with a suggestion (`config.appearanc: unknown key (did you mean "appearance"?)`)
and so is a wrong type. Enum values are checked too, case-insensitively, the way
the shell reads them: `config.bar.palette: expected one of Wallpaper, Fixed,
got "Fixd" (did you mean "Fixed"?)`. `--no-schema` skips the check;
`--schema PATH` points at a different qmltypes.

## What you cannot write yet

- **Functions.** `hooks` is reserved and rejected with an error until the
  theme engine exists to call them. This is deliberate: a config that can
  hang is a config that breaks the session.
- **Reactivity.** The file is evaluated once, at compile time. It is a
  config, not a plugin: changing a value takes a compile and a shell reload,
  not a live patch.

## What the settings app changes

The shell's own settings UI writes `shell.json` directly. The compiler would
otherwise overwrite those edits at the next login, so it carries them over:

```
defaults  <  init.lua  <  local.lua  <  changes made in the UI
```

How it knows what "changed in the UI" means: next to `shell.json` the compiler
keeps `shell.json.base`, the tree `init.lua` alone produced last time. Anything
that differs between the baseline and the file on disk is an edit, and an edit
wins over `init.lua` — including a key the UI added that `init.lua` never
mentions. A key you *remove* from `init.lua` still disappears, unless the UI
also edited it.

`--no-merge` turns this off and writes `init.lua`'s tree verbatim; it is what
you want when the two have drifted and you would rather start from the file
you can read.

## When it is wrong

The compiler refuses to write a broken config:

- syntax and runtime errors carry the line: `init.lua:12: unexpected symbol near '='`
- type errors carry the key path: `config.bar.onClick: is a function`
- the output is written to a temporary file and renamed, so a failure leaves
  the previous `shell.json` exactly as it was
- exit codes: `0` ok, `1` config error, `2` usage

`tests/run.sh` holds those promises to the fire.

## Commands

```sh
bin/padilha-config compile                  # init.lua -> shell.json
bin/padilha-config compile --check          # parse and validate, write nothing
bin/padilha-config compile --print          # to stdout, for diffing
bin/padilha-config compile --config X.lua --out Y.json
bin/padilha-config compile --schema path/to.qmltypes   # validate against another schema
bin/padilha-config compile --no-schema                 # skip key/type validation
bin/padilha-config compile --no-merge                  # ignore UI edits, init.lua wins
```

At login the session calls `bin/padilha-session`, which compiles `init.lua`
and then starts the shell. A failed compile keeps the previous JSON (the
write is atomic) and the session still comes up, with a notification. To apply
a change without logging out:

```sh
bin/padilha-config compile && caelestia shell -r
```

Watching `init.lua` and reloading on save comes later; `settings.watchFiles`
is deliberately off.

## Example

```lua
-- ~/.config/padilha/init.lua
return {
    appearance = {
        transparency = {
            enabled = false, -- opaque bar and drawers
        },
    },

    general = {
        idle = {
            timeouts = padilha.array {}, -- no automatic lock/suspend on idle
        },
    },
}
```

`examples/init.lua` is this file, and it compiles to exactly the `shell.json`
the machine runs today — the model is lossless before it is mandatory.
