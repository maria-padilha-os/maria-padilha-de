import QtQuick
import Caelestia.Config
import qs.services

// Keyboard focus indicator that can be overlaid on any item. Using a separate
// rectangle keeps focus visible even when the target is a custom control with
// no radius or border of its own.
Rectangle {
    id: root

    required property Item target
    property real margin: 1
    property real ringWidth: Accessibility.focusRingWidth
    property color colour: Colours.palette.m3primary

    readonly property bool shown: target !== null && target !== undefined && target.activeFocus

    objectName: "settingsFocusRing"
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
