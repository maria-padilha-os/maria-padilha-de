#!/usr/bin/env bash
# Run every contract test the project has. One entry point for CI and for the
# "did I break the desktop?" question before a commit.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
suites=(
    "$root/tests/run.sh"
    "$root/tests/theme/run.sh"
)
for extra in "$root"/tests/cli/*.sh; do
    [ -f "$extra" ] && suites+=("$extra")
done

failed=()
for suite in "${suites[@]}"; do
    name=${suite#"$root"/}
    printf '\n== %s\n' "$name"
    if ! "$suite"; then
        failed+=("$name")
    fi
done

printf '\n'
if [ ${#failed[@]} -eq 0 ]; then
    printf 'all suites passed\n'
    exit 0
fi
printf 'failed: %s\n' "${failed[*]}"
exit 1
