import QtQuick

// Dashboard entry point for the Files extension. The panel sizes itself to this
// item; Widget keeps its own content centered and readable when stretched.
Item {
    id: root

    property var api
    property bool active: true

    implicitWidth: 760
    implicitHeight: 480

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
    }
}
