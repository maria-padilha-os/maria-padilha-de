pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

PanelWindow {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState

    screen: root.screen
    color: "transparent"

    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    implicitWidth: 56

    visible: AssistantSettings.enabled && !screenState.assistant && !screenState.launcher && !screenState.sidebar && !screenState.dashboard

    WlrLayershell.namespace: "caelestia-assistant-handle"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the small centre strip takes input. The rest of the right edge is
    // transparent to the browser/editor scrollbar underneath.
    mask: Region {
        x: 0
        y: Math.round((root.height - 108) / 2)
        width: root.width
        height: 108
    }

    Item {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: hover.hovered ? 52 : 14
        height: 96

        Behavior on width {
            Anim {}
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Qt.alpha(Colours.palette.m3surface, 0.94)
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "auto_awesome"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.medium
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                Anim {}
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.screenState.assistant = true
        }
    }
}
