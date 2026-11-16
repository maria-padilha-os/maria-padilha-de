pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

Singleton {
    id: root

    readonly property bool enabled: GlobalConfig.clipboard.enabled
    readonly property int maxEntries: GlobalConfig.clipboard.maxEntries
    readonly property int privateWindowDelay: GlobalConfig.clipboard.privateWindowDelay
    readonly property int maxEntryBytes: GlobalConfig.clipboard.maxEntryBytes
    readonly property bool showIndicator: GlobalConfig.clipboard.showIndicator
    readonly property var denyClasses: GlobalConfig.clipboard.denyClasses
    readonly property var denyTitles: GlobalConfig.clipboard.denyTitles

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/padilha/clipboard`
    readonly property string helper: Quickshell.env("PADILHA_CLIPBOARD") || "padilha-clipboard"

    property bool paused: false
    property bool ready: false
    property string error: ""
    property list<var> entries: []

    readonly property bool recording: enabled && !paused && error === ""
    readonly property int count: entries.length

    function decodeHistory(raw: string): list<var> {
        const result = [];
        for (const line of raw.split("\n")) {
            if (!line)
                continue;
            const fields = line.split("\t");
            if (fields.length < 3)
                continue;
            let text = "";
            try {
                text = Qt.atob(fields[2]);
            } catch (e) {
                continue;
            }
            result.push({
                id: fields[0],
                time: Number(fields[1]) || 0,
                text: text
            });
        }
        return result.reverse();
    }

    function refresh(): void {
        historyView.reload();
        pausedView.reload();
    }

    function run(args: list<string>): void {
        commandProc.args = args;
        commandProc.running = true;
    }

    function pause(): void {
        paused = true;
        run(["--pause"]);
    }

    function resume(): void {
        paused = false;
        error = "";
        run(["--resume"]);
    }

    function togglePause(): void {
        if (paused)
            resume();
        else
            pause();
    }

    function clear(): void {
        entries = [];
        run(["--clear"]);
    }

    function removeEntry(id: string): void {
        run(["--remove", id]);
    }

    function copyEntry(id: string): void {
        run(["--copy", id]);
    }

    Component.onCompleted: refresh()

    Process {
        id: daemonProc

        running: root.enabled
        command: [
            root.helper,
            "--daemon",
            "--max", String(root.maxEntries),
            "--delay", String(root.privateWindowDelay),
            "--max-bytes", String(root.maxEntryBytes),
            "--deny-classes", (root.denyClasses ?? []).join(","),
            "--deny-titles", (root.denyTitles ?? []).join(",")
        ]

        stdout: StdioCollector {
            id: daemonOut
        }

        stderr: StdioCollector {
            id: daemonErr
        }

        onExited: code => {
            if (code === 0 || !root.enabled)
                return;
            root.error = daemonErr.text.trim() || Tr.tr("Clipboard history stopped unexpectedly");
            if (code !== 3)
                daemonRetry.restart();
        }
    }

    Timer {
        id: daemonRetry

        interval: 3000
        repeat: false
        onTriggered: {
            if (root.enabled)
                daemonProc.running = true;
        }
    }

    FileView {
        id: historyView

        path: `${root.stateDir}/history`
        watchChanges: true
        printErrors: false

        onLoaded: {
            root.entries = root.decodeHistory(text());
            root.ready = true;
        }

        onFileChanged: reload()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.entries = [];
                root.ready = true;
            }
        }
    }

    FileView {
        id: pausedView

        path: `${root.stateDir}/paused`
        watchChanges: true
        printErrors: false

        onLoaded: root.paused = true
        onFileChanged: reload()

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.paused = false;
        }
    }

    Process {
        id: commandProc

        property list<string> args

        command: [root.helper].concat(args ?? [])
        running: false

        stdout: StdioCollector {
            id: commandOut
        }

        stderr: StdioCollector {
            id: commandErr
        }

        onExited: code => {
            if (code === 0)
                root.error = "";
            else
                root.error = commandErr.text.trim() || Tr.tr("Clipboard action failed");
            root.refresh();
        }
    }

    // The marker files are watched, but a poll is the safety net for editors
    // and filesystems where the watch is still catching up. It is cheap: two
    // small reads, and only while the feature is enabled.
    Timer {
        interval: 1500
        repeat: true
        running: root.enabled
        onTriggered: root.refresh()
    }
}
