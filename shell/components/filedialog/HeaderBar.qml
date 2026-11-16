pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    objectName: "fileDialogHeaderBar"

    required property var dialog

    implicitWidth: inner.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: inner.implicitHeight + Tokens.padding.medium * 2

    color: Colours.tPalette.m3surfaceContainer

    function focusAddressBar(): void {
        if (folderRepeater.count > 0)
            folderRepeater.itemAt(folderRepeater.count - 1).forceActiveFocus();
        else
            addressBar.forceActiveFocus();
    }

    function goUp(): void {
        if (root.dialog.cwd.length > 1)
            root.dialog.cwd.pop();
    }

    RowLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        StyledRect {
            objectName: "fileDialogUp"

            implicitWidth: implicitHeight
            implicitHeight: upIcon.implicitHeight + Tokens.padding.small
            radius: Tokens.rounding.medium
            color: "transparent"
            border.width: activeFocus ? 2 : 0
            border.color: Colours.palette.m3primary
            activeFocusOnTab: true
            enabled: root.dialog.cwd.length > 1

            Keys.onReturnPressed: root.goUp()
            Keys.onSpacePressed: root.goUp()

            StateLayer {
                radius: Tokens.rounding.medium
                disabled: root.dialog.cwd.length === 1
                onClicked: {
                    parent.forceActiveFocus();
                    root.goUp();
                }
            }

            MaterialIcon {
                id: upIcon

                anchors.centerIn: parent
                text: "drive_folder_upload"
                color: root.dialog.cwd.length === 1 ? Colours.palette.m3outline : Colours.palette.m3onSurface
                grade: 200
            }
        }

        StyledRect {
            id: addressBar

            objectName: "fileDialogAddressBar"

            Layout.fillWidth: true

            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHigh
            border.width: addressBar.activeFocus ? 2 : 0
            border.color: Colours.palette.m3primary
            activeFocusOnTab: true

            implicitHeight: pathComponents.implicitHeight + pathComponents.anchors.margins * 2

            Keys.onReturnPressed: root.focusAddressBar()
            Keys.onSpacePressed: root.focusAddressBar()

            RowLayout {
                id: pathComponents

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall / 2
                anchors.leftMargin: 0

                spacing: Tokens.spacing.small

                Repeater {
                    id: folderRepeater

                    model: root.dialog.cwd

                    RowLayout {
                        id: folder

                        required property string modelData
                        required property int index

                        spacing: 0

                        Loader {
                            asynchronous: true
                            Layout.rightMargin: Tokens.spacing.small
                            active: folder.index > 0
                            sourceComponent: StyledText {
                                text: "/"
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.builders.small.weight(Font.Bold).build()
                            }
                        }

                        StyledRect {
                            id: crumb

                            objectName: "fileDialogCrumb" + folder.index

                            implicitWidth: homeIcon.implicitWidth + (homeIcon.active ? Tokens.padding.extraSmall : 0) + folderName.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: folderName.implicitHeight + Tokens.padding.small
                            radius: Tokens.rounding.medium
                            color: "transparent"
                            border.width: crumb.activeFocus ? 2 : 0
                            border.color: Colours.palette.m3primary
                            activeFocusOnTab: true

                            function activate(): void {
                                root.dialog.cwd = root.dialog.cwd.slice(0, folder.index + 1);
                            }

                            Keys.onReturnPressed: activate()
                            Keys.onSpacePressed: activate()
                            Keys.onLeftPressed: (event) => {
                                if (folder.index > 0)
                                    folderRepeater.itemAt(folder.index - 1).forceActiveFocus();
                                event.accepted = true;
                            }
                            Keys.onRightPressed: (event) => {
                                if (folder.index < folderRepeater.count - 1)
                                    folderRepeater.itemAt(folder.index + 1).forceActiveFocus();
                                event.accepted = true;
                            }

                            Loader {
                                asynchronous: true
                                anchors.fill: parent
                                active: folder.index < root.dialog.cwd.length - 1
                                sourceComponent: StateLayer {
                                    onClicked: {
                                        crumb.forceActiveFocus();
                                        crumb.activate();
                                    }

                                    radius: Tokens.rounding.medium
                                }
                            }

                            Loader {
                                id: homeIcon

                                asynchronous: true

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Tokens.padding.medium

                                active: folder.index === 0 && folder.modelData === "Home"
                                sourceComponent: MaterialIcon {
                                    text: "home"
                                    color: root.dialog.cwd.length === 1 ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                                    fill: 1
                                }
                            }

                            StyledText {
                                id: folderName

                                anchors.left: homeIcon.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: homeIcon.active ? Tokens.padding.extraSmall : 0

                                text: folder.modelData
                                color: folder.index < root.dialog.cwd.length - 1 ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                                font: Tokens.font.body.builders.small.weight(Font.Bold).build()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
