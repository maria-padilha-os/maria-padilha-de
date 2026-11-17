import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    readonly property string stateDescription: Assistant.error.length > 0 ? Tr.tr("Assistant has an error") : Assistant.streaming ? Tr.tr("Assistant is responding") : Tr.tr("Open the assistant")

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: Tr.tr("Assistant")
    Accessible.description: root.stateDescription
    Accessible.focusable: AssistantSettings.enabled
    Accessible.focused: activeFocus
    Accessible.onPressAction: root.toggleAssistant()

    function toggleAssistant(): void {
        if (!AssistantSettings.enabled)
            return;
        Assistant.start();
        const screenState = ShellState.forActive();
        if (!screenState)
            return;
        if (!screenState.assistant)
            screenState.sidebar = false;
        screenState.assistant = !screenState.assistant;
    }

    Keys.onReturnPressed: root.toggleAssistant()
    Keys.onEnterPressed: root.toggleAssistant()
    Keys.onSpacePressed: root.toggleAssistant()

    FocusRing {
        target: root
    }

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            root.forceActiveFocus();
            root.toggleAssistant();
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent

        text: Assistant.streaming ? "graphic_eq" : "auto_awesome"
        color: Assistant.streaming ? Colours.palette.m3primary : Colours.palette.m3secondary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()

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
