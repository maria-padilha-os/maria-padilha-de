import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var bar

    implicitWidth: icon.implicitHeight + Tokens.padding.small
    implicitHeight: icon.implicitHeight

    StateLayer {
        // Same sizing trick as the other bar buttons: a round target that is
        // a little taller than the icon itself.
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: icon.implicitHeight + Tokens.padding.small
        radius: Tokens.rounding.full
        onClicked: {
            const popouts = root.bar.popouts;
            if (popouts.hasCurrent && popouts.currentName === "colourpicker") {
                popouts.hasCurrent = false;
                return;
            }
            popouts.currentName = "colourpicker";
            popouts.currentCenter = root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
            popouts.hasCurrent = true;
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: "palette"
        color: Colours.palette.m3secondary
        fontStyle: Tokens.font.icon.builders.small.weight(Font.Bold).build()
    }
}
