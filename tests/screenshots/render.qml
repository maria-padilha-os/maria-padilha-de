import QtQuick
import QtQuick.Window
import Quickshell

// Renders the six widget tabs to PNG on an offscreen Qt platform. Nothing
// here reads the live session, clipboard, network, or terminal: the extension
// receives the same fake `api` shape the dashboard loader uses, `active` stays
// false, and filemanager browses a throwaway empty home.
Window {
    id: win

    readonly property string targetDir: Quickshell.env("PADILHA_SCREENSHOT_DIR") || ""
    readonly property string homeDir: Quickshell.env("PADILHA_SCREENSHOT_HOME") || "/tmp"
    readonly property bool useMinimum: Quickshell.env("PADILHA_SCREENSHOT_MIN") === "1"
    readonly property var defs: (Quickshell.env("PADILHA_SCREENSHOT_WIDGETS") || "").split("\n").filter(line => line.length > 0).map(line => {
        const separator = line.indexOf("|");
        return {
            id: line.slice(0, separator),
            path: line.slice(separator + 1)
        };
    })

    // A fixed Material dark palette keeps before/after captures comparable.
    readonly property var palette: ({
            m3surface: "#141218",
            m3surfaceContainerLow: "#1D1B20",
            m3surfaceContainer: "#211F26",
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
            m3secondary: "#CCC2DC",
            m3onSecondary: "#332D41",
            m3secondaryContainer: "#4A4458",
            m3tertiary: "#EFB8C8",
            m3onTertiary: "#492532",
            m3error: "#F2B8B5",
            m3onError: "#601410",
            m3errorContainer: "#8C1D18",
            m3onErrorContainer: "#F9DEDC"
        })

    property int index: -1
    property int failures: 0
    property var item: null
    property string currentId: ""

    width: 480
    height: 320
    visible: true
    color: win.palette.m3surface

    function apiFor(path: string): var {
        return {
            config: {},
            colours: {
                palette: win.palette
            },
            brightness: null,
            hypr: null,
            paths: {
                home: win.homeDir,
                cache: win.homeDir + "/.cache"
            },
            extension: {
                dirPath: path.slice(0, path.lastIndexOf("/"))
            }
        };
    }

    function next(): void {
        if (win.item) {
            win.item.destroy();
            win.item = null;
        }

        win.index += 1;
        if (win.index >= win.defs.length) {
            console.log(`rendered ${win.defs.length - win.failures} of ${win.defs.length} widget captures`);
            Qt.exit(win.failures === 0 ? 0 : 1);
            return;
        }

        const def = win.defs[win.index];
        win.currentId = def.id;
        const component = Qt.createComponent("file://" + def.path, Component.PreferSynchronous);
        if (component.status !== Component.Ready) {
            console.error(`${def.id}: ${component.errorString()}`);
            win.failures += 1;
            win.next();
            return;
        }

        const object = component.createObject(win.contentItem, {
            api: win.apiFor(def.path),
            active: false
        });
        if (!object) {
            console.error(`${def.id}: could not create tab`);
            win.failures += 1;
            win.next();
            return;
        }

        const margin = 16;
        const targetWidth = win.useMinimum && object.minimumWidth > 0 ? Math.ceil(object.minimumWidth) : Math.ceil(object.implicitWidth);
        const targetHeight = win.useMinimum && object.minimumHeight > 0 ? Math.ceil(object.minimumHeight) : Math.ceil(object.implicitHeight);
        win.width = targetWidth + margin * 2;
        win.height = targetHeight + margin * 2;
        object.x = margin;
        object.y = margin;
        object.width = targetWidth;
        object.height = targetHeight;
        win.item = object;

        settle.restart();
    }

    function capture(): void {
        if (!win.item)
            return;

        win.contentItem.grabToImage(result => {
            const path = `${win.targetDir}/${win.currentId}.png`;
            if (!result.saveToFile(path)) {
                console.error(`${win.currentId}: could not save ${path}`);
                win.failures += 1;
            } else {
                console.log(`${win.currentId}: ${path}`);
            }
            win.next();
        });
    }

    Rectangle {
        anchors.fill: parent
        color: win.palette.m3surface
    }

    Timer {
        id: settle

        interval: 320
        onTriggered: win.capture()
    }

    Component.onCompleted: win.next()
}
