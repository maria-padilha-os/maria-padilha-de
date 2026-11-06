import QtQuick
import Quickshell

// Runs under `qs -p`: instantiate every extension tab with the same API shape
// the dashboard provides. `active` is false so tabs do not start network,
// audio or clipboard work while this test is running.
QtObject {
    id: harness

    readonly property var paths: (Quickshell.env("PADILHA_EXTENSION_TABS") || "").split("\n").filter(path => path.length > 0)
    readonly property var fakeApi: ({
            config: {},
            colours: null,
            brightness: null,
            hypr: null,
            paths: {
                home: Quickshell.env("HOME") || "/tmp",
                cache: Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME") || "/tmp"}/.cache`
            },
            extension: {}
        })

    property var loaded: []
    property int failures: 0
    property bool finished: false
    property Timer settleTimer: Timer {
        interval: 100
        onTriggered: harness.finish()
    }

    function finish(): void {
        if (harness.finished)
            return;
        harness.finished = true;
        for (const item of harness.loaded)
            item.destroy();
        harness.loaded = [];
        console.log(`loaded ${harness.paths.length - harness.failures} of ${harness.paths.length} extension tabs`);
        Qt.exit(harness.failures === 0 ? 0 : 1);
    }

    Component.onCompleted: {
        if (harness.paths.length === 0) {
            console.error("PADILHA_EXTENSION_TABS is empty");
            harness.failures++;
            harness.finish();
            return;
        }

        for (const path of harness.paths) {
            const component = Qt.createComponent("file://" + path, Component.PreferSynchronous);
            if (component.status !== Component.Ready) {
                console.error(`${path}: ${component.errorString()}`);
                harness.failures++;
                continue;
            }

            const api = Object.assign({}, harness.fakeApi, {
                extension: {
                    dirPath: path.replace(/\/Tab\.qml$/, "")
                }
            });

            let item = null;
            try {
                item = component.createObject(harness, {
                    api: api,
                    active: false
                });
            } catch (error) {
                console.error(`${path}: ${error}`);
            }

            if (!item) {
                console.error(`could not instantiate ${path}`);
                harness.failures++;
                continue;
            }

            item.active = false;
            harness.loaded = harness.loaded.concat([item]);
            console.log(`loaded ${path}`);
        }

        settleTimer.start();
    }
}
