import QtQuick

// Dashboard entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 800
    implicitHeight: 540

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
        compact: false
    }
}
