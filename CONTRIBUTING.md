# Contributing

Maria Padilha is GPL-3.0-only. Contributions are welcome through issues and
pull requests.

## Before you start

- The desktop repository is `maria-padilha-de`; the configs live in the sibling
  `maria-padilha-dotfiles` checkout. The installer looks for
  `../maria-padilha-dotfiles` or `PADILHA_DOTFILES`.
- Do not commit secrets. `hypr/hyprland/env.local.lua` (dotfiles) is ignored and
  must stay local.
- Never deploy from a pull request: package installation, Pages publication, and
  release uploads are maintainer actions.

## Development loop

From `maria-padilha-de/`:

```sh
bash tests/all.sh          # contract suites (compiler, theme, commands)
make lint                  # shellcheck, luacheck, ruff, yamllint, Lua parse
make docs                  # local Jekyll site in .scratch/docs-site
./install.sh --dry-run --full
tools/build.sh             # CMake/Ninja shell build, including the C++ plugin
```

The shell build needs Qt 6, CMake, Ninja, libqalculate, libpipewire, aubio, and
libcava. `libcava` is AUR-only on Arch; CI builds the upstream source tag.

For dotfiles changes:

```sh
cd ../maria-padilha-dotfiles
tests/ci.sh
```

## Style

- **Shell:** POSIX `sh` in `bin/` and `install.sh`; Bash only for tests and
  tooling; `set -eu`, quoted paths, no `eval`.
- **Lua:** Lua 5.5 for `bin/` and `lib/`; Hyprland config uses the `hl.*` API and
  must parse with `lua -e 'assert(loadfile("..."))'`.
- **QML:** use the existing `Colours`, `Tokens`, and `Quickshell` services. Do not
  hard-code a palette outside generated state.
- **Docs:** one Jekyll site under `docs/` with `baseurl: /maria-padilha-de`.
- **Packaging:** when adding a `bin/` command, update `install.sh`'s `commands`
  array and the symlink loop in `packaging/PKGBUILD` together.

## Pull requests

- Keep the change focused; explain the user-visible effect and how you tested it.
- Include tests for new contracts, especially anything that writes a file,
  validates user input, or changes a command's exit status.
- Do not include generated build trees, package artefacts, logs, sessions, or
  screenshots containing private windows.
- Keep compatibility aliases working unless the change explicitly removes
  them.

## License

By contributing you agree that your changes are licensed under GPL-3.0-only,
the same terms as the project.
