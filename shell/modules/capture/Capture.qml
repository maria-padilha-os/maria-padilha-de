import QtQuick
import Quickshell
import Quickshell.Io
import qs.components.misc
import qs.services

Scope {
    id: root

    function openPanel(): void {
        const screenState = ShellState.forActive();
        if (screenState)
            screenState.utilities = true;
    }

    function takeScreenshot(mode: string, copy: bool): void {
        Screenshot.capture(mode, copy);
        root.openPanel();
    }

    function startRecording(mode: string): void {
        if (Recorder.running)
            return;
        Recorder.start(["--mode", mode]);
        root.openPanel();
    }

    function stopRecording(): void {
        if (Recorder.running)
            Recorder.stop();
    }

    function status(): string {
        if (!Recorder.running)
            return "idle";
        return Recorder.paused ? "paused" : "recording";
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "capturePanel"
        description: "Open the screenshot and recording panel"
        onPressed: root.openPanel()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "captureFull"
        description: "Screenshot the focused monitor"
        onPressed: root.takeScreenshot("full", false)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "captureWindow"
        description: "Screenshot the focused window"
        onPressed: root.takeScreenshot("window", false)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "captureRegion"
        description: "Screenshot a region"
        onPressed: root.takeScreenshot("region", false)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "captureRecord"
        description: "Start or stop a screen recording"
        onPressed: {
            if (Recorder.running)
                root.stopRecording();
            else
                root.startRecording("full");
        }
    }

    IpcHandler {
        function open(): void {
            root.openPanel();
        }

        function screenshot(mode: string): string {
            if (!["full", "window", "region"].includes(mode))
                return `unknown screenshot mode: ${mode}`;
            root.takeScreenshot(mode, false);
            return `screenshot ${mode}`;
        }

        function screenshotCopy(mode: string): string {
            if (!["full", "window", "region"].includes(mode))
                return `unknown screenshot mode: ${mode}`;
            root.takeScreenshot(mode, true);
            return `screenshot ${mode} (copy)`;
        }

        function record(mode: string): string {
            if (!["full", "window", "region"].includes(mode))
                return `unknown recording mode: ${mode}`;
            if (Recorder.running)
                return "already recording";
            root.startRecording(mode);
            return `recording ${mode}`;
        }

        function stop(): string {
            if (!Recorder.running)
                return "not recording";
            root.stopRecording();
            return "stopping";
        }

        function toggle(): string {
            if (Recorder.running) {
                root.stopRecording();
                return "stopping";
            }
            root.startRecording("full");
            return "recording full";
        }

        function status(): string {
            return root.status();
        }

        target: "capture"
    }
}
