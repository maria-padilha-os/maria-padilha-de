pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.services

StyledRect {
    id: root

    objectName: "fileDialogSidebar"

    required property var dialog

    implicitWidth: Sizes.sidebarWidth
    implicitHeight: inner.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer

    function focusFirstPlace(): void {
        if (placeRepeater.count > 0)
            placeRepeater.itemAt(0).forceActiveFocus();
    }

    function focusSelectedPlace(): void {
        for (let i = 0; i < placeRepeater.count; i++) {
            const item = placeRepeater.itemAt(i);
            if (item && item.selected) {
                item.forceActiveFocus();
                return;
            }
        }
        root.focusFirstPlace();
    }

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.padding.extraSmall / 2
            Layout.bottomMargin: Tokens.spacing.medium
            text: Tr.trCtx("Files", "file dialog sidebar heading")
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.large.weight(Font.Bold).build()
        }

        Repeater {
            id: placeRepeater

            model: ["Home", "Downloads", "Desktop", "Documents", "Music", "Pictures", "Videos"]

            StyledRect {
                id: place

                objectName: "fileDialogSidebar" + modelData

                required property string modelData
                readonly property bool selected: modelData === root.dialog.cwd[root.dialog.cwd.length - 1]

                Layout.fillWidth: true
                implicitHeight: placeInner.implicitHeight + Tokens.padding.medium * 2

                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3secondaryContainer, selected ? 1 : 0)
                border.width: place.activeFocus ? 2 : 0
                border.color: Colours.palette.m3primary
                activeFocusOnTab: true

                function activate(): void {
                    if (place.modelData === "Home")
                        root.dialog.cwd = ["Home"];
                    else
                        root.dialog.cwd = ["Home", place.modelData];
                }

                Keys.onReturnPressed: place.activate()
                Keys.onSpacePressed: place.activate()

                StateLayer {
                    color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    onClicked: {
                        place.forceActiveFocus();
                        place.activate();
                    }
                }

                RowLayout {
                    id: placeInner

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large

                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: {
                            const p = place.modelData;
                            if (p === "Home")
                                return "home";
                            if (p === "Downloads")
                                return "file_download";
                            if (p === "Desktop")
                                return "desktop_windows";
                            if (p === "Documents")
                                return "description";
                            if (p === "Music")
                                return "music_note";
                            if (p === "Pictures")
                                return "image";
                            if (p === "Videos")
                                return "video_library";
                            return "folder";
                        }
                        color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.medium
                        fill: place.selected ? 1 : 0

                        Behavior on fill {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: place.modelData
                        color: place.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
