pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property bool shouldBeActive: screenState.assistant && AssistantSettings.enabled
    readonly property real screenWidth: root.screenState.modelData ? root.screenState.modelData.width : 1920
    // Share of the current screen, clamped so the drawer remains usable on
    // small outputs and never covers the whole desktop.
    readonly property real panelWidth: Math.round(Math.max(360, Math.min(root.screenWidth * AssistantSettings.widthRatio, root.screenWidth - 48)))
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: root.panelWidth
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: root.panelWidth - content.anchors.leftMargin - content.anchors.margins
            screenState: root.screenState
        }
    }
}
