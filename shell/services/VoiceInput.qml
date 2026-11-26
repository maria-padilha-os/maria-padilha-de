pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property bool ready: false
    property bool listening: false
    property string transcript: ""
    property string error: ""

    function takeTranscript(): string {
        const value = root.transcript;
        root.transcript = "";
        return value;
    }

    Process {
        id: listener

        command: ["padilha-voice", "listen", "--events"]
        running: AssistantSettings.wakeEnabled

        stdout: SplitParser {
            onRead: line => {
                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return;
                }
                switch (event.event) {
                case "ready":
                    root.ready = true;
                    root.error = "";
                    break;
                case "wake":
                    root.listening = true;
                    root.transcript = "";
                    Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "drawers", "open", "assistant"]);
                    break;
                case "final":
                    root.listening = false;
                    root.transcript = event.text || "";
                    break;
                case "error":
                    root.listening = false;
                    root.error = event.message || "Wake-word listener failed";
                    break;
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0)
                    console.warn("padilha-voice listen:", line);
            }
        }

        onExited: {
            root.ready = false;
            root.listening = false;
        }
    }
}
