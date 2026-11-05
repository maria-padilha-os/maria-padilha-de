import QtQuick

// Dashboard tab entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api

    implicitWidth: 560
    implicitHeight: 360

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
