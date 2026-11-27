pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

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

    // Only the bottom-right corner strip takes input. The rest of the edge
    // stays transparent to the browser/editor scrollbar underneath.
    mask: Region {
        x: 0
        y: root.height - Tokens.sizes.session.button
        width: root.width
        height: Tokens.sizes.session.button
    }

    Item {
        id: handle

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.right: parent.right
        width: Tokens.sizes.session.button
        height: Tokens.sizes.session.button
        StyledRect {
            id: pill

            anchors.fill: parent
            radius: Tokens.rounding.largeIncreased
            color: Qt.alpha(Colours.tPalette.m3surfaceContainer, 1)
            opacity: 1
        }

        AnimatedImage {
            id: avatar

            anchors.centerIn: parent
            width: 64
            height: 64
            source: Paths.absolutePath(Config.paths.sessionGif)
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            playing: hover.hovered || Assistant.streaming
            visible: status === Image.Ready
            opacity: 1

            Behavior on opacity {
                Anim {}
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: avatar.status !== Image.Ready
            text: Assistant.streaming ? "graphic_eq" : "auto_awesome"
            color: Assistant.streaming ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font: Tokens.font.icon.builders.large.scale(1.3).build()
            fill: 1
            opacity: 1

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
            Accessible.role: Accessible.Button
            Accessible.name: Tr.tr("Open Padilha")
            Accessible.onPressAction: root.screenState.assistant = true
            onClicked: root.screenState.assistant = true
        }
    }
}
