import QtQuick
import Caelestia.Config
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

    // An extension may shrink to whatever the dashboard gives it, but never
    // below the minimum its own Tab.qml declares. The tokens are only a first
    // frame fallback so switching tabs does not flash an empty size.
    readonly property real minimumWidth: Math.max(loader.item?.minimumWidth ?? 0, Tokens.sizes.dashboard.userWidth)
    readonly property real minimumHeight: Math.max(loader.item?.minimumHeight ?? 0, Tokens.sizes.dashboard.perfNetworkCardHeight)

    implicitWidth: Math.max(panelWidth, minimumWidth, loader.item?.implicitWidth ?? 0)
    implicitHeight: Math.max(panelHeight, minimumHeight, loader.item?.implicitHeight ?? 0)

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
