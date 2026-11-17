import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// Exercises the same value the Extensions service writes: the enabled ids in
// dashboard.extensionTabs. The test waits for the config debounce, reads the
// real shell.json, then disables one id and checks the file again. It runs with
// throwaway XDG directories, so it never touches the user's config.
Item {
    id: root

    readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") || ""}/padilha/shell.json`
    property int attempts: 0
    property bool enabledPhase: true

    function setEnabled(ids: var, id: string, enabled: bool): var {
        let current = Array.isArray(ids) ? ids.slice() : [];
        const index = current.indexOf(id);
        if (enabled && index === -1)
            current.push(id);
        else if (!enabled && index !== -1)
            current.splice(index, 1);
        return current;
    }

    function fail(message: string): void {
        console.error(`persistence: ${message}`);
        Qt.exit(1);
    }

    function has(text: string, id: string): bool {
        return text.indexOf(`"${id}"`) !== -1;
    }

    function check(text: string): void {
        if (root.enabledPhase) {
            if (root.has(text, "calculator") && root.has(text, "notes")) {
                let ids = [];
                try {
                    const data = JSON.parse(text);
                    ids = data?.dashboard?.extensionTabs ?? [];
                } catch (error) {
                    return root.fail(`shell.json is not valid JSON: ${error.message}`);
                }
                root.enabledPhase = false;
                root.attempts = 0;
                GlobalConfig.dashboard.extensionTabs = root.setEnabled(ids, "calculator", false);
                console.log("persistence: enable was written, disabling calculator");
                return;
            }
            if (root.attempts > 20)
                return root.fail("enabled ids were not written to shell.json");
            return;
        }

        if (!root.has(text, "calculator") && root.has(text, "notes")) {
            console.log("persistence: disable survived the reload");
            Qt.exit(0);
        }
        if (root.attempts > 20)
            root.fail("disabled id was not removed from shell.json");
    }

    Component.onCompleted: {
        // Let the config singleton finish loading before the first write, or
        // its initial file read can overwrite the test value.
        writeTimer.start();
    }

    Timer {
        id: writeTimer

        interval: 800
        onTriggered: {
            let ids = root.setEnabled([], "calculator", true);
            ids = root.setEnabled(ids, "notes", true);
            GlobalConfig.dashboard.extensionTabs = ids;
            console.log(`persistence: wrote ${JSON.stringify(ids)}`);
            readTimer.start();
        }
    }

    Timer {
        id: readTimer

        interval: 250
        repeat: true
        onTriggered: {
            root.attempts++;
            readProc.running = true;
        }
    }

    Process {
        id: readProc

        command: ["cat", root.configPath]

        stdout: StdioCollector {
            onStreamFinished: root.check(text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0 && root.attempts > 20)
                root.fail(`could not read ${root.configPath}`);
        }
    }
}
