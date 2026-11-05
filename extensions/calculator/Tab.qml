import QtQuick

// Dashboard tab: the dashboard sizes itself to this item.
Item {
    id: root

    property var api

    implicitWidth: 360
    implicitHeight: 220

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
