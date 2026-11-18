pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "OutputLayout.js" as OutputLayout
import "ScreenModel.js" as ScreenModel

// Per-output panel layout.  The file is intentionally metadata-only: output
// geometry and the anchors/offsets of the bar, launcher, dashboard,
// notifications and wallpaper.  No screenshots, window titles, notification
// text, wallpaper pixels or other screen contents are ever written.
Singleton {
    id: root

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
    readonly property string stateDir: `${root.stateHome}/padilha`
    readonly property string path: Quickshell.env("PADILHA_PANEL_LAYOUT") || `${root.stateDir}/panel-layout.json`

    property var state: OutputLayout.emptyState()
    property bool loaded
    property bool pendingSave
    property var pendingScreens: []

    readonly property var outputs: root.state.outputs

    function forScreen(screen: var): var {
        return OutputLayout.restore(root.state, screen);
    }

    function placement(screen: var, panel: string): var {
        return OutputLayout.position(root.state, screen, panel);
    }

    function setPosition(screen: var, panel: string, position: var): void {
        root.state = OutputLayout.setPosition(root.state, screen, panel, position);
        root.queueSave();
    }

    function forget(screen: var): void {
        root.state = OutputLayout.forget(root.state, screen);
        root.queueSave();
    }

    function targetForName(name: string): var {
        return {
            key: name,
            name: name
        };
    }

    // Called when the ScreenModel changes.  Offline outputs stay in the file so
    // reconnecting a monitor restores its panel anchors; only the online
    // geometry is refreshed.
    function reconcile(screens: var): void {
        if (!root.loaded) {
            root.pendingScreens = screens;
            return;
        }

        const next = OutputLayout.reconcile(root.state, ScreenModel.snapshot(screens), Date.now());
        if (JSON.stringify(next) !== JSON.stringify(root.state)) {
            root.state = next;
            root.queueSave();
        }
    }

    function queueSave(): void {
        if (!root.loaded)
            return;
        root.pendingSave = true;
        if (!ensureDir.running)
            ensureDir.running = true;
    }

    function readState(source: string): var {
        try {
            const parsed = JSON.parse(source || "{}");
            return OutputLayout.sanitise(parsed);
        } catch (error) {
            console.warn(`panel-layout: ignoring unreadable state: ${error}`);
            return OutputLayout.emptyState();
        }
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        watchChanges: false

        onLoaded: {
            root.state = root.readState(file.text());
            root.loaded = true;
            const pending = root.pendingScreens;
            root.pendingScreens = [];
            if (pending.length > 0)
                root.reconcile(pending);
        }

        onLoadFailed: {
            root.loaded = true;
            const pending = root.pendingScreens;
            root.pendingScreens = [];
            if (pending.length > 0)
                root.reconcile(pending);
        }
    }

    Process {
        id: ensureDir

        command: ["mkdir", "-p", root.stateDir]

        onExited: {
            if (!root.pendingSave)
                return;
            root.pendingSave = false;
            file.setText(`${JSON.stringify(root.state, null, 2)}\n`);
        }
    }

    IpcHandler {
        function list(): string {
            return JSON.stringify(root.state.outputs, null, 2);
        }

        function setPosition(output: string, panel: string, position: string): string {
            let parsed;
            try {
                parsed = JSON.parse(position);
            } catch (error) {
                // A bare edge/anchor is convenient from a shell.
                parsed = panel === "bar" ? {
                    edge: position
                } : {
                    anchor: position
                };
            }

            const target = root.targetForName(output);
            root.setPosition(target, panel, parsed);
            return JSON.stringify(root.placement(target, panel));
        }

        function forget(output: string): void {
            root.forget(root.targetForName(output));
        }

        target: "screens"
    }
}
