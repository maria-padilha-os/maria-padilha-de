import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property var updates: []
    property bool checking: false

    title: Tr.tr("Updates")

    function refresh(): void {
        checking = true;
        updates = [];
        checkProc.running = true;
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.checking ? Tr.tr("Checking for updates…") : root.updates.length === 0 ? Tr.tr("System is up to date") : Tr.tr("%1 updates available").arg(root.updates.length)
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                enabled: !root.checking
                onClicked: root.refresh()
            }
        }

        SectionHeader {
            visible: root.updates.length > 0
            text: Tr.tr("Packages")
        }

        Repeater {
            model: root.updates

            delegate: InfoRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.updates.length - 1
                label: modelData.name
                value: `${modelData.old} → ${modelData.new}`
            }
        }

        // Non-visual: PageBase's default property is an Item, so this lives in
        // the layout's data property instead of at page level.
        Process {
            id: checkProc

            command: ["pacman", "-Qu"]

            stdout: StdioCollector {
                onStreamFinished: {
                    const rows = [];
                    for (const line of text.trim().split("\n")) {
                        if (!line.trim())
                            continue;
                        const parts = line.split(" -> ");
                        if (parts.length !== 2)
                            continue;
                        const left = parts[0].split(" ");
                        rows.push({
                            name: left[0],
                            old: left.slice(1).join(" "),
                            new: parts[1]
                        });
                    }
                    root.updates = rows;
                    root.checking = false;
                }
            }

            onExited: root.checking = false
        }
    }
}
