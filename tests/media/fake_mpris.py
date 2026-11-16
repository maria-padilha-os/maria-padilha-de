#!/usr/bin/env python3
"""A tiny, deterministic MPRIS 2 service for the media widget tests.

It owns org.mpris.MediaPlayer2.fakeplayer on the session bus and implements the
properties and methods the shell reads. There is no audio, no network and no
real player process: Play/Pause only flips a string, and Next/Previous change
the fake metadata. The service writes a JSON snapshot so the shell test can
assert the commands it received.
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import warnings
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

warnings.filterwarnings("ignore", category=DeprecationWarning)

BUS_NAME = "org.mpris.MediaPlayer2.fakeplayer"
OBJECT_PATH = "/org/mpris/MediaPlayer2"
ROOT_IFACE = "org.mpris.MediaPlayer2"
PLAYER_IFACE = "org.mpris.MediaPlayer2.Player"

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <method name="Raise"/>
    <method name="Quit"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek">
      <arg name="Offset" type="x" direction="in"/>
    </method>
    <method name="SetPosition">
      <arg name="TrackId" type="o" direction="in"/>
      <arg name="Position" type="x" direction="in"/>
    </method>
    <method name="OpenUri">
      <arg name="Uri" type="s" direction="in"/>
    </method>
    <signal name="Seeked">
      <arg name="Position" type="x"/>
    </signal>
  </interface>
</node>
"""


