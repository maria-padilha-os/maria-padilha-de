#!/usr/bin/env python3
"""Static contract checks for the MPRIS media widget.

The runtime checks live in run.sh; these assertions keep the promises that are
easy to regress without a session bus: no autoplay, no media discovery, a
palette-owned empty state and artwork fallback, all transport controls, and
the bar/popout wiring.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SHELL = ROOT / "shell"
POPOUT = SHELL / "modules" / "bar" / "popouts" / "Media.qml"
BAR_WIDGET = SHELL / "modules" / "bar" / "components" / "Media.qml"
ARTWORK = SHELL / "components" / "widgets" / "MediaArtwork.qml"
PLAYERS = SHELL / "services" / "Players.qml"
INFO = SHELL / "services" / "MediaInfo.js"
DASHBOARD_MEDIA = SHELL / "modules" / "dashboard" / "media" / "Details.qml"

HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")
NAMED = re.compile(r'"(?:white|black|red|green|blue|gray|grey|lightgray|darkgray)"', re.IGNORECASE)

failures: list[str] = []
checks = 0


def ok(message: str) -> None:
    global checks
    checks += 1
    print(f"  ok   {message}")


def bad(message: str, detail: str = "") -> None:
    global checks
    checks += 1
    failures.append(message)
    print(f"  FAIL {message}")
    if detail:
        print(f"       {detail}")


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        bad(f"{path.relative_to(ROOT)} is readable", str(error))
        return ""


def require(path: Path, label: str, markers: tuple[str, ...]) -> None:
    source = read(path)
    for marker in markers:
        if marker in source:
            ok(f"{label} keeps {marker!r}")
        else:
            bad(f"{label} keeps {marker!r}")


def main() -> int:
    for path in (POPOUT, BAR_WIDGET, ARTWORK, PLAYERS, INFO):
        if path.is_file():
            ok(f"{path.relative_to(ROOT)} exists")
        else:
            bad(f"{path.relative_to(ROOT)} exists")

    require(PLAYERS, "Players.qml", (
        "Mpris.players.values",
        "MediaInfo.artUrl",
        "function getArtUrl(",
        "function formatTime(",
        "function canSeek(",
        "function seekTarget(",
        "function setVolume(",
        "function actionForKey(",
        "function perform(",
        'name: "mediaToggle"',
        'name: "mediaPrev"',
        'name: "mediaNext"',
        'name: "mediaSeekBackward"',
        'name: "mediaSeekForward"',
        'name: "mediaVolumeUp"',
        'name: "mediaVolumeDown"',
        "function getTrackAlbum(",
    ))

    require(INFO, "MediaInfo.js", (
        "function artUrl(",
        "function normaliseArtUrl(",
        "function trackTitle(",
        "function trackArtist(",
        "function trackAlbum(",
        "function formatTime(",
        "function canSeek(",
        "function seekTarget(",
        "function canSetVolume(",
        "function actionForKey(",
        "javascript:",
        "file:",
        "https:",
    ))

    require(POPOUT, "Media.qml", (
        "Players.active",
        "Players.getTrackTitle",
        "Players.getTrackArtist",
        "Players.getTrackAlbum",
        "Players.canSeek",
        "Players.seekTarget",
        "Players.canSetVolume",
        "Players.setVolume",
        "Players.actionForKey",
        "Keys.onPressed",
        "forceActiveFocus",
        "Nothing playing",
        "Start playback in a media app",
        "MediaArtwork",
    ))

    require(BAR_WIDGET, "bar/components/Media.qml", (
        "Players.active",
        "MediaArtwork",
        "Players.progress",
        "music_off",
    ))

    require(ARTWORK, "MediaArtwork.qml", (
        "Players.getArtUrl(player)",
        "Image.Error",
        "music_note",
        "Colours.palette",
        "Colours.layer",
    ))

    require(DASHBOARD_MEDIA, "dashboard media Details.qml", (
        "trackAlbum",
        "Players.getVolume",
        "Players.setVolume",
        "volumeSupported",
    ))

    bar = read(SHELL / "modules" / "bar" / "Bar.qml")
    if 'roleValue: "media"' in bar and '"taskbarMedia"' in bar:
        ok("Bar.qml routes the media entry")
    else:
        bad("Bar.qml routes the media entry")

    bar_widget = read(BAR_WIDGET)
    if 'popouts.currentName = "media"' in bar_widget:
        ok("the compact bar item opens the media popout")
    else:
        bad("the compact bar item opens the media popout")

    content = read(SHELL / "modules" / "bar" / "popouts" / "Content.qml")
    if 'name: "media"' in content:
        ok("Content.qml registers the media popout")
    else:
        bad("Content.qml registers the media popout")

    schema = read(SHELL / "plugin" / "src" / "Caelestia" / "Config" / "barconfig.hpp")
    if "LIST_ENTRY(media, true)" in schema:
        ok("bar defaults include the media item")
    else:
        bad("bar defaults include the media item")

    media_sources = "\n".join(read(path) for path in (POPOUT, BAR_WIDGET, ARTWORK, PLAYERS, INFO))

    # Opening the widget must not start playback. The only play calls in the
    # service are explicit IPC/shortcut actions; the popout and bar never call
    # play on creation or on a timer.
    widget_sources = "\n".join(read(path) for path in (POPOUT, BAR_WIDGET, ARTWORK))
    if re.search(r"\.play\s*\(", widget_sources):
        bad("opening the widget never autoplays")
    else:
        ok("opening the widget never autoplays")

    # Media discovery is the MPRIS service's job. Do not shell out to
    # playerctl/pgrep or scan processes from the widget.
    discovery = re.compile(r"\b(playerctl|pgrep|pidof|dbus-send|Process\s*\{)", re.IGNORECASE)
    match = discovery.search(media_sources)
    if match:
        bad("the widget has no background media discovery", match.group(0))
    else:
        ok("the widget has no background media discovery")

    for label, source in (("media widget QML", widget_sources), ("service/helper", read(PLAYERS) + read(INFO))):
        raw = HEX.findall(source)
        named = NAMED.findall(source)
        if raw or named:
            bad(f"{label} follows the active palette", ", ".join(raw + named))
        else:
            ok(f"{label} follows the active palette")

    if "Component.onCompleted" in read(POPOUT) and "forceActiveFocus" in read(POPOUT):
        ok("the popout takes keyboard focus when it opens")
    else:
        bad("the popout takes keyboard focus when it opens")

    print(f"\n{checks} checks, {len(failures)} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
