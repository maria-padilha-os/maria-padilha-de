import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("Session menu")
    Accessible.description: Tr.tr("Open or close the session menu")
    Accessible.focusable: true
    Accessible.focused: activeFocus
    Accessible.onPressAction: root.toggleSession()

    function toggleSession(): void {
        root.screenState.session = !root.screenState.session;
    }

    Keys.onReturnPressed: root.toggleSession()
    Keys.onEnterPressed: root.toggleSession()
    Keys.onSpacePressed: root.toggleSession()

    FocusRing {
        target: root
    }

    StateLayer {
        // Cursed workaround to make the height larger than the parent
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            root.forceActiveFocus();
            root.toggleSession();
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: "power_settings_new"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
