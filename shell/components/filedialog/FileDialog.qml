pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.I18n
import qs.components
import qs.services

LazyLoader {
    id: loader

    property list<string> cwd: ["Home"]
    property string filterLabel: Tr.tr("All files")
    property list<string> filters: ["*"]
    property string title: Tr.tr("Select a file")

    signal accepted(path: string)
    signal rejected

    function open(): void {
        activeAsync = true;
    }

    function close(): void {
        rejected();
    }

    onAccepted: activeAsync = false
    onRejected: activeAsync = false

    FloatingWindow {
        id: root

        objectName: "fileDialogWindow"

        property list<string> cwd: loader.cwd
        property string filterLabel: loader.filterLabel
        property list<string> filters: loader.filters

        readonly property bool selectionValid: {
            const file = folderContents.currentItem?.modelData;
            return (file && !file.isDir && (filters.includes("*") || filters.some(filter => filter.toLowerCase() === file.suffix.toLowerCase()))) ?? false;
        }

        function accepted(path: string): void {
            loader.accepted(path);
        }

        function rejected(): void {
            loader.rejected();
        }

        function focusSidebar(): void {
            sidebar.focusSelectedPlace();
        }

        function focusAddressBar(): void {
            header.focusAddressBar();
        }

        function focusContents(): void {
            folderContents.focusView();
        }

        function goUp(): void {
            header.goUp();
            folderContents.focusView();
        }

        implicitWidth: 1000
        implicitHeight: 600
        minimumSize.width: 400
        minimumSize.height: 300
        color: Colours.tPalette.m3surface
        surfaceFormat.opaque: false
        title: loader.title

        onVisibleChanged: {
            if (!visible)
                rejected();
        }

        // Keyboard routes to the two surfaces that a mouse otherwise owns.
        // The text fields keep normal typing because these are window-level
        // chords, not single letters.
        Shortcut {
            sequence: "Ctrl+L"
            context: Qt.WindowShortcut
            onActivated: root.focusAddressBar()
        }

        Shortcut {
            sequence: "Ctrl+B"
            context: Qt.WindowShortcut
            onActivated: root.focusSidebar()
        }

        Shortcut {
            sequence: "F6"
            context: Qt.WindowShortcut
            onActivated: root.focusContents()
        }

        Shortcut {
            sequence: "Alt+Up"
            context: Qt.WindowShortcut
            onActivated: root.goUp()
        }

        RowLayout {
            anchors.fill: parent

            spacing: 0

            Sidebar {
                id: sidebar

                Layout.fillHeight: true
                dialog: root
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 0

                HeaderBar {
                    id: header

                    Layout.fillWidth: true
                    dialog: root
                }

                FolderContents {
                    id: folderContents

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    dialog: root
                }

                DialogButtons {
                    Layout.fillWidth: true
                    dialog: root
                    folder: folderContents
                }
            }
        }

        Behavior on color {
            CAnim {}
        }
    }
}
