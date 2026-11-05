import QtQuick

// Dashboard tab: the dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 360
    implicitHeight: 220

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
