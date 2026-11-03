#!/usr/bin/env bash
# What moved upstream since our pins.
#
#   upstream-watch.sh             table of pin vs latest tag
#   upstream-watch.sh --log       commits between our shell pin and the latest
#   upstream-watch.sh --exit-code non-zero when anything moved (for CI)
#
# Network: four `git ls-remote` calls, plus one bare clone the first time --log
# is used (cached in .upstream/, gitignored).

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
pins="$root/upstream.json"
cache="$root/.upstream"

want_log=0
want_exit=0

usage() { printf 'usage: %s [--log] [--exit-code]\n' "$(basename "$0")" >&2; }

for arg in "$@"; do
    case "$arg" in
        --log) want_log=1 ;;
        --exit-code) want_exit=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

# name<TAB>repo<TAB>pin, one line per project
read_pins() {
    python3 - "$pins" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
for name, entry in data.items():
    if not name.startswith("$"):
        print(f"{name}\t{entry['repo']}\t{entry.get('pin', '')}")
PY
}

# Newest release-looking tag, exactly as upstream names it (e.g. v2.5.0).
latest_tag() {
    timeout 25 git ls-remote --tags --refs "$1" 2>/dev/null |
        awk '{ sub("refs/tags/", "", $2); print $2 }' |
        grep -E '^v?[0-9]+(\.[0-9]+)*$' |
        sort -V |
        tail -1
}

normalise() { printf '%s' "${1#v}"; }

# Prints "1.2.3" style, so versions compare regardless of the v prefix.
compare() {
    local a b
    a=$(normalise "$1")
    b=$(normalise "$2")
    if [ "$a" = "$b" ]; then
        echo same
    elif [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$b" ]; then
        echo behind
    else
        echo ahead
    fi
}

printf '%-16s %-10s %-10s %s\n' upstream pin latest status
printf '%-16s %-10s %-10s %s\n' -------- --- ------ ------

moved=0
while IFS=$'\t' read -r name repo pin; do
    latest=$(latest_tag "$repo")

    if [ -z "$latest" ]; then
        printf '%-16s %-10s %-10s %s\n' "$name" "$pin" '?' 'unreachable'
        continue
    fi

    case "$(compare "$pin" "$latest")" in
        same) status=pinned ;;
        behind) status=behind; moved=1 ;;
        *) status=ahead ;;
    esac

    printf '%-16s %-10s %-10s %s\n' "$name" "$pin" "$latest" "$status"
done < <(read_pins)

if [ "$want_log" -eq 1 ]; then
    mapfile -t shell < <(python3 - "$pins" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    entry = json.load(fh)["shell"]
print(entry["repo"])
print(entry["pin"])
PY
)
    shell_repo=${shell[0]}
    shell_pin=${shell[1]}
    shell_latest=$(latest_tag "$shell_repo")

    echo
    if [ -z "$shell_latest" ] || [ "$(compare "$shell_pin" "$shell_latest")" != behind ]; then
        echo "shell: pinned at $shell_pin, nothing to read"
    else
        mkdir -p "$cache"
        if [ ! -d "$cache/shell.git/objects" ]; then
            git clone --bare --quiet --filter=blob:none "$shell_repo" "$cache/shell.git" ||
                { echo "shell: could not clone $shell_repo" >&2; exit 1; }
        else
            git -C "$cache/shell.git" fetch --quiet --tags --force origin
        fi

        count=$(git -C "$cache/shell.git" rev-list --count "$shell_pin..$shell_latest")
        echo "shell: $shell_pin..$shell_latest ($count commits)"
        git -C "$cache/shell.git" log --oneline --no-decorate "$shell_pin..$shell_latest" |
            sed 's/^/  /' |
            head -60
        [ "$count" -gt 60 ] && echo "  ... $((count - 60)) more"
    fi
fi

if [ "$want_exit" -eq 1 ] && [ "$moved" -eq 1 ]; then
    exit 1
fi