class FakeMpris:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.connection: Gio.DBusConnection | None = None
        self.identity = "Fake Player"
        self.playback_status = "Paused"
        self.loop_status = "None"
        self.rate = 1.0
        self.shuffle = False
        self.volume = 0.6
        self.position_us = 42 * 1_000_000
        self.length_us = 180 * 1_000_000
        self.track_index = 1
        self.calls: list[str] = []
        self.write_state()

    @property
    def title(self) -> str:
        return f"Fake Track {self.track_index}"

    @property
    def artist(self) -> str:
        return "Fake Artist"

    @property
    def album(self) -> str:
        return "Fake Album"

    def snapshot(self) -> dict:
        return {
            "identity": self.identity,
            "playbackStatus": self.playback_status,
            "title": self.title,
            "artist": self.artist,
            "album": self.album,
            "volume": round(self.volume, 6),
            "position": round(self.position_us / 1_000_000, 3),
            "calls": self.calls,
        }

    def write_state(self) -> None:
        if not self.args.state_file:
            return
        path = Path(self.args.state_file)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(json.dumps(self.snapshot(), indent=2) + "\n", encoding="utf-8")
        os.replace(temporary, path)

    def metadata(self) -> GLib.Variant:
        data = {
            "mpris:trackid": GLib.Variant("o", f"{OBJECT_PATH}/track/{self.track_index}"),
            "mpris:length": GLib.Variant("x", self.length_us),
            "xesam:title": GLib.Variant("s", self.title),
            "xesam:artist": GLib.Variant("as", [self.artist]),
            "xesam:album": GLib.Variant("s", self.album),
        }
        if self.args.art_url:
            data["mpris:artUrl"] = GLib.Variant("s", self.args.art_url)
        return GLib.Variant("a{sv}", data)

    def emit_changed(self, changed: dict[str, GLib.Variant]) -> None:
        assert self.connection is not None
        self.connection.emit_signal(
            None,
            OBJECT_PATH,
            "org.freedesktop.DBus.Properties",
            "PropertiesChanged",
            GLib.Variant("(sa{sv}as)", (PLAYER_IFACE, changed, [])),
        )

    def emit_seeked(self) -> None:
        assert self.connection is not None
        self.connection.emit_signal(
            None,
            OBJECT_PATH,
            PLAYER_IFACE,
            "Seeked",
            GLib.Variant("(x)", (int(self.position_us),)),
        )

    def set_playback(self, status: str) -> None:
        if self.playback_status == status:
            return
        self.playback_status = status
        self.emit_changed({"PlaybackStatus": GLib.Variant("s", self.playback_status)})
        self.write_state()

    def clamp_position(self, position_us: float) -> int:
        return int(max(0, min(self.length_us, position_us)))

    def next_track(self) -> None:
        self.track_index += 1
        self.position_us = 0
        self.emit_changed({"Metadata": self.metadata()})
        self.emit_seeked()
        self.write_state()

    def previous_track(self) -> None:
        self.track_index = max(1, self.track_index - 1)
        self.position_us = 0
        self.emit_changed({"Metadata": self.metadata()})
        self.emit_seeked()
        self.write_state()

    def handle_method(self, interface: str, method: str, params: GLib.Variant) -> None:
        self.calls.append(f"{interface}.{method}")
        args = params.unpack()

        if interface == ROOT_IFACE:
            # No real window or application to raise/quit.
            self.write_state()
            return

        if method == "PlayPause":
            self.set_playback("Paused" if self.playback_status == "Playing" else "Playing")
        elif method == "Play":
            self.set_playback("Playing")
        elif method == "Pause":
            self.set_playback("Paused")
        elif method == "Stop":
            self.position_us = 0
            self.set_playback("Stopped")
            self.emit_seeked()
        elif method == "Next":
            self.next_track()
        elif method == "Previous":
            self.previous_track()
        elif method == "Seek":
            self.position_us = self.clamp_position(self.position_us + int(args[0]))
            self.emit_seeked()
            self.write_state()
        elif method == "SetPosition":
            self.position_us = self.clamp_position(int(args[1]))
            self.emit_seeked()
            self.write_state()
        elif method == "OpenUri":
            self.write_state()
        else:
            self.write_state()

    def get_property(self, interface: str, name: str) -> GLib.Variant | None:
        if interface == ROOT_IFACE:
            values = {
                "Identity": GLib.Variant("s", self.identity),
                "DesktopEntry": GLib.Variant("s", "fake-player"),
                "SupportedUriSchemes": GLib.Variant("as", ["file", "http", "https"]),
                "SupportedMimeTypes": GLib.Variant("as", ["audio/mpeg"]),
                "CanQuit": GLib.Variant("b", False),
                "CanRaise": GLib.Variant("b", False),
                "HasTrackList": GLib.Variant("b", False),
            }
            return values.get(name)

        values = {
            "PlaybackStatus": GLib.Variant("s", self.playback_status),
            "LoopStatus": GLib.Variant("s", self.loop_status),
            "Rate": GLib.Variant("d", self.rate),
            "Shuffle": GLib.Variant("b", self.shuffle),
            "Metadata": self.metadata(),
            "Volume": GLib.Variant("d", self.volume),
            "Position": GLib.Variant("x", int(self.position_us)),
            "MinimumRate": GLib.Variant("d", 1.0),
            "MaximumRate": GLib.Variant("d", 1.0),
            "CanGoNext": GLib.Variant("b", True),
            "CanGoPrevious": GLib.Variant("b", True),
            "CanPlay": GLib.Variant("b", True),
            "CanPause": GLib.Variant("b", True),
            "CanSeek": GLib.Variant("b", True),
            "CanControl": GLib.Variant("b", True),
        }
        return values.get(name)

    def set_property(self, interface: str, name: str, value: GLib.Variant) -> bool:
        if interface != PLAYER_IFACE:
            return False
        self.calls.append(f"{interface}.Set.{name}")
        if name == "LoopStatus":
            self.loop_status = value.get_string()
        elif name == "Rate":
            self.rate = value.get_double()
        elif name == "Shuffle":
            self.shuffle = value.get_boolean()
        elif name == "Volume":
            self.volume = max(0.0, min(1.0, value.get_double()))
            self.emit_changed({"Volume": GLib.Variant("d", self.volume)})
        else:
            return False
        self.write_state()
        return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-file", default="", help="write a JSON snapshot after every change")
    parser.add_argument("--ready-file", default="", help="touch this file once the bus name is owned")
    parser.add_argument("--art-url", default="", help="optional mpris:artUrl value")
    args = parser.parse_args()

    fake = FakeMpris(args)
    loop = GLib.MainLoop()

    def on_bus_acquired(connection: Gio.DBusConnection, name: str) -> None:
        fake.connection = connection
        node = Gio.DBusNodeInfo.new_for_xml(XML)

        def on_method_call(
            conn: Gio.DBusConnection,
            sender: str,
            path: str,
            interface: str,
            method: str,
            params: GLib.Variant,
            invocation: Gio.DBusMethodInvocation,
        ) -> None:
            fake.handle_method(interface, method, params)
            invocation.return_value(None)

        for interface in node.interfaces:
            connection.register_object(
                OBJECT_PATH,
                interface,
                on_method_call,
                lambda conn, sender, path, iface, prop: fake.get_property(iface, prop),
                lambda conn, sender, path, iface, prop, value: fake.set_property(iface, prop, value),
            )
        fake.write_state()
        if args.ready_file:
            Path(args.ready_file).write_text("ready\n", encoding="utf-8")
        print("fake MPRIS service ready", flush=True)

    def stop(*_args: object) -> None:
        loop.quit()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    Gio.bus_own_name(
        Gio.BusType.SESSION,
        BUS_NAME,
        Gio.BusNameOwnerFlags.NONE,
        on_bus_acquired,
        None,
        None,
    )
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
