import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledSwitch {
    id: root

    property string subtext
    property alias first: bg.first
    readonly property bool settingsRow: true
    readonly property bool settingsInteractive: true
    readonly property string settingsLabel: root.text
    readonly property string settingsDescription: root.subtext
    property alias last: bg.last
    readonly property alias bg: bg

    Layout.fillWidth: true

    horizontalPadding: Tokens.padding.largeIncreased
    verticalPadding: Tokens.padding.medium
    font: Tokens.font.body.small

    implicitWidth: implicitContentWidth + implicitIndicatorWidth + horizontalPadding * 2
    implicitHeight: Math.max(implicitContentHeight, implicitIndicatorHeight) + verticalPadding * 2
    cLayer: 2
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.text
    Accessible.description: root.subtext
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.focusable: root.enabled
    Accessible.focused: root.activeFocus
    Accessible.onPressAction: root.toggleFromKeyboard()

    function toggleFromKeyboard(): void {
        if (!root.enabled)
            return;
        root.checked = !root.checked;
        root.toggled();
    }

    Keys.onReturnPressed: root.toggleFromKeyboard()
    Keys.onEnterPressed: root.toggleFromKeyboard()

    FocusRing {
        target: root
        colour: Colours.palette.m3primary
        radius: Tokens.rounding.small
        margin: 2
    }

    indicator.anchors.verticalCenter: verticalCenter
    indicator.anchors.right: right
    indicator.anchors.rightMargin: root.horizontalPadding

    onPressed: stateLayer.press(stateLayer.mouseX, stateLayer.mouseY)

    background: ConnectedRect {
        id: bg

        StateLayer {
            id: stateLayer

            disabled: root.disabled
            manualPressOverride: root.pressed
        }
    }

    contentItem: Item {
        anchors.left: parent.left
        anchors.right: root.indicator.left
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: Tokens.spacing.medium

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                id: label

                anchors.left: parent.left
                anchors.right: parent.right

                text: root.text
                font: root.font
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right

                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
    }
}
