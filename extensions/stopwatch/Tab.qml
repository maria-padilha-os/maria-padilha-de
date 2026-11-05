import QtQuick

Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 340
    implicitHeight: 230

    Widget {
        anchors.fill: parent
        api: root.api
        compact: true
    }
}
