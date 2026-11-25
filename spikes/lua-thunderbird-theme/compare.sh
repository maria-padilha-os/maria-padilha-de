#!/usr/bin/env bash
# Compare the Lua Thunderbird renderer with the Python reference on fixtures.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
lua_theme="$root/bin/padilha-thunderbird-theme"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

refdir="$tmp/ref"
mkdir -p "$refdir/bin" "$refdir/share"
cp "$root/spikes/lua-thunderbird-theme/reference.py" "$refdir/bin/padilha-thunderbird-theme"
chmod +x "$refdir/bin/padilha-thunderbird-theme"
cp -r "$root/share/templates" "$refdir/share/"
python_theme="$refdir/bin/padilha-thunderbird-theme"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

setup_scheme() {
    local home=$1 mode=$2
    mkdir -p "$home/.local/state/caelestia"
    python3 - "$HOME/.local/state/caelestia/scheme.json" "$home/.local/state/caelestia/scheme.json" "$mode" <<'PY'
import json
import sys

source, destination, mode = sys.argv[1:4]
with open(source, encoding="utf-8") as handle:
    data = json.load(handle)
data["mode"] = mode
with open(destination, "w", encoding="utf-8") as handle:
    json.dump(data, handle)
PY
}

run_case() {
    local name=$1 mode=$2 kind=$3
    local home="$tmp/$name/home" xdg="$tmp/$name/home/.config"
    mkdir -p "$home" "$xdg/thunderbird"
    setup_scheme "$home" "$mode"

    local css=""
    if [ "$kind" = profile ]; then
        mkdir -p "$xdg/thunderbird/tb.default"
        {
            printf '[Profile0]\n'
            printf 'Name=default\n'
            printf 'IsRelative=1\n'
            printf 'Path=tb.default\n'
            printf 'Default=1\n'
        } >"$xdg/thunderbird/profiles.ini"
        css="$xdg/thunderbird/tb.default/chrome/padilha.css"
    elif [ "$kind" = install ]; then
        mkdir -p "$xdg/thunderbird/Profiles/abc.default"
        {
            printf '[Install4F96D1932A9F858E]\n'
            printf 'Default=Profiles/abc.default\n'
            printf '\n'
            printf '[Profile0]\n'
            printf 'Name=default\n'
            printf 'IsRelative=1\n'
            printf 'Path=Profiles/abc.default\n'
            printf 'Default=1\n'
        } >"$xdg/thunderbird/profiles.ini"
        css="$xdg/thunderbird/Profiles/abc.default/chrome/padilha.css"
    elif [ "$kind" = none ]; then
        HOME="$home" XDG_CONFIG_HOME="$xdg" "$python_theme"
        HOME="$home" XDG_CONFIG_HOME="$xdg" "$lua_theme"
        if find "$xdg/thunderbird" -name padilha.css -print -quit | grep -q .; then
            fail "$name: a profile was written without profiles.ini"
        fi
        printf 'ok   %s\n' "$name"
        return
    else
        fail "unknown fixture kind $kind"
    fi

    HOME="$home" XDG_CONFIG_HOME="$xdg" "$python_theme"
    [ -s "$css" ] || fail "$name: python did not write $css"
    cp "$css" "$tmp/$name.python.css"
    rm -f "$css"

    HOME="$home" XDG_CONFIG_HOME="$xdg" "$lua_theme"
    [ -s "$css" ] || fail "$name: lua did not write $css"
    if ! diff -u "$tmp/$name.python.css" "$css"; then
        fail "$name: output differs"
    fi
    printf 'ok   %s\n' "$name"
}

run_case light-profile light profile
run_case dark-profile dark profile
run_case light-install light install
run_case dark-install dark install
run_case none light none
printf 'all fixtures match the Python reference\n'
