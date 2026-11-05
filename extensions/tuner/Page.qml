import QtQuick

// Settings page entry. The shell gives this item the settings content area.
Item {
    id: root

    property var api

    implicitWidth: 420
    implicitHeight: 260

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
