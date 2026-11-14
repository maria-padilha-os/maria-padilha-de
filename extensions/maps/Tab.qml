import QtQuick

// Dashboard tab entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 420
    readonly property int minimumHeight: 300

    implicitWidth: Math.max(560, minimumWidth)
    implicitHeight: Math.max(360, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
    }
}
