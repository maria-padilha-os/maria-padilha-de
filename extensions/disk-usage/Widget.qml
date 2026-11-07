import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services

// Read-only disk overview. Storage already collects the mounted physical
// filesystems (and dedupes multiple mounts of the same device), so opening the
// tab does not walk the home directory or spawn a polling process.
Item {
    id: root

    property var api
    property bool active: true
    property bool compact: false

    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null
    readonly property color foreground: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color muted: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color accent: root.palette ? root.palette.m3primary : "transparent"
    readonly property color secondary: root.palette ? root.palette.m3secondary : "transparent"
    readonly property color surfaceHigh: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"
    readonly property color outline: root.palette ? root.palette.m3outlineVariant : "transparent"

    readonly property real contentWidth: Math.min(Math.max(300, root.width - (root.compact ? Tokens.padding.medium : Tokens.padding.large) * 2), 760)

    function formatPercent(value: real): string {
        const clamped = Math.max(0, Math.min(1, Number(value) || 0));
        return `${Math.round(clamped * 100)}%`;
    }

    ServiceRef {
        service: root.active ? Storage : null
    }

    component UsageBar: Item {
        id: bar

        property real value: 0
        property color colour: root.accent

        implicitHeight: 7

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(root.outline, 0.35)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * Math.max(0, Math.min(1, bar.value))
            radius: height / 2
            color: bar.colour
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.contentWidth
        spacing: root.compact ? Tokens.spacing.small : Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: Tr.tr("Disk usage")
                    color: root.foreground
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: Tr.tr("Mounted filesystems · read-only")
                    color: root.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Text {
                text: Tr.tr("%1 filesystems").arg(Storage.disks.length)
                color: root.muted
                font.pixelSize: 12
            }
        }

        ListView {
            id: diskList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Storage.disks.length > 0
            clip: true
            model: Storage.disks
            spacing: Tokens.spacing.extraSmall
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: diskRow

                required property var modelData

                width: diskList.width
                implicitHeight: diskBody.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Qt.alpha(root.surfaceHigh, 0.55)
                border.width: 1
                border.color: Qt.alpha(root.outline, 0.35)

                ColumnLayout {
                    id: diskBody

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Text {
                            Layout.fillWidth: true
                            text: diskRow.modelData.mount
                            color: root.foreground
                            font.pixelSize: 15
                            font.family: "monospace"
                            font.weight: Font.Medium
                            elide: Text.ElideMiddle
                        }

                        Rectangle {
                            visible: diskRow.modelData.hasRoot
                            implicitWidth: rootChip.implicitWidth + Tokens.padding.small * 2
                            implicitHeight: rootChip.implicitHeight + 4
                            radius: Tokens.rounding.full
                            color: Qt.alpha(root.accent, 0.16)

                            Text {
                                id: rootChip

                                anchors.centerIn: parent
                                text: Tr.tr("root")
                                color: root.accent
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            text: root.formatPercent(diskRow.modelData.perc)
                            color: diskRow.modelData.perc >= 0.9 ? root.secondary : root.accent
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                    }

                    UsageBar {
                        Layout.fillWidth: true
                        value: diskRow.modelData.perc
                        colour: diskRow.modelData.perc >= 0.9 ? root.secondary : root.accent
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Text {
                            Layout.fillWidth: true
                            text: Units.formatKibUsage(diskRow.modelData.used, diskRow.modelData.total)
                            color: root.muted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            text: Tr.tr("%1 free").arg(Units.formatBytes(diskRow.modelData.free * 1024))
                            color: root.muted
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Storage.disks.length === 0
            text: Tr.tr("No mounted filesystems detected yet.")
            color: root.muted
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }
    }
}
