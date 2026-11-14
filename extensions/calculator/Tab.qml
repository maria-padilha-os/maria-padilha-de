import QtQuick

// Dashboard tab: the dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 300
    readonly property int minimumHeight: 180

    implicitWidth: Math.max(360, minimumWidth)
    implicitHeight: Math.max(220, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
