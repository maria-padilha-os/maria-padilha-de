import QtQuick

Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 300
    readonly property int minimumHeight: 200

    implicitWidth: Math.max(340, minimumWidth)
    implicitHeight: Math.max(230, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
        compact: true
    }
}
