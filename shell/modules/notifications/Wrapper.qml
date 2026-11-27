import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    required property Item assistantPanel
    property real placementX
    property real placementY
    property string placementAnchor: "top-right"
    readonly property var anchorParts: (placementAnchor || "top-right").split("-")
    readonly property string anchorVertical: anchorParts[0] === "middle" ? "middle" : anchorParts[0]
    readonly property string anchorHorizontal: anchorParts[1] || "center"
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    visible: height > 0
    x: root.anchorHorizontal === "left" ? root.placementX : root.anchorHorizontal === "right" ? parent.width - implicitWidth - root.placementX : (parent.width - implicitWidth) / 2 + root.placementX
    y: root.anchorVertical === "top" ? root.placementY : root.anchorVertical === "bottom" ? parent.height - implicitHeight - root.placementY : (parent.height - implicitHeight) / 2 + root.placementY
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.topMargin: 5
        screenState: root.screenState
    }
}
