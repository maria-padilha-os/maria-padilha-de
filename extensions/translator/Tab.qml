import QtQuick

// Dashboard entry point. The dashboard stretches this item to the built-in tab
// size, so the widget should use all of it. Below the comfortable reading size
// it switches to the compact layout; the minimums keep the language row, both
// text panels and the status line from being clipped at the narrow end.
Item {
    id: root

    property var api
    property bool active: true

    readonly property int minimumWidth: 360
    readonly property int minimumHeight: 280
    readonly property bool compact: width < 640 || height < 420

    implicitWidth: Math.max(480, minimumWidth)
    implicitHeight: Math.max(280, minimumHeight)

    Widget {
        objectName: "translatorWidget"

        anchors.fill: parent
        api: root.api
        active: root.active
        compact: root.compact
    }
}
