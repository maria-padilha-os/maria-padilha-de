import QtQuick

// Dashboard tab entry. The dashboard sizes itself to these implicit sizes.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 240

    implicitWidth: Math.max(420, minimumWidth)
    implicitHeight: Math.max(260, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
