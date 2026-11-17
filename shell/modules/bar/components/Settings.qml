import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Item {
    id: root

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("Open settings")
    Accessible.description: Tr.tr("Open the settings window")
    Accessible.focusable: true
    Accessible.focused: activeFocus
    Accessible.onPressAction: root.openSettings()

    function openSettings(): void {
        WindowFactory.create();
    }

    Keys.onReturnPressed: root.openSettings()
    Keys.onEnterPressed: root.openSettings()
    Keys.onSpacePressed: root.openSettings()

    FocusRing {
        target: root
    }

    StateLayer {
        // Same sizing trick as Power: taller than the parent for a round target.
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            root.forceActiveFocus();
            root.openSettings();
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: "settings"
        color: Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
