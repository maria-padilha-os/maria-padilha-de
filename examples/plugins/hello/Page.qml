import QtQuick
import QtQuick.Layouts

// A plugin entry is a plain QML item; the settings app gives it the content
// area. Shell modules (qs.services, Caelestia.Config, ...) are importable.
Rectangle {
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
            text: qsTr("Copy examples/plugins/hello to ~/.config/lilith/plugins/")
            color: "#aaaaaa"
            font.pixelSize: 14
        }
    }
}
