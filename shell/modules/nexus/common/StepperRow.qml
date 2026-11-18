pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property real value
    property real from: 0
    property real to: 99
    property real stepSize: 1
    readonly property bool settingsRow: true
    readonly property bool settingsInteractive: true
    readonly property string settingsLabel: root.label
    readonly property string settingsDescription: root.subtext

    signal moved(value: real)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2
    activeFocusOnTab: true
    Accessible.role: Accessible.SpinBox
    Accessible.name: root.label
    Accessible.description: root.subtext
    Accessible.focusable: root.enabled
    Accessible.focused: root.activeFocus

    Keys.onReturnPressed: root.activate()
    Keys.onEnterPressed: root.activate()

    function activate(): void {
        if (root.enabled)
            spinBox.forceActiveFocus();
    }

    FocusRing {
        target: root
        colour: Colours.palette.m3primary
        radius: Tokens.rounding.small
        margin: 2
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }

        StyledSpinBox {
            id: spinBox

            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            cLayer: 2
            accessibleName: root.label
            accessibleDescription: root.subtext
            onValueModified: root.moved(value)
        }
    }
}
