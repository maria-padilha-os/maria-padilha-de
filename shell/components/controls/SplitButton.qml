import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Row {
    id: root

    enum Type {
        Filled,
        Tonal
    }

    property real horizontalPadding: Tokens.padding.medium
    property real verticalPadding: Tokens.padding.small
    property int type: SplitButton.Filled
    property bool disabled
    property bool menuOnTop
    property string fallbackIcon
    property string fallbackText
    property real minLeftWidth
    property string accessibleName

    property alias menuItems: menu.items
    property alias active: menu.active
    property alias expanded: menu.expanded
    readonly property alias menu: menu
    readonly property alias iconLabel: iconLabel
    readonly property alias label: label
    readonly property alias stateLayer: stateLayer
    readonly property alias textRow: textRow
    readonly property alias expandBtn: expandBtn

    property color colour: type == SplitButton.Filled ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
    property color textColour: type == SplitButton.Filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
    property color disabledColour: Qt.alpha(Colours.palette.m3onSurface, 0.1)
    property color disabledTextColour: Qt.alpha(Colours.palette.m3onSurface, 0.38)

    spacing: Math.floor(Tokens.spacing.extraSmall / 2)

    StyledRect {
        id: mainButton

        radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
        topRightRadius: Tokens.rounding.medium / 2
        bottomRightRadius: Tokens.rounding.medium / 2
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: Math.max(root.minLeftWidth, textRow.implicitWidth + root.horizontalPadding * 2)
        implicitHeight: expandBtn.implicitHeight

        activeFocusOnTab: !root.disabled

        Accessible.role: Accessible.Button
        Accessible.name: root.accessibleName.length > 0 ? root.accessibleName : (root.active?.activeText ?? root.fallbackText)
        Accessible.focusable: !root.disabled
        Accessible.focused: activeFocus
        Accessible.onPressAction: root.active?.clicked()

        Keys.onReturnPressed: root.active?.clicked()
        Keys.onEnterPressed: root.active?.clicked()
        Keys.onSpacePressed: root.active?.clicked()

        FocusRing {
            target: mainButton
            radius: mainButton.radius
        }

        StateLayer {
            id: stateLayer

            topRightRadius: parent.topRightRadius
            bottomRightRadius: parent.bottomRightRadius
            color: root.textColour
            disabled: root.disabled
            onClicked: root.active?.clicked()
        }

        RowLayout {
            id: textRow

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: Math.floor(root.verticalPadding / 4)
            spacing: Tokens.spacing.small

            MaterialIcon {
                id: iconLabel

                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: root.active?.activeIcon ?? root.fallbackIcon
                color: root.disabled ? root.disabledTextColour : root.textColour
                fill: 1
            }

            StyledText {
                id: label

                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
                animate: true
                text: root.active?.activeText ?? root.fallbackText
                color: root.disabled ? root.disabledTextColour : root.textColour
                clip: true

                Behavior on Layout.preferredWidth {
                    Anim {
                        type: Anim.Emphasized
                    }
                }
            }
        }
    }

    StyledRect {
        id: expandBtn

        property real rad: root.expanded ? implicitHeight / 2 * Math.min(1, Tokens.rounding.scale) : Tokens.rounding.medium / 2

        radius: implicitHeight / 2 * Math.min(1, Tokens.rounding.scale)
        topLeftRadius: rad
        bottomLeftRadius: rad
        color: root.disabled ? root.disabledColour : root.colour

        implicitWidth: implicitHeight
        implicitHeight: expandIcon.implicitHeight + root.verticalPadding * 2

        activeFocusOnTab: !root.disabled

        Accessible.role: Accessible.Button
        Accessible.name: root.accessibleName.length > 0 ? root.accessibleName + " " + Tr.tr("options") : root.fallbackText + " " + Tr.tr("options")
        Accessible.focusable: !root.disabled
        Accessible.focused: activeFocus
        Accessible.onPressAction: root.expanded = !root.expanded

        Keys.onReturnPressed: root.expanded = !root.expanded
        Keys.onEnterPressed: root.expanded = !root.expanded
        Keys.onSpacePressed: root.expanded = !root.expanded
        Keys.onEscapePressed: root.expanded = false

        FocusRing {
            target: expandBtn
            radius: expandBtn.radius
        }

        StateLayer {
            id: expandStateLayer

            rect.topLeftRadius: parent.topLeftRadius
            rect.bottomLeftRadius: parent.bottomLeftRadius
            color: root.textColour
            disabled: root.disabled
            onClicked: root.expanded = !root.expanded
        }

        MaterialIcon {
            id: expandIcon

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.expanded ? 0 : -Math.floor(root.verticalPadding / 4)

            text: "expand_more"
            color: root.disabled ? root.disabledTextColour : root.textColour
            rotation: root.expanded ? 180 : 0

            Behavior on anchors.horizontalCenterOffset {
                Anim {}
            }

            Behavior on rotation {
                Anim {}
            }
        }

        Behavior on rad {
            Anim {}
        }
    }

    Menu {
        id: menu

        attachTo: expandBtn
        attachSideY: root.menuOnTop ? Menu.Top : Menu.Bottom
        thisSideY: root.menuOnTop ? Menu.Bottom : Menu.Top
        marginY: Tokens.spacing.small * (root.menuOnTop ? -1 : 1)
    }
}
