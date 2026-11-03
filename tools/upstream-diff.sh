#!/usr/bin/env bash
# What upstream changed in the files this tree actually modified.
#
#   tools/upstream-diff.sh [TARGET] [--patch] [--exit-code]
#
# TARGET defaults to the newest release tag. The bare clone in .upstream/ is
# reused, and the comparison is limited to the files touched since the import,
# so upstream noise stays out of the report.
#
#   tools/upstream-diff.sh                 # newest tag, stat summary
#   tools/upstream-diff.sh main --patch    # the hunks, per touched file
#   tools/upstream-diff.sh --exit-code     # non-zero when the files moved

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache="$root/.upstream/shell.git"
pins="$root/upstream.json"

target=""
want_patch=0
want_exit=0

usage() {
    echo "usage: $(basename "$0") [TARGET] [--patch] [--exit-code]" >&2
}

for arg in "$@"; do
    case "$arg" in
    --patch) want_patch=1 ;;
    --exit-code) want_exit=1 ;;
    -h | --help) usage; exit 0 ;;
    -*) usage; exit 2 ;;
    *)
        [ -z "$target" ] || usage
        target=$arg
        ;;
    esac
done

command -v python3 >/dev/null || {
    echo "upstream-diff: python3 is required" >&2
    exit 2
}

read -r repo pin < <(python3 - "$pins" <<'PY'
import json, sys
entry = json.load(open(sys.argv[1]))["shell"]
print(entry["repo"], entry["pin"])
PY
)

[ -n "$repo" ] && [ -n "$pin" ] || {
    echo "upstream-diff: cannot read shell.repo/shell.pin from $pins" >&2
    exit 1
}

mkdir -p "$(dirname "$cache")"
if [ ! -d "$cache/objects" ]; then
    git clone --bare --quiet --filter=blob:none "$repo" "$cache" || exit 1
else
    git -C "$cache" fetch --quiet --tags --force origin '+refs/heads/*:refs/heads/*' ||
        echo "upstream-diff: fetch failed; using the cached tags" >&2
fi

if [ -z "$target" ]; then
    target=$(git -C "$cache" tag --sort=-v:refname | grep -E '^v?[0-9]+(\.[0-9]+)*$' | head -1)
fi
[ -n "$target" ] || {
    echo "upstream-diff: no tags in $cache" >&2
    exit 1
}
git -C "$cache" rev-parse --verify --quiet "$target^{commit}" >/dev/null || {
    echo "upstream-diff: unknown target: $target" >&2
    exit 1
}
git -C "$cache" rev-parse --verify --quiet "$pin^{commit}" >/dev/null || {
    echo "upstream-diff: unknown pin: $pin" >&2
    exit 1
}

import=$(git -C "$root" rev-list --max-parents=0 HEAD | head -1)
mapfile -t touched < <(git -C "$root" diff --name-only "$import" HEAD -- shell | sed 's|^shell/||')

if [ ${#touched[@]} -eq 0 ]; then
    echo "shell: no local changes against the import"
    exit 0
fi

changed=()
removed=()
for path in "${touched[@]}"; do
    if ! git -C "$cache" cat-file -e "$target:$path" 2>/dev/null; then
        # Only a removal when the file existed at our pin.
        git -C "$cache" cat-file -e "$pin:$path" 2>/dev/null && removed+=("$path")
        continue
    fi
    git -C "$cache" diff --quiet "$pin" "$target" -- "$path" && continue
    changed+=("$path")
done

printf 'shell: %s -> %s\n' "$pin" "$target"
printf '       %d files touched locally, %d changed upstream' "${#touched[@]}" "${#changed[@]}"
[ ${#removed[@]} -gt 0 ] && printf ', %d removed' "${#removed[@]}"
printf '\n'

if [ ${#changed[@]} -eq 0 ] && [ ${#removed[@]} -eq 0 ]; then
    echo "       nothing to absorb"
    exit 0
fi

if [ ${#changed[@]} -gt 0 ]; then
    printf '  changed upstream:\n'
    printf '    %s\n' "${changed[@]}"
fi
if [ ${#removed[@]} -gt 0 ]; then
    printf '  removed upstream:\n'
    printf '    %s\n' "${removed[@]}"
fi
echo

if [ ${#changed[@]} -gt 0 ]; then
    git -C "$cache" diff --stat "$pin" "$target" -- "${changed[@]}"
    echo

    commits=$(git -C "$cache" log --oneline --no-decorate "$pin..$target" -- "${changed[@]}" | head -20)
    if [ -n "$commits" ]; then
        echo "  commits touching those files:"
        printf '%s\n' "$commits" | sed 's/^/    /'
        echo
    fi

    if [ "$want_patch" -eq 1 ]; then
        git -C "$cache" diff "$pin" "$target" -- "${changed[@]}"
    fi
fi

if [ "$want_exit" -eq 1 ]; then
    exit 1
fi
