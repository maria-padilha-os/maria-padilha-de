import QtQuick
import Caelestia.Config
import qs.services

// A keyboard focus indicator that works on any palette surface. Keep it as an
// overlay so a control can be a Rectangle, a MouseArea or a custom Item.
Rectangle {
    id: root

    required property Item target
    property color colour: Colours.palette.m3primary
    property real ringWidth: Accessibility.focusRingWidth
    property real margin: 1

    readonly property bool shown: target !== null && target.activeFocus

    anchors.fill: target
    anchors.margins: -margin
    z: 1000

    visible: shown
    color: "transparent"
    border.width: shown ? ringWidth : 0
    border.color: colour
    radius: target && target.hasOwnProperty("radius") ? target.radius : Tokens.rounding.small

    Behavior on border.width {
        enabled: !Accessibility.reducedMotion

        NumberAnimation {
            duration: Accessibility.motion(Tokens.anim.durations.expressiveFastEffects)
            easing: Tokens.anim.expressiveFastEffects
        }
    }
}
