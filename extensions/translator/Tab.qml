import QtQuick

// Dashboard entry point. The dashboard sizes itself to this item, so keep the
// tab compact and let Widget stack the two text areas.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 480
    implicitHeight: 280

    Widget {
        anchors.fill: parent
        api: root.api
        compact: true
    }
}
