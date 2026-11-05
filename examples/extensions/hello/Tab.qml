import QtQuick

// The dashboard sizes itself to this item; declare the size you want.
Item {
    property var api

    implicitWidth: 360
    implicitHeight: 220

    Text {
        anchors.centerIn: parent
        text: qsTr("Hello from a panel tab")
        color: "white"
        font.pixelSize: 20
    }
}
