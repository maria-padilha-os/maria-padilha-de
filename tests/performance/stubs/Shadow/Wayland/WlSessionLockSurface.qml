import QtQuick

Item {
    property var screen
    property color color: "transparent"
    property var mask
    readonly property Item contentItem: inner
    default property alias contentData: inner.data

    Item {
        id: inner
        anchors.fill: parent
    }
}
