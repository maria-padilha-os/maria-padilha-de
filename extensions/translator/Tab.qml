import QtQuick

// Dashboard entry point. The dashboard sizes itself to this item, so keep the
// tab compact and let Widget stack the two text areas.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 260

    implicitWidth: Math.max(480, minimumWidth)
    implicitHeight: Math.max(280, minimumHeight)

    Widget {
        anchors.fill: parent
        api: root.api
        active: root.active
        compact: true
    }
}
