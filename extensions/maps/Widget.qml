import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n

// OpenStreetMap viewer with a 3x3 slippy tile grid and Nominatim search.
// All theme colours come from the Colours singleton passed in `api`.
Item {
    id: root

    property var api
    property bool active: true
    // Paths.cache is ~/.cache/caelestia and honours XDG_CACHE_HOME.
    property string cacheDir: (root.api && root.api.paths && root.api.paths.cache
        ? root.api.paths.cache
        : ((root.api && root.api.paths ? root.api.paths.home : "") + "/.cache/caelestia")) + "/maps"
    readonly property string userAgent: "Padilha-Maps/1.0 (+https://github.com/maria-padilha-os/maria-padilha-de)"

    // The shell assigns `api` when it creates the item, so it may still be
    // unset on the first frame. Everything below tolerates that.
    readonly property var palette: root.api && root.api.colours ? root.api.colours.palette : null

    readonly property color onSurface: root.palette ? root.palette.m3onSurface : "transparent"
    readonly property color onSurfaceVariant: root.palette ? root.palette.m3onSurfaceVariant : "transparent"
    readonly property color surface: root.palette ? root.palette.m3surface : "transparent"
    readonly property color surfaceContainerHigh: root.palette ? root.palette.m3surfaceContainerHigh : "transparent"
    readonly property color surfaceContainerHighest: root.palette ? root.palette.m3surfaceContainerHighest : "transparent"
    readonly property color outlineVariant: root.palette ? root.palette.m3outlineVariant : "transparent"
    readonly property color primary: root.palette ? root.palette.m3primary : "transparent"
    readonly property color onPrimary: root.palette ? root.palette.m3onPrimary : "transparent"
    readonly property color primaryContainer: root.palette ? root.palette.m3primaryContainer : "transparent"
    readonly property color onPrimaryContainer: root.palette ? root.palette.m3onPrimaryContainer : "transparent"

    readonly property int tileSize: 256
    readonly property int gridSize: 3
    readonly property real maxLatitude: 85.05112878
    readonly property int minZoom: 3
    readonly property int maxZoom: 18
    readonly property int maxResults: 5

    // Porto Alegre, RS.
    property real centerLat: -30.0346
    property real centerLon: -51.2177
    property int zoom: 12

    property bool searching: false
    property string searchMessage: ""
    property var pendingRequest: null

    // --- Tile math ---------------------------------------------------------
    // Street-map slippy tiles: x/y in tile units, 256 screen pixels per tile.

    function lon2tile(lon: real, z: int): real {
        return (lon + 180) / 360 * Math.pow(2, z);
    }

    function lat2tile(lat: real, z: int): real {
        const clamped = Math.max(-root.maxLatitude, Math.min(root.maxLatitude, lat));
        const rad = clamped * Math.PI / 180;
        return (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * Math.pow(2, z);
    }

    function tileX2lon(x: real, z: int): real {
        return x / Math.pow(2, z) * 360 - 180;
    }

    function tileY2lat(y: real, z: int): real {
        const n = Math.PI * (1 - 2 * y / Math.pow(2, z));
        return Math.atan((Math.exp(n) - Math.exp(-n)) / 2) * 180 / Math.PI;
    }

    function wrap(value: real, size: real): real {
        return ((value % size) + size) % size;
    }

    // --- Map interaction ---------------------------------------------------

    // Move the map content by a screen-pixel delta, like a grab-and-drag.
    function panBy(dx: real, dy: real) {
        const n = Math.pow(2, root.zoom);
        const worldSize = root.tileSize * n;
        const x = root.wrap(root.lon2tile(root.centerLon, root.zoom) * root.tileSize - dx, worldSize);
        const y = Math.max(0, Math.min(worldSize, root.lat2tile(root.centerLat, root.zoom) * root.tileSize - dy));
        root.centerLon = root.tileX2lon(x / root.tileSize, root.zoom);
        root.centerLat = root.tileY2lat(y / root.tileSize, root.zoom);
    }

    function setZoom(value: int) {
        const next = Math.max(root.minZoom, Math.min(root.maxZoom, value));
        if (next !== root.zoom)
            root.zoom = next;
    }

    // --- Search ------------------------------------------------------------

    function hideResults() {
        root.searchMessage = "";
        if (searchResults.count > 0)
            searchResults.clear();
    }

    function selectResult(lat: real, lon: real) {
        root.centerLat = Math.max(-root.maxLatitude, Math.min(root.maxLatitude, lat));
        root.centerLon = (((lon + 180) % 360) + 360) % 360 - 180;
        root.hideResults();
        searchField.focus = false;
    }

    function performSearch() {
        const query = searchField.text.trim();
        if (query.length === 0 || root.searching || searchCooldown.running)
            return;

        root.searching = true;
        root.searchMessage = "";
        searchResults.clear();

        const request = new XMLHttpRequest();
        root.pendingRequest = request;

        request.onreadystatechange = function () {
            if (request.readyState !== 4)
                return;
            if (root.pendingRequest === request)
                root.pendingRequest = null;
            root.searching = false;
            searchCooldown.restart();

            if (request.status !== 200) {
                root.searchMessage = Tr.tr("Search failed (%1)").arg(request.status);
                return;
            }

            let results;
            try {
                results = JSON.parse(request.responseText);
            } catch (error) {
                root.searchMessage = Tr.tr("Could not read the search results");
                return;
            }

            if (!Array.isArray(results) || results.length === 0) {
                root.searchMessage = Tr.tr("No places found");
                return;
            }

            for (let i = 0; i < Math.min(results.length, root.maxResults); ++i) {
                const item = results[i];
                const lat = Number(item.lat);
                const lon = Number(item.lon);
                if (!isFinite(lat) || !isFinite(lon))
                    continue;
                searchResults.append({
                    displayName: String(item.display_name ?? ""),
                    lat: lat,
                    lon: lon
                });
            }

            if (searchResults.count === 0)
                root.searchMessage = Tr.tr("No places found");
        };

        request.open("GET", "https://nominatim.openstreetmap.org/search?format=json&q=" + encodeURIComponent(query) + "&limit=5");
        request.setRequestHeader("Accept", "application/json");
        // Nominatim rejects Qt's stock user agent; identify the application.
        request.setRequestHeader("User-Agent", root.userAgent);
        request.send();
    }

    ListModel {
        id: searchResults
    }

    // Nominatim allows at most one request per second.
    Timer {
        id: searchCooldown

        interval: 1100
    }

    Component.onDestruction: {
        if (root.pendingRequest)
            root.pendingRequest.abort();
    }

    // --- UI ----------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.padding.medium
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            TextField {
                id: searchField

                Layout.fillWidth: true
                Layout.preferredHeight: 40

                leftPadding: Tokens.padding.large
                rightPadding: Tokens.padding.large
                topPadding: 0
                bottomPadding: 0

                placeholderText: Tr.tr("Search for a place")
                placeholderTextColor: root.onSurfaceVariant
                color: root.onSurface
                selectionColor: Qt.alpha(root.primary, 0.4)
                selectedTextColor: root.onSurface
                font: Tokens.font.body.medium
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true

                onAccepted: root.performSearch()

                background: Rectangle {
                    radius: Tokens.rounding.full
                    color: root.surfaceContainerHigh
                    border.width: searchField.activeFocus ? 1 : 0
                    border.color: root.primary
                }
            }

            Rectangle {
                id: searchButton

                Layout.preferredHeight: 40
                Layout.preferredWidth: searchButtonLabel.implicitWidth + Tokens.padding.large * 2
                radius: Tokens.rounding.full
                color: searchButtonMouse.containsMouse ? root.primary : root.primaryContainer
                opacity: root.searching ? 0.7 : 1

                Text {
                    id: searchButtonLabel

                    anchors.centerIn: parent
                    text: root.searching ? Tr.tr("Searching…") : Tr.tr("Search")
                    color: searchButtonMouse.containsMouse ? root.onPrimary : root.onPrimaryContainer
                    font: Tokens.font.label.medium
                }

                MouseArea {
                    id: searchButtonMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.searching
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.performSearch()
                }
            }
        }

        Rectangle {
            id: mapFrame

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            Layout.bottomMargin: Tokens.padding.medium

            radius: Tokens.rounding.large
            clip: true
            color: root.surfaceContainerHigh

            Item {
                id: mapArea

                // Geometry shared by the nine cells. The centre tile is the
                // middle of the grid; columns/rows are clamped near the poles.
                readonly property real n: Math.pow(2, root.zoom)
                readonly property real worldSize: root.tileSize * n
                readonly property real centerPx: root.wrap(root.lon2tile(root.centerLon, root.zoom) * root.tileSize, worldSize)
                readonly property real centerPy: root.lat2tile(root.centerLat, root.zoom) * root.tileSize
                readonly property real originX: centerPx - width / 2
                readonly property real originY: centerPy - height / 2
                readonly property int baseX: Math.floor(centerPx / root.tileSize) - 1
                readonly property int baseY: Math.floor(centerPy / root.tileSize) - 1

                anchors.fill: parent
                clip: true

                Repeater {
                    model: root.gridSize * root.gridSize

                    delegate: Item {
                        id: tile

                        required property int index
                        readonly property int column: index % root.gridSize
                        readonly property int row: Math.floor(index / root.gridSize)
                        readonly property int tileX: mapArea.baseX + column
                        readonly property int tileY: mapArea.baseY + row
                        readonly property bool valid: tileY >= 0 && tileY < mapArea.n
                        readonly property int wrappedX: ((tileX % mapArea.n) + mapArea.n) % mapArea.n

                        visible: valid
                        x: tileX * root.tileSize - mapArea.originX
                        y: tileY * root.tileSize - mapArea.originY
                        width: root.tileSize
                        height: root.tileSize

                        Rectangle {
                            anchors.fill: parent
                            color: root.surfaceContainerHigh
                        }

                        readonly property string tileUrl: tile.valid ? "https://tile.openstreetmap.org/" + root.zoom + "/" + tile.wrappedX + "/" + tile.tileY + ".png" : ""
                        readonly property string cachePath: root.cacheDir + "/" + root.zoom + "/" + tile.wrappedX + "/" + tile.tileY + ".png"
                        property bool ready: false
                        property bool failed: false

                        // Fetches only the tiles of the visible 3x3 grid, only
                        // while this tab is the current one, and only when the
                        // disk cache does not already have the tile. The
                        // identifying User-Agent is required by the OSM tile
                        // usage policy; the cache avoids refetching on reloads.
                        function requestTile(): void {
                            if (!root.active || !tile.valid || tile.ready || fetch.running)
                                return;
                            fetch.command = [
                                "sh", "-c",
                                `cache="$2"; [ -f "$cache" ] && exit 0; mkdir -p "$(dirname "$cache")" || exit 1; curl -fsSL --max-time 20 -A "$3" -o "$cache.tmp" "$1" || { rm -f "$cache.tmp"; exit 1; }; mv "$cache.tmp" "$cache"`,
                                "sh", tile.tileUrl, tile.cachePath, root.userAgent
                            ];
                            fetch.running = true;
                        }

                        onTileUrlChanged: {
                            tile.ready = false;
                            tile.failed = false;
                            if (root.active)
                                delay.restart();
                        }

                        Connections {
                            target: root

                            function onActiveChanged(): void {
                                if (root.active)
                                    delay.restart();
                            }
                        }

                        Component.onCompleted: {
                            if (root.active)
                                delay.start();
                        }

                        Image {
                            id: tileImage

                            anchors.fill: parent
                            source: tile.ready ? "file://" + tile.cachePath : ""
                            asynchronous: true
                            cache: false
                            fillMode: Image.Pad
                            smooth: false
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: tile.failed
                            text: Tr.tr("Tile unavailable")
                            color: root.onSurfaceVariant
                            font: Tokens.font.body.small
                        }

                        Process {
                            id: fetch

                            onExited: (exitCode) => {
                                tile.failed = exitCode !== 0;
                                if (exitCode === 0)
                                    tile.ready = true;
                            }
                        }

                        Timer {
                            id: delay

                            // Stagger the nine requests instead of firing a burst.
                            interval: 80 + (tile.index % 9) * 90
                            onTriggered: tile.requestTile()
                        }
                    }
                }

                MouseArea {
                    id: mapDrag

                    property real lastX: 0
                    property real lastY: 0

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onPressed: (mouse) => {
                        root.hideResults();
                        searchField.focus = false;
                        mapDrag.lastX = mouse.x;
                        mapDrag.lastY = mouse.y;
                    }

                    onPositionChanged: (mouse) => {
                        if (!pressed)
                            return;
                        root.panBy(mouse.x - mapDrag.lastX, mouse.y - mapDrag.lastY);
                        mapDrag.lastX = mouse.x;
                        mapDrag.lastY = mouse.y;
                    }

                    onWheel: (wheel) => {
                        root.setZoom(root.zoom + (wheel.angleDelta.y > 0 ? 1 : -1));
                        wheel.accepted = true;
                    }
                }

                Rectangle {
                    id: attribution

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.small

                    width: attributionLabel.implicitWidth + Tokens.padding.medium
                    height: attributionLabel.implicitHeight + Tokens.padding.extraSmall

                    radius: Tokens.rounding.small
                    color: Qt.alpha(root.surface, 0.82)

                    Text {
                        id: attributionLabel

                        anchors.centerIn: parent
                        text: "© OpenStreetMap contributors"
                        color: root.onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    MouseArea {
                        id: attributionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/copyright")
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    Rectangle {
                        width: 38
                        height: 38
                        radius: Tokens.rounding.full
                        color: Qt.alpha(root.surfaceContainerHigh, 0.94)
                        border.width: 1
                        border.color: root.outlineVariant
                        opacity: root.zoom < root.maxZoom ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: root.onSurface
                            font: Tokens.font.title.large
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.zoom < root.maxZoom
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setZoom(root.zoom + 1)
                        }
                    }

                    Rectangle {
                        width: 38
                        height: 38
                        radius: Tokens.rounding.full
                        color: Qt.alpha(root.surfaceContainerHigh, 0.94)
                        border.width: 1
                        border.color: root.outlineVariant
                        opacity: root.zoom > root.minZoom ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            color: root.onSurface
                            font: Tokens.font.title.large
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.zoom > root.minZoom
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setZoom(root.zoom - 1)
                        }
                    }
                }

                Rectangle {
                    id: resultsPanel

                    readonly property bool hasStatus: root.searching || root.searchMessage.length > 0

                    visible: hasStatus || searchResults.count > 0
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Tokens.padding.medium
                    height: resultsColumn.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.large
                    color: Qt.alpha(root.surfaceContainerHigh, 0.97)
                    border.width: 1
                    border.color: root.outlineVariant
                    clip: true

                    ColumnLayout {
                        id: resultsColumn

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.small
                        spacing: 0

                        Text {
                            visible: root.searching
                            Layout.fillWidth: true
                            Layout.margins: Tokens.padding.small
                            text: Tr.tr("Searching…")
                            color: root.onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: !root.searching && root.searchMessage.length > 0
                            Layout.fillWidth: true
                            Layout.margins: Tokens.padding.small
                            text: root.searchMessage
                            color: root.onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: searchResults

                            delegate: Rectangle {
                                id: resultRow

                                required property string displayName
                                required property real lat
                                required property real lon

                                Layout.fillWidth: true
                                implicitHeight: resultLabel.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.medium
                                color: resultMouse.containsMouse ? root.surfaceContainerHighest : "transparent"

                                Text {
                                    id: resultLabel

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Tokens.padding.medium
                                    anchors.rightMargin: Tokens.padding.medium
                                    text: resultRow.displayName
                                    color: root.onSurface
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                MouseArea {
                                    id: resultMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectResult(resultRow.lat, resultRow.lon)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
