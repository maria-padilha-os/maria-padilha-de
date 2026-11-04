#!/bin/sh
# Switch the hyprsunset daemon on or off. Stopping the daemon (instead of
# calling `hyprctl hyprsunset identity`) makes "off" survive profile changes;
# the flag file makes it survive a relogin too.
set -eu

flag="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/nightlight-off"

running() {
    pgrep -x hyprsunset >/dev/null 2>&1
}

start() {
    rm -f "$flag"
    if ! running; then
        setsid hyprsunset >/dev/null 2>&1 &
    fi
}

stop() {
    mkdir -p "$(dirname "$flag")"
    : >"$flag"
    pkill -x hyprsunset >/dev/null 2>&1 || true
}

case "${1:-toggle}" in
    on | enable)
        start
        ;;
    off | disable)
        stop
        ;;
    toggle)
        if running; then
            stop
        else
            start
        fi
        ;;
    status)
        if running; then
            echo on
        else
            echo off
        fi
        ;;
    resume)
        [ -f "$flag" ] || start
        ;;
    *)
        echo "usage: $0 [on|off|toggle|status|resume]" >&2
        exit 2
        ;;
esac
