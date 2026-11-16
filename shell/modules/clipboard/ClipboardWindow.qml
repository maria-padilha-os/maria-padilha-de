pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

StyledWindow {
    id: root

    required property ShellScreen modelData

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var filtered: {
        const all = ClipboardHistory.entries ?? [];
        if (!query)
            return all;
        return all.filter(entry => entry.text.toLowerCase().includes(query));
    }
    readonly property bool empty: filtered.length === 0
    readonly property bool disabled: !ClipboardHistory.enabled
    readonly property int minimumWidth: 420
    readonly property int minimumHeight: 360
    readonly property string stateLabel: {
        if (disabled)
            return Tr.tr("Off");
        if (ClipboardHistory.error)
            return Tr.tr("Unavailable");
        if (ClipboardHistory.paused)
            return Tr.tr("Paused");
        return Tr.tr("Recording");
    }
    readonly property color stateColour: {
        if (disabled || ClipboardHistory.paused)
            return Colours.palette.m3outline;
        if (ClipboardHistory.error)
            return Colours.palette.m3error;
        return Colours.palette.m3primary;
    }

    property bool confirmClear

    signal closeRequested

    function moveSelection(delta: int): void {
        if (root.filtered.length === 0)
            return;
        let next = list.currentIndex + delta;
        next = Math.max(0, Math.min(root.filtered.length - 1, next));
        list.currentIndex = next;
        list.positionViewAtIndex(next, ListView.Contain);
    }

    function copyCurrent(): void {
        const entry = root.filtered[list.currentIndex];
        if (!entry)
            return;
        ClipboardHistory.copyEntry(entry.id);
        root.closeRequested();
    }

    function removeCurrent(): void {
        const entry = root.filtered[list.currentIndex];
        if (!entry)
            return;
        ClipboardHistory.removeEntry(entry.id);
        Qt.callLater(() => {
            list.currentIndex = Math.min(list.currentIndex, root.filtered.length - 1);
        });
    }

    name: "clipboard"
    screen: modelData
    color: "transparent"
    objectName: "clipboardWindow"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    focus: true

    Keys.onEscapePressed: closeRequested()

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.45

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    StyledRect {
        id: panel

        objectName: "clipboardPanel"
        anchors.centerIn: parent
        width: Math.max(minimumWidth, Math.min(720, parent.width - Tokens.padding.extraLarge * 2))
        height: Math.max(minimumHeight, Math.min(640, parent.height - Tokens.padding.extraLarge * 2))
        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Tokens.rounding.extraLarge
        clip: true

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "content_paste"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.large.build()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Tr.tr("Clipboard history")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.medium
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: Tr.tr("Private entries are never stored")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        Layout.fillWidth: true
                    }
                }

                StyledRect {
                    id: statusPill

                    objectName: "clipboardStatus"
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: statusRow.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: statusRow.implicitHeight + Tokens.padding.small * 2
                    color: Qt.alpha(root.stateColour, 0.12)
                    radius: Tokens.rounding.full

                    RowLayout {
                        id: statusRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        Rectangle {
                            implicitWidth: Tokens.padding.extraSmall
                            implicitHeight: Tokens.padding.extraSmall
                            radius: Tokens.rounding.full
                            color: root.stateColour
                        }

                        StyledText {
                            text: root.stateLabel
                            color: root.stateColour
                            font: Tokens.font.label.small
                        }
                    }

                    Accessible.name: root.stateLabel
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                SearchBar {
                    id: search

                    Layout.fillWidth: true
                    objectName: "clipboardSearch"
                    placeholderText: Tr.tr("Search clipboard history")
                    enabled: !root.disabled

                    onAccepted: root.copyCurrent()
                    onTextChanged: Qt.callLater(() => {
                        list.currentIndex = root.filtered.length > 0 ? 0 : -1;
                    })

                    Keys.onUpPressed: root.moveSelection(-1)
                    Keys.onDownPressed: root.moveSelection(1)
                    Keys.onEscapePressed: root.closeRequested()
                    Keys.onDeletePressed: root.removeCurrent()

                    Component.onCompleted: forceActiveFocus()
                }

                IconTextButton {
                    objectName: "clipboardPause"

                    icon: ClipboardHistory.paused ? "play_arrow" : "pause"
                    text: ClipboardHistory.paused ? Tr.tr("Resume history") : Tr.tr("Pause history")
                    disabled: root.disabled
                    onClicked: ClipboardHistory.togglePause()

                    Accessible.role: Accessible.Button
                    Accessible.name: text
                }

                IconTextButton {
                    objectName: "clipboardClear"

                    icon: "delete_sweep"
                    text: root.confirmClear ? Tr.tr("Confirm clear") : Tr.tr("Clear all")
                    disabled: root.disabled || ClipboardHistory.count === 0
                    onClicked: {
                        if (root.confirmClear) {
                            root.confirmClear = false;
                            ClipboardHistory.clear();
                        } else {
                            root.confirmClear = true;
                            clearConfirm.restart();
                        }
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: text
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StyledListView {
                    id: list

                    objectName: "clipboardList"
                    anchors.fill: parent
                    visible: !root.empty && !root.disabled
                    clip: true
                    spacing: Tokens.spacing.extraSmall
                    currentIndex: -1
                    model: root.filtered

                    onCountChanged: {
                        if (currentIndex < 0 && count > 0)
                            currentIndex = 0;
                        else if (currentIndex >= count)
                            currentIndex = count > 0 ? count - 1 : -1;
                    }

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: list
                    }

                    delegate: Rectangle {
                        id: entryRow

                        required property int index
                        required property var modelData

                        readonly property bool current: ListView.isCurrentItem
                        readonly property bool hovered: hover.containsMouse

                        width: list.width
                        implicitHeight: rowContent.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.medium
                        color: current ? Colours.palette.m3secondaryContainer : hovered ? Colours.tPalette.m3surfaceContainerHighest : "transparent"

                        Behavior on color {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                list.currentIndex = entryRow.index;
                                root.copyCurrent();
                            }
                        }

                        RowLayout {
                            id: rowContent

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                Layout.alignment: Qt.AlignTop
                                text: "content_paste"
                                color: entryRow.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.builders.small.build()
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: (entryRow.modelData.text ?? "").replace(/\s+/g, " ").trim() || Tr.tr("Empty entry")
                                    color: entryRow.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Qt.formatDateTime(new Date((entryRow.modelData.time ?? 0) * 1000), "HH:mm")
                                    color: entryRow.current ? Qt.alpha(Colours.palette.m3onSecondaryContainer, 0.75) : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: emptyState

                    objectName: "clipboardEmpty"
                    anchors.centerIn: parent
                    width: Math.min(parent.width, 420)
                    spacing: Tokens.spacing.medium
                    visible: root.empty || root.disabled

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (root.disabled)
                                return "content_paste_off";
                            if (ClipboardHistory.error)
                                return "error";
                            if (ClipboardHistory.paused)
                                return "pause_circle";
                            return "content_paste";
                        }
                        color: root.disabled || ClipboardHistory.paused ? Colours.palette.m3outline : ClipboardHistory.error ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.builders.extraLarge.build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            if (root.disabled)
                                return Tr.tr("Clipboard history is off");
                            if (ClipboardHistory.error)
                                return Tr.tr("Clipboard history is unavailable");
                            if (ClipboardHistory.paused)
                                return Tr.tr("History is paused");
                            if (root.query)
                                return Tr.tr("No matching entries");
                            return Tr.tr("No clipboard history yet");
                        }
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            if (root.disabled)
                                return Tr.tr("Enable clipboard.enabled in ~/.config/padilha/init.lua, then reload the shell.");
                            if (ClipboardHistory.error)
                                return ClipboardHistory.error;
                            if (ClipboardHistory.paused)
                                return Tr.tr("Resume history to start recording again.");
                            if (root.query)
                                return Tr.tr("Try a different search.");
                            return Tr.tr("Copy something and it will show up here.");
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: ClipboardHistory.error && !root.disabled ? ClipboardHistory.error : Tr.tr("↑↓ select · Enter copy · Delete remove · Esc close")
                    color: ClipboardHistory.error && !root.disabled ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                StyledText {
                    text: Tr.tr("%1 entries").arg(ClipboardHistory.count)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    Timer {
        id: clearConfirm

        interval: 4000
        onTriggered: root.confirmClear = false
    }
}
