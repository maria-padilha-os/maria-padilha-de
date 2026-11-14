import QtQuick

// Dashboard entry point for the Files extension. The panel sizes itself to this
// item; Widget keeps its own content centered and readable when stretched.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 520
    readonly property int minimumHeight: 360

    implicitWidth: Math.max(760, minimumWidth)
    implicitHeight: Math.max(480, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
    }
}
