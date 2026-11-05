import QtQuick

// Dashboard tab entry. The dashboard sizes itself to these implicit sizes.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 420
    implicitHeight: 260

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
