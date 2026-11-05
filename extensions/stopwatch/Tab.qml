import QtQuick

Item {
    property var api

    implicitWidth: 340
    implicitHeight: 230

    Widget {
        anchors.fill: parent
        api: root.api
        compact: true
    }
}
