#!/usr/bin/env bash
# Localization contract: both catalogs cover every extracted string, preserve
# placeholders and plural forms, and stay compilable.

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)

echo "catalogs, placeholders and desktop locales"
if /usr/bin/python3 "$root/tests/localization/check.py" "$root"; then
    exit 0
fi
exit 1
