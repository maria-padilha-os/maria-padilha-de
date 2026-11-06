import QtQuick

// Dashboard entry point. The dashboard sizes itself to this item.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 560
    implicitHeight: 340

    Widget {
        anchors.fill: parent
        api: root.api
        compact: true
    }
}
