pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

Singleton {
    id: root

    readonly property string helper: Quickshell.env("PADILHA_SHOT") || "padilha-shot"

    property bool busy: false
    property string lastPath: ""
    property string error: ""

    function capture(mode: string, copy: bool): void {
        if (busy)
            return;

        const args = [root.helper, "--mode", mode, "--print-path"];
        if (copy)
            args.push("--copy");

        error = "";
        busy = true;
        commandProc.command = args;
        commandProc.running = true;
    }

    function clearError(): void {
        error = "";
    }

    Process {
        id: commandProc

        running: false

        stdout: StdioCollector {
            id: commandOut
        }
        stderr: StdioCollector {
            id: commandErr
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            root.busy = false;
            if (code === 0) {
                const lines = commandOut.text.trim().split("\n").filter(line => line.length > 0);
                root.lastPath = lines.length > 0 ? lines[lines.length - 1] : "";
                root.error = "";
            } else {
                root.error = commandErr.text.trim() || Tr.tr("Screenshot failed");
            }
        }
    }
}
