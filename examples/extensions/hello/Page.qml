import QtQuick
import QtQuick.Layouts

// An extension entry is a plain QML item; the settings app gives it the content
// area. Shell modules (qs.services, Caelestia.Config, ...) are importable.
Rectangle {
    property var api

    color: "transparent"

    ColumnLayout {
        anchors.centerIn: parent

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Hello from a plugin")
            color: "white"
            font.pixelSize: 24
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Copy examples/extensions/hello to ~/.config/lilith/extensions/")
            color: "#aaaaaa"
            font.pixelSize: 14
        }
    }
}
