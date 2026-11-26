pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string voice: "pf_dora"
    property real speed: 0.85
    property string engine: ""
    property bool available: false
    property bool loaded: false

    readonly property var voiceOptions: [
        { id: "pf_dora", name: "Maria · Dora" },
    ]

    function refresh(): void {
        if (!configProcess.running)
            configProcess.running = true;
    }

    function setVoice(id: string): void {
        if (!id || id === root.voice)
            return;
        root.voice = id;
        Quickshell.execDetached(["padilha-voice", "set-voice", id]);
    }

    function setSpeed(value: real): void {
        const speed = Math.max(0.5, Math.min(1.5, value));
        if (Math.abs(speed - root.speed) < 0.001)
            return;
        root.speed = speed;
        Quickshell.execDetached(["padilha-voice", "set-speed", speed.toFixed(2)]);
    }

    Process {
        id: configProcess

        command: ["padilha-voice", "config"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    if (data.voice)
                        root.voice = data.voice;
                    if (typeof data.speed === "number")
                        root.speed = data.speed;
                    root.engine = data.engine || "";
                    root.available = !!data.voice_available;
                } catch (e) {
                    // The daemon may be unavailable while the package is being set up.
                }
            }
        }

        onExited: root.loaded = true
    }
}
