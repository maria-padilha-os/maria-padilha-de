import QtQuick
import qs.services

// Hosts an extension's dashboard tab. The extension decides its own size;
// these are only fallbacks for the first frame before the Loader resolves.
Item {
    id: root

    property var extension
    property bool active: true
    property real panelWidth: 0
    property real panelHeight: 0

    property alias loader: loader

    implicitWidth: panelWidth > 0 ? panelWidth : loader.item?.implicitWidth ?? 420
    implicitHeight: panelHeight > 0 ? panelHeight : loader.item?.implicitHeight ?? 240

    function load(): void {
        const url = root.extension?.tabUrl ?? "";
        if (url === loadedUrl)
            return;
        loadedUrl = url;
        if (url)
            loader.setSource(url, { api: Object.assign({}, Extensions.api, { extension: root.extension }) });
        else
            loader.source = "";
    }

    property string loadedUrl

    onExtensionChanged: root.load()
    Component.onCompleted: root.load()

    Loader {
        id: loader

        anchors.fill: parent

        onLoaded: {
            if (item) {
                item.width = Qt.binding(() => loader.width);
                item.height = Qt.binding(() => loader.height);
                item.active = Qt.binding(() => root.active);
            }
        }
    }
}
