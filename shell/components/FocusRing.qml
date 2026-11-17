import QtQuick
import Caelestia.Config

// Keyboard focus indicator that can be overlaid on any item. Using a separate
// rectangle keeps focus visible even when the target is a custom control with
// no radius or border of its own.
Rectangle {
    id: root

    required property Item target
    property real margin: 1
    property real radius: Tokens.rounding.small
    property color colour: "transparent"

    readonly property bool shown: target !== null && target !== undefined && target.activeFocus

    objectName: "settingsFocusRing"
    anchors.fill: target
    anchors.margins: -margin
    z: 1000

    visible: shown
    color: "transparent"
    border.width: shown ? 2 : 0
    border.color: colour
}
