import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    property bool opened: false

    readonly property bool enabled: GlobalConfig.clipboard.enabled

    function open(): void {
        // Opening while disabled is deliberate: the palette then explains how
        // to enable history instead of failing silently.
        opened = true;
    }

    function close(): void {
        opened = false;
    }

    function toggle(): void {
        if (opened)
            close();
        else
            open();
    }

    function status(): string {
        if (!enabled)
            return "disabled";
        if (ClipboardHistory.error)
            return `error: ${ClipboardHistory.error}`;
        if (ClipboardHistory.paused)
            return "paused";
        return "recording";
    }

    LazyLoader {
        id: loader

        active: root.opened

        ClipboardWindow {
            modelData: ShellState.forActive()?.modelData ?? Quickshell.screens[0]
            onCloseRequested: root.close()
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clipboard"
        description: "Toggle clipboard history"
        onPressed: root.toggle()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clipboardPause"
        description: "Pause or resume clipboard history"
        onPressed: ClipboardHistory.togglePause()
    }

    IpcHandler {
        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }

        function pause(): void {
            ClipboardHistory.pause();
        }

        function resume(): void {
            ClipboardHistory.resume();
        }

        function clear(): void {
            ClipboardHistory.clear();
        }

        function status(): string {
            return root.status();
        }

        target: "clipboard"
    }
}
