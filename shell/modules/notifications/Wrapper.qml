import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    required property Item assistantPanel
    property Item dashboardPanel
    property real placementX
    property real placementY
    property string placementAnchor: "top-right"
    readonly property var anchorParts: (placementAnchor || "top-right").split("-")
    readonly property string anchorVertical: anchorParts[0] === "middle" ? "middle" : anchorParts[0]
    readonly property string anchorHorizontal: anchorParts[1] || "center"
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    readonly property real rightDrawerOffset: {
        let offset = 0;
        if (assistantPanel && assistantPanel.visible)
            offset = Math.max(offset, assistantPanel.implicitWidth);
        if (sidebarPanel && sidebarPanel.visible)
            offset = Math.max(offset, sidebarPanel.implicitWidth);
        return offset;
    }
    readonly property real dashboardOffset: dashboardPanel && dashboardPanel.visible ? dashboardPanel.implicitHeight + Tokens.spacing.medium : 0

    visible: height > 0
    x: root.anchorHorizontal === "left" ? root.placementX : root.anchorHorizontal === "right" ? parent.width - implicitWidth - root.placementX - root.rightDrawerOffset : (parent.width - implicitWidth) / 2 + root.placementX
    y: root.anchorVertical === "top" ? root.placementY + root.dashboardOffset : root.anchorVertical === "bottom" ? parent.height - implicitHeight - root.placementY : (parent.height - implicitHeight) / 2 + root.placementY
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.topMargin: 5
        screenState: root.screenState
    }
}
