pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    readonly property string helper: Quickshell.env("PADILHA_RECORD") || "padilha-record"

    property int refCount: 0
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause
    property string error: ""

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        error = "";
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    function clearError(): void {
        error = "";
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int

        reloadableId: "recorder"
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "wf-recorder"]
        onExited: code => { // qmllint disable signal-handler-parameters
            const running = code === 0;

            if (running && root.needsStop) {
                commandProc.exec([root.helper, "--stop"]);
                props.running = false;
                props.paused = false;
            } else if (running && root.needsPause) {
                commandProc.exec([root.helper, "--pause"]);
                props.paused = !props.paused;
            } else if (!running && root.needsStart) {
                commandProc.exec([root.helper, "--start", ...root.startArgs]);
                props.running = true;
                props.paused = false;
                props.elapsed = 0;
            } else if (running !== props.running && !commandProc.running) {
                // The recording was started/stopped outside the shell (e.g. via
                // keybind), or our command finished without reaching the optimistic state
                props.running = running;
                props.paused = false;
                props.elapsed = 0;
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    Process {
        id: commandProc

        // The command owns the transition: `padilha-record` blocks on slurp for
        // region captures, waits for wf-recorder to finalise the file when
        // stopping, and prints a clear error when the tool is missing.
        stderr: StdioCollector {
            id: commandErr
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                root.error = commandErr.text.trim() || Tr.tr("Recorder action failed");
            else
                root.error = "";
            checkProc.running = true;
        }
    }

    // Only poll while something is showing the state, i.e. the utilities drawer is open
    Timer {
        interval: 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: checkProc.running = true
    }

    Connections {
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        enabled: props.running && !props.paused
        target: Time // qmllint disable incompatible-type
    }
}
