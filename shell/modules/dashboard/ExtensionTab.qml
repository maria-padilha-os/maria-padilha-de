import QtQuick
import qs.services

// Hosts an extension's dashboard tab. The extension decides its own size;
// these are only fallbacks for the first frame before the Loader resolves.
Item {
    id: root

    property var extension

    property alias loader: loader

    implicitWidth: loader.item?.implicitWidth ?? 420
    implicitHeight: loader.item?.implicitHeight ?? 240

    function load(): void {
        const url = root.extension?.tabUrl ?? "";
        if (url === loadedUrl)
            return;
        loadedUrl = url;
        if (url)
            loader.setSource(url, { api: Extensions.api });
        else
            loader.source = "";
    }

    property string loadedUrl

    onExtensionChanged: root.load()
    Component.onCompleted: root.load()

    Loader {
        id: loader

        anchors.fill: parent
    }
}
