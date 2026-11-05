import QtQuick

// Settings entry point. The host gives this item the content area and assigns
// `api` (colours, paths, ...); Widget does the real work.
Item {
    id: root

    property var api

    Widget {
        anchors.fill: parent
        api: root.api
    }
}
