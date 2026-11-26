import QtQuick
import QtQuick.Window
import Quickshell

// Offscreen contract for the Files tab. It loads the real Tab.qml with a fake
// API, then exercises the keyboard table, the search/address focus switch and
// the active-focus hand-off without opening a file or touching the network.
Window {
    id: harness

    readonly property string tabPath: Quickshell.env("PADILHA_FILEMANAGER_TAB") || ""
    readonly property var palette: ({
            m3surface: "#141218",
            m3surfaceContainer: "#211F26",
            m3surfaceContainerLow: "#1D1B20",
            m3surfaceContainerHigh: "#2B2930",
            m3surfaceContainerHighest: "#36343B",
            m3onSurface: "#E6E0E9",
            m3onSurfaceVariant: "#CAC4D0",
            m3outline: "#938F99",
            m3outlineVariant: "#49454F",
            m3primary: "#D0BCFF",
            m3onPrimary: "#381E72",
            m3primaryContainer: "#4F378B",
            m3onPrimaryContainer: "#EADDFF",
            m3error: "#F2B8B5",
            m3errorContainer: "#8C1D18",
            m3onErrorContainer: "#F9DEDC"
        })

    property var item: null
    property int failures: 0
    property bool finished: false

    visible: true
    width: 1000
    height: 700
    color: harness.palette.m3surface

    function fakeApi(): var {
        return {
            config: {},
            colours: {
                palette: harness.palette
            },
            brightness: null,
            hypr: null,
            paths: {
                home: Quickshell.env("HOME") || "/tmp",
                cache: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") || "/tmp") + "/.cache")
            },
            extension: {}
        };
    }

    function fail(message: string): void {
        harness.failures++;
        console.error(`FAIL ${message}`);
    }

    function check(condition: bool, message: string): void {
        if (condition)
            console.log(`  ok   ${message}`);
        else
            harness.fail(message);
    }

    function findByName(object: var, name: string): var {
        if (!object)
            return null;
        if (object.objectName === name)
            return object;

        const children = object.children || [];
        for (let i = 0; i < children.length; i++) {
            const found = harness.findByName(children[i], name);
            if (found)
                return found;
        }
        return null;
    }

    function finish(): void {
        if (harness.finished)
            return;
        harness.finished = true;
        if (harness.item) {
            harness.item.destroy();
            harness.item = null;
        }
        console.log(`files keyboard checks: ${harness.failures} failures`);
        Qt.exit(harness.failures === 0 ? 0 : 1);
    }

    function runChecks(): void {
        const tab = harness.findByName(harness.contentItem, "fileManagerTab");
        if (!tab) {
            harness.fail("fileManagerTab exists");
            return harness.finish();
        }

        const widget = harness.findByName(tab, "fileManagerWidget");
        const list = harness.findByName(tab, "fileManagerList");
        const search = harness.findByName(tab, "fileManagerSearch");
        const address = harness.findByName(tab, "fileManagerAddressField");
        const toggle = harness.findByName(tab, "fileManagerVimToggle");
        const mode = harness.findByName(tab, "fileManagerMode");
        const modeLabel = harness.findByName(tab, "fileManagerModeLabel");
        const ring = harness.findByName(tab, "fileManagerFocusRing");

        if (!widget || !list || !search || !address || !toggle || !mode || !modeLabel || !ring) {
            harness.fail("all keyboard objectNames exist");
            return harness.finish();
        }
        harness.check(widget.count > 3, `folder listing has entries (${widget.count})`);
        harness.check(widget.vimEnabled === false, "Vim mode is off by default");
        harness.check(mode.visible === false, "mode indicator is hidden while Vim mode is off");
        harness.check(list.currentIndex === 0, "first row is selected on load");
        harness.check(list.activeFocus, "file list owns focus when the tab is active");
        harness.check(ring.visible, "file list shows a focus ring");

        // Existing navigation stays available.
        const start = list.currentIndex;
        widget.dispatchVim("j", false, false);
        harness.check(list.currentIndex === start, "Vim keys are inert while Vim mode is off");

        toggle.toggle();
        harness.check(widget.vimEnabled === true, "Vim toggle enables Vim mode");
        harness.check(mode.visible === true, "mode indicator is visible in Vim mode");
        harness.check(modeLabel.text === "NORMAL", "mode indicator reads NORMAL");
        harness.check(list.activeFocus, "Vim toggle returns focus to the file list");

        const first = list.currentIndex;
        harness.check(widget.dispatchVim("j", false, false), "j is consumed in Vim mode");
        harness.check(list.currentIndex === first + 1, "j moves down one row");
        harness.check(widget.dispatchVim("k", false, false), "k is consumed in Vim mode");
        harness.check(list.currentIndex === first, "k moves up one row");

        harness.check(widget.dispatchVim("G", false, true), "G is consumed in Vim mode");
        harness.check(list.currentIndex === widget.count - 1, "G selects the last row");
        harness.check(widget.dispatchVim("g", false, false), "first g starts the gg prefix");
        harness.check(widget.pendingKeys === "g", "gg prefix is pending");
        harness.check(widget.dispatchVim("g", false, false), "second g completes gg");
        harness.check(list.currentIndex === 0, "gg selects the first row");
        harness.check(widget.pendingKeys === "", "gg clears the prefix");

        widget.dispatchVim("G", false, true);
        harness.check(widget.dispatchVim("d", true, false), "Ctrl+d is consumed in Vim mode");
        harness.check(list.currentIndex > 0, "Ctrl+d pages down");
        harness.check(widget.dispatchVim("u", true, false), "Ctrl+u is consumed in Vim mode");

        // Search owns focus and normal typing; Vim must not see the keys.
        widget.openSearch();
        harness.check(search.activeFocus, "slash/search moves focus to the search box");
        harness.check(widget.textEditing, "search focus marks the text editor active");
        harness.check(modeLabel.text === widget.modeLabel && modeLabel.text.length > 0, "mode indicator reads SEARCH");
        const beforeSearchKeys = list.currentIndex;
        harness.check(widget.dispatchVim("j", false, false) === false, "j is ignored while search has focus");
        harness.check(list.currentIndex === beforeSearchKeys, "search focus does not move the list");
        search.text = "alpha";
        harness.check(widget.searchQuery === "alpha", "search receives normal typing");
        search.text = "";
        widget.clearSearch();
        harness.check(widget.searchActive === false && widget.searchQuery === "", "Esc/clear clears the search");
        harness.check(modeLabel.text === "NORMAL", "clearing search returns the indicator to NORMAL");
        harness.check(list.activeFocus, "clearing search returns focus to the file list");

        // Address bar owns focus in the same way.
        widget.focusAddressBar();
        harness.check(address.activeFocus, "Ctrl+L focuses the address bar");
        harness.check(widget.textEditing, "address focus marks the text editor active");
        harness.check(widget.dispatchVim("k", false, false) === false, "Vim keys are ignored in the address bar");
        widget.cancelAddressBar();
        harness.check(list.activeFocus, "leaving the address bar restores list focus");

        // Activating the tab again hands focus back to the list.
        widget.active = false;
        widget.active = true;
        harness.check(list.activeFocus, "reactivating the tab focuses the file list");

        harness.finish();
    }

    Timer {
        interval: 700
        running: harness.item !== null
        onTriggered: harness.runChecks()
    }

    Component.onCompleted: {
        if (harness.tabPath.length === 0) {
            console.error("PADILHA_FILEMANAGER_TAB is empty");
            harness.failures++;
            Qt.exit(1);
            return;
        }

        const component = Qt.createComponent("file://" + harness.tabPath, Component.PreferSynchronous);
        if (component.status !== Component.Ready) {
            console.error(`tab loads: ${component.errorString()}`);
            harness.failures++;
            Qt.exit(1);
            return;
        }

        harness.item = component.createObject(harness.contentItem, {
            api: harness.fakeApi(),
            active: false,
            width: 1000,
            height: 600
        });
        if (!harness.item) {
            console.error("tab could be instantiated");
            harness.failures++;
            Qt.exit(1);
            return;
        }

        harness.item.x = 0;
        harness.item.y = 0;
        harness.item.active = true;
        harness.requestActivate();
    }
}
