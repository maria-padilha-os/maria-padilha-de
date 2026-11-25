# Lua port of padilha-thunderbird-theme

The shipped helper is now `bin/padilha-thunderbird-theme` in Lua 5.5. This
directory keeps the pre-port Python reference and the fixture comparison used to
prove the port.

## What it does

Finds the Thunderbird profile from `profiles.ini`, renders
`share/templates/thunderbird.css` with the current
`~/.local/state/caelestia/scheme.json`, and atomically rewrites
`chrome/padilha.css`. If no profile exists it exits 0 without writing.

## Compare

```sh
bash spikes/lua-thunderbird-theme/compare.sh
```

The script stages the Python reference with its own `share/templates` and runs
both implementations against fixtures for:

- a relative `Profile0` default in light and dark
- an `Install…Default` profile in light and dark
- no `profiles.ini` (both must write nothing)

All fixture outputs match byte for byte. `tests/cli/thunderbird.sh` covers the
shipped Lua script in CI through `padilha-theme apply` fixtures.

## Notes

- The Lua script uses `lib/json.lua` and the same template placeholder syntax as
  `padilha-theme`; it does not need any module outside the checkout.
- Startup is ~2 ms for Lua versus ~130 ms for CPython, and the process is
  transient either way, so this is a language-consistency change rather than a
  memory win.
- The Python version remains at `reference.py` for future comparisons.
