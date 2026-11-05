import QtQuick

// Settings entry: the host gives this item the content area, so it must not
// declare a size of its own.
Item {
    id: root

    property var api

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
