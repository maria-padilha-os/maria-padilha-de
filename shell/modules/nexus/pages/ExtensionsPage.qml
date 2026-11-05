import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Extensions")

    Component.onCompleted: {
        if (Extensions.list.length === 0)
            Extensions.refresh();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.extraSmall
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Extensions.loading ? Tr.tr("Looking for extensions…") : Tr.tr("%1 extensions").arg(Extensions.list.length)
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                enabled: !Extensions.loading
                onClicked: Extensions.refresh()
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            visible: Extensions.list.length > 0
            text: Tr.tr("Enabled extensions appear as tabs in the top panel, after Weather.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        SectionHeader {
            visible: Extensions.list.length > 0
            text: Tr.tr("Installed")
        }

        Repeater {
            model: Extensions.list

            delegate: ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Extensions.list.length - 1
                text: modelData.name
                subtext: !modelData.valid ? Tr.tr("extension.json is not valid JSON") : modelData.tab.length > 0 ? modelData.description : Tr.tr("No tab available")
                checked: Extensions.isTabEnabled(modelData.id)
                enabled: modelData.valid && modelData.tab.length > 0
                onToggled: Extensions.setTabEnabled(modelData.id, checked)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: !Extensions.loading && Extensions.list.length === 0
            text: Tr.tr("No extensions installed. An extension is a folder under ~/.config/lilith/extensions with an extension.json manifest and a Tab.qml tab.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
    }
}
