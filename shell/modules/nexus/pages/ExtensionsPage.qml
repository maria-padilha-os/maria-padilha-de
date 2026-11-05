import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    property var opened: null

    readonly property bool listVisible: opened === null

    property alias loader: loader

    title: Tr.tr("Extensions")

    Component.onCompleted: {
        if (Extensions.list.length === 0)
            Extensions.refresh();
    }

    function open(ext): void {
        opened = ext;
        loader.setSource(ext.entryUrl, {
            api: Extensions.api
        });
    }

    function close(): void {
        opened = null;
        loader.source = "";
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                visible: !root.listVisible
                icon: "arrow_back"
                type: IconButton.Tonal
                isRound: true
                onClicked: root.close()
            }

            StyledText {
                Layout.fillWidth: true
                text: root.listVisible ? Extensions.loading ? Tr.tr("Looking for extensions…") : Tr.tr("%1 extensions").arg(Extensions.list.length) : root.opened?.name ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                visible: root.listVisible
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                enabled: !Extensions.loading
                onClicked: Extensions.refresh()
            }
        }

        SectionHeader {
            visible: root.listVisible && Extensions.list.length > 0
            text: Tr.tr("Installed")
        }

        Repeater {
            model: root.listVisible ? Extensions.list : []

            delegate: NavRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Extensions.list.length - 1
                icon: modelData.icon
                text: modelData.name
                subtext: modelData.valid ? `${modelData.description}${modelData.tab ? " · " + Tr.tr("top panel") : ""}` : Tr.tr("extension.json is not valid JSON")
                onClicked: root.open(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: root.listVisible && !Extensions.loading && Extensions.list.length === 0
            text: Tr.tr("No extensions installed. An extension is a folder under ~/.config/lilith/extensions with an extension.json manifest and QML entry files.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        ToggleRow {
            visible: !root.listVisible && (root.opened?.tab.length ?? 0) > 0
            text: Tr.tr("Show in the top panel")
            subtext: Tr.tr("Adds this extension as a dashboard tab")
            checked: Extensions.isTabEnabled(root.opened?.id ?? "")
            onToggled: Extensions.setTabEnabled(root.opened.id, checked)
        }

        Loader {
            id: loader

            visible: !root.listVisible
            Layout.fillWidth: true
            Layout.preferredHeight: 640
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.listVisible && loader.status === Loader.Error
            text: Tr.tr("This extension failed to load. Check its entry file: %1").arg(root.opened?.entry ?? "")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
    }
}
