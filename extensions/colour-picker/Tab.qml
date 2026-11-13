import QtQuick

// Dashboard tab entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 360
    implicitHeight: 430

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
    }
}
