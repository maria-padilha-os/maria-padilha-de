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
    implicitWidth: Tokens.sizes.session.button

    visible: AssistantSettings.enabled && !screenState.assistant && !screenState.launcher && !screenState.sidebar && !screenState.dashboard

    WlrLayershell.namespace: "caelestia-assistant-handle"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the small centre strip takes input. The rest of the right edge is
    // transparent to the browser/editor scrollbar underneath.
    mask: Region {
        x: 0
        y: Math.round((root.height - (Tokens.sizes.session.button + 12)) / 2)
        width: root.width
        height: Tokens.sizes.session.button + 12
    }

    Item {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: hover.hovered || Assistant.streaming ? Tokens.sizes.session.button : 14
        height: Tokens.sizes.session.button

        Behavior on width {
            Anim {}
        }

        StyledRect {
            id: pill

            property real pulseOpacity: 1

            anchors.fill: parent
            radius: Tokens.rounding.largeIncreased
            color: Colours.tPalette.m3surfaceContainer
            opacity: Assistant.streaming ? pulseOpacity : 1

            SequentialAnimation {
                running: Assistant.streaming
                loops: Animation.Infinite

                NumberAnimation {
                    target: pill
                    property: "pulseOpacity"
                    from: 1
                    to: 0.5
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: pill
                    property: "pulseOpacity"
                    from: 0.5
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: Assistant.streaming ? "graphic_eq" : "auto_awesome"
            color: Assistant.streaming ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.icon.builders.large.scale(1.3).build()
            fill: 1
            opacity: hover.hovered || Assistant.streaming ? 1 : 0

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
