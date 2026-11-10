import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            if (!AssistantSettings.enabled)
                return;
            const screenState = ShellState.forActive();
            if (!screenState.assistant)
                screenState.sidebar = false;
            screenState.assistant = !screenState.assistant;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: Assistant.streaming ? "graphic_eq" : "auto_awesome"
        color: Assistant.streaming ? Colours.palette.m3primary : Colours.palette.m3secondary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()

        Behavior on color {
            Anim {}
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        width: 5
        height: 5
        radius: 3
        color: Colours.palette.m3error
        visible: Assistant.error.length > 0
    }
}
