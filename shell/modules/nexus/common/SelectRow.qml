import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property alias label: label.text
    property string subtext
    property alias menuItems: splitButton.menuItems
    property alias active: splitButton.active
    property alias fallbackText: splitButton.fallbackText
    property alias fallbackIcon: splitButton.fallbackIcon
    property alias menuOnTop: splitButton.menuOnTop
    readonly property bool settingsRow: true
    readonly property bool settingsInteractive: true
    readonly property string settingsLabel: root.label
    readonly property string settingsDescription: root.subtext

    signal selected(item: MenuItem)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2
    clip: false
    z: splitButton.expanded ? 1 : 0
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: root.label
    Accessible.description: root.subtext
    Accessible.focusable: root.enabled
    Accessible.focused: root.activeFocus
    Accessible.onPressAction: root.openMenu()

    function openMenu(): void {
        splitButton.expanded = !splitButton.expanded;
    }

    Keys.onReturnPressed: root.openMenu()
    Keys.onEnterPressed: root.openMenu()
    Keys.onSpacePressed: root.openMenu()
    Keys.onEscapePressed: splitButton.expanded = false

    FocusRing {
        target: root
        colour: Colours.palette.m3primary
        radius: Tokens.rounding.small
        margin: 2
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                id: label

                Layout.fillWidth: true
                font: Tokens.font.body.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }

        SplitButton {
            id: splitButton

            accessibleName: root.label
            type: SplitButton.Tonal
            stateLayer.onClicked: splitButton.expanded = !splitButton.expanded
            menu.onItemSelected: item => root.selected(item)
        }
    }
}
