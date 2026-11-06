#!/usr/bin/env bash
# Fast static checks for the development toolchain. It deliberately does not
# try to be a formatter: formatting is a separate, reviewable change.
#
# Exit status is meaningful: a failing syntax check, shellcheck, luacheck,
# ruff, yamllint, or Lua parse makes `make lint` fail.
set -uo pipefail

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root" || exit 1

status=0
fail() {
    printf 'lint: %s\n' "$*" >&2
    status=1
}

shell_files=()
echo "== shell syntax"
for f in bin/* install.sh tests/*.sh tools/*; do
    [ -f "$f" ] || continue
    [ -L "$f" ] && continue
    first=$(head -n1 "$f" 2>/dev/null) || continue
    case "$first" in
        *bash*)
            shell_files+=("$f")
            bash -n "$f" || fail "bash -n $f"
            ;;
        *sh*)
            shell_files+=("$f")
            sh -n "$f" || fail "sh -n $f"
            ;;
    esac
done

if command -v shellcheck >/dev/null 2>&1; then
    echo "== shellcheck"
    shellcheck --severity=warning --external-sources "${shell_files[@]}" || fail "shellcheck"
fi

if command -v luacheck >/dev/null 2>&1; then
    echo "== luacheck"
    luacheck --no-color --codes lib/*.lua \
        bin/padilha bin/padilha-config bin/padilha-theme bin/padilha-daylight ||
        fail "luacheck"
fi

if command -v ruff >/dev/null 2>&1; then
    echo "== ruff"
    ruff check --select E9,F63,F7,F82 tools tests || fail "ruff"
fi

if command -v yamllint >/dev/null 2>&1; then
    echo "== yamllint"
    yamllint -d relaxed docs/_config.yml .github/workflows/*.yml || fail "yamllint"
fi

echo "== lua parse (dotfiles)"
dots_dir=
for candidate in ../maria-padilha-dotfiles ../lilith-dotfiles; do
    if [ -d "$candidate" ]; then
        dots_dir=$candidate
        break
    fi
done
if [ -n "$dots_dir" ]; then
    while IFS= read -r -d '' f; do
        lua -e "assert(loadfile('$f'))" || fail "lua parse $f"
    done < <(find "$dots_dir/hypr" -name '*.lua' -print0)
fi

if [ "$status" -ne 0 ]; then
    echo "lint: failed" >&2
    exit 1
fi
echo "lint: done"
