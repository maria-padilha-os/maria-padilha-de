import QtQuick

Item {
    property var api

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
