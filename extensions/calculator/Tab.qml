import QtQuick

// Dashboard tab: the dashboard sizes itself to this item. The compact layout
// stacks the display, history and keypad; the full dashboard size puts history
// beside the keypad.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 460
    readonly property bool compact: width < 680 || height < 500

    implicitWidth: Math.max(420, minimumWidth)
    implicitHeight: Math.max(560, minimumHeight)

    Widget {
        objectName: "calculatorWidget"

        anchors.fill: parent
        api: root.api
        active: root.active
        compact: root.compact
    }
}
