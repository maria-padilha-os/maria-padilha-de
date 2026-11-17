import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

RadioButton {
    id: root

    font: Tokens.font.body.small
    property string accessibleName
    property string accessibleDescription

    activeFocusOnTab: true

    Accessible.role: Accessible.RadioButton
    Accessible.name: accessibleName.length > 0 ? accessibleName : text
    Accessible.description: accessibleDescription
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.focusable: enabled
    Accessible.focused: activeFocus
    function activateFromKeyboard(): void {
        if (!root.enabled)
            return;
        root.checked = true;
        root.toggled();
    }

    Accessible.onPressAction: root.activateFromKeyboard()

    Keys.onReturnPressed: root.activateFromKeyboard()
    Keys.onEnterPressed: root.activateFromKeyboard()
    Keys.onSpacePressed: root.activateFromKeyboard()

    implicitWidth: implicitIndicatorWidth + implicitContentWidth + contentItem.anchors.leftMargin
    implicitHeight: Math.max(implicitIndicatorHeight, implicitContentHeight)

    indicator: Rectangle {
        id: outerCircle

        implicitWidth: 20
        implicitHeight: 20
        radius: Tokens.rounding.full
        color: "transparent"
        border.color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        border.width: 2
        anchors.verticalCenter: parent.verticalCenter

        StateLayer {
            anchors.margins: -Tokens.padding.small
            color: root.checked ? Colours.palette.m3onSurface : Colours.palette.m3primary
            z: -1
            onClicked: root.click()
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: 8
            implicitHeight: 8

            radius: Tokens.rounding.full
            color: Qt.alpha(Colours.palette.m3primary, root.checked ? 1 : 0)
        }

        Behavior on border.color {
            CAnim {}
        }
    }

    FocusRing {
        target: root
        margin: 3
    }

    contentItem: StyledText {
        text: root.text
        font: root.font
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: outerCircle.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.medium
        elide: Text.ElideRight
    }
}
