import QtQuick
import Quickshell

// Runs under `qs -p`: instantiate every extension tab with the same API shape
// the dashboard provides. `active` is false so tabs do not start network,
// audio, service or timer work while this test is running.
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
        interval: 200
        onTriggered: harness.finish()
    }

    function checkMinimumSize(item, path): bool {
        const minimumWidth = Number(item.minimumWidth ?? 0);
        const minimumHeight = Number(item.minimumHeight ?? 0);
        if (minimumWidth <= 0 || minimumHeight <= 0)
            return true;

        // The dashboard sizes the tab from its implicit size. A minimum larger
        // than that would be clipped before the widget ever gets a chance to
        // lay itself out, so the two must agree.
        if (Number(item.implicitWidth) < minimumWidth || Number(item.implicitHeight) < minimumHeight) {
            console.error(`${path}: implicit size ${item.implicitWidth}x${item.implicitHeight} is smaller than minimum ${minimumWidth}x${minimumHeight}`);
            return false;
        }

        item.width = minimumWidth;
        item.height = minimumHeight;
        const widget = item.children.length > 0 ? item.children[0] : null;
        if (widget && (Math.round(widget.width) < minimumWidth || Math.round(widget.height) < minimumHeight)) {
            console.error(`${path}: content ${widget.width}x${widget.height} is clipped at minimum ${minimumWidth}x${minimumHeight}`);
            return false;
        }

        return true;
    }

    function finish(): void {
        if (harness.finished)
            return;
        harness.finished = true;

        for (const entry of harness.loaded) {
            if (!harness.checkMinimumSize(entry.item, entry.path))
                harness.failures++;
        }

        for (const entry of harness.loaded)
            entry.item.destroy();
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
            harness.loaded = harness.loaded.concat([{
                item: item,
                path: path
            }]);
            console.log(`loaded ${path}`);
        }

        settleTimer.start();
    }
}
