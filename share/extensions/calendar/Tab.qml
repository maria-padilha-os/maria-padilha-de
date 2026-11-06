import QtQuick

// Dashboard entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 680
    implicitHeight: 460

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
        compact: true
    }
}
