pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // The chosen width survives shell restarts. This is intentionally separate
    // from PersistentProperties, which only covers reloadable shell state.
    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/padilha/assistant-width"
    property real ratio: 0.4
    property bool loaded: false

    function clamp(value: var): real {
        const number = Number(value);
        if (!Number.isFinite(number))
            return 0.4;
        return Math.max(0.2, Math.min(0.8, number));
    }

    function read(): void {
        const value = clamp(file.text().trim());
        root.ratio = value;
        root.loaded = true;
    }

    function setRatio(value: real): void {
        const next = clamp(value);
        root.ratio = next;
        file.setText(next.toFixed(4) + "\n");
    }

    FileView {
        id: file

        path: root.path
        preload: true
        watchChanges: true
        atomicWrites: true

        onLoaded: root.read()
        onTextChanged: root.read()
        onFileChanged: root.read()
    }
}
