import QtQuick

// Settings page entry point. The host gives it the content area, so the map
// gets much more room than in the dashboard tab.
Item {
    id: root

    property var api

    implicitWidth: 960
    implicitHeight: 640

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
