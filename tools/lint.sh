#!/usr/bin/env bash
# Fast static checks for the development toolchain. It deliberately does not
# try to be a formatter: formatting is a separate, reviewable change.
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

echo "== shell syntax"
for f in bin/* install.sh tests/*.sh tools/*; do
    [ -f "$f" ] || continue
    case "$f" in
        *.sh|*/install.sh|bin/*|tools/promo-agents|tools/docs-preview)
            if head -n1 "$f" | grep -qE '^#!.*(ba)?sh' || [ "$f" = "install.sh" ]; then
                bash -n "$f"
            fi
            ;;
    esac
done

if command -v shellcheck >/dev/null 2>&1; then
    echo "== shellcheck (errors only)"
    shellcheck --severity=error --external-sources bin/* install.sh tests/*.sh || true
fi

if command -v luacheck >/dev/null 2>&1; then
    echo "== luacheck"
    luacheck --no-color --codes lib bin || true
fi

if command -v ruff >/dev/null 2>&1; then
    echo "== ruff"
    ruff check --select E9,F63,F7,F82 tools tests || true
fi

if command -v yamllint >/dev/null 2>&1; then
    echo "== yamllint"
    yamllint -d relaxed docs/_config.yml .github/workflows/*.yml || true
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
    find "$dots_dir/hypr" -name '*.lua' -print0 |
        while IFS= read -r -d '' f; do
            lua -e "assert(loadfile('$f'))" || exit 1
        done
fi

echo "lint: done"
