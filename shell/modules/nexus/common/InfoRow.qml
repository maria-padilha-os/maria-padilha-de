pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property alias value: value.text
    property string icon
    property color iconColour: Colours.palette.m3onSurfaceVariant
    property Component leadingComponent: icon ? iconComp : null
    readonly property bool settingsRow: true
    readonly property bool settingsInteractive: false
    readonly property string settingsLabel: root.label
    readonly property string settingsDescription: root.subtext

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2
    Accessible.role: Accessible.StaticText
    Accessible.name: root.label
    Accessible.description: root.subtext

    Accessible.role: Accessible.StaticText
    Accessible.name: [label.text, value.text].filter(s => s.length > 0).join(": ")
    Accessible.description: subtext

    Component {
        id: iconComp

        MaterialIcon {
            text: root.icon
            color: root.iconColour
            fontStyle: Tokens.font.icon.small
        }
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        Loader {
            visible: root.leadingComponent
            active: root.leadingComponent
            sourceComponent: root.leadingComponent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            id: value

            Layout.maximumWidth: root.width / 2
            horizontalAlignment: Text.AlignRight
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }
}
