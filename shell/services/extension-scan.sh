#!/bin/sh
# Discover extension folders for the Settings catalog.
#
# Usage: extension-scan.sh USER_PADILHA USER_LILITH SHELL_DIR COMMANDS_PY \
#            INSTALLED_PADILHA INSTALLED_LILITH
#
# Priority: user config, then the checkout when the shell runs from one, then
# the installed copies. Duplicate real paths are scanned once. A checkout
# already ships the bundled extensions, so its installed copies are stale and
# are skipped instead of being reported as shadowed duplicates.

set -u

user_padilha=${1:-}
user_lilith=${2:-}
shell_dir=${3:-}
commands=${4:-}
installed_padilha=${5:-}
installed_lilith=${6:-}

resolved_shell=$(realpath "$shell_dir" 2>/dev/null) || resolved_shell=$shell_dir

checkout_extensions="$resolved_shell/../extensions"
checkout_share="$resolved_shell/../share/extensions"

bases="$user_padilha
$user_lilith"
if [ -d "$checkout_extensions" ] && [ -n "$(find "$checkout_extensions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)" ]; then
    bases="$bases
$checkout_extensions
$checkout_share"
else
    bases="$bases
$checkout_share
$installed_padilha
$installed_lilith"
fi

priority=0
seen=
printf '%s\n' "$bases" | while IFS= read -r base; do
    [ -n "$base" ] || continue
    [ -d "$base" ] || continue
    resolved=$(realpath "$base" 2>/dev/null) || continue
    if [ -n "$seen" ] && printf '%s\n' "$seen" | grep -Fxq -- "$resolved"; then
        continue
    fi
    seen="$seen
$resolved"
    priority=$((priority + 1))
    for extension in "$resolved"/*/; do
        [ -f "$extension/extension.json" ] || continue
        printf 'EXTENSION:%s\nPRIORITY:%s\nFILES:' "$extension" "$priority"
        find "$extension" -mindepth 1 -printf '%P\t' 2>/dev/null
        printf '\n'
        if command -v python3 >/dev/null 2>&1 && grep -q '"commands"' "$extension/extension.json" 2>/dev/null && output=$(python3 "$commands" "$extension/extension.json" 2>/dev/null); then
            printf 'COMMANDS:%s\n' "$output"
        else
            printf 'COMMANDS:?\n'
        fi
        cat "$extension/extension.json"
        printf '\n'
    done
done
