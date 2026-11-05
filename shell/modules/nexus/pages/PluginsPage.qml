import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    property var plugins: []
    property var opened: null
    property bool loading: false

    readonly property bool listVisible: opened === null

    property alias loader: loader

    title: Tr.tr("Plugins")

    function parse(output: string): var {
        const result = [];
        for (const chunk of output.split("PLUGIN:")) {
            const trimmed = chunk.trim();
            if (!trimmed)
                continue;
            const newline = trimmed.indexOf("\n");
            const path = newline === -1 ? trimmed : trimmed.slice(0, newline);
            const body = newline === -1 ? "" : trimmed.slice(newline + 1);
            let manifest = null;
            try {
                manifest = JSON.parse(body);
            } catch (e) {
                manifest = null;
            }
            result.push({
                path: path,
                directoryPath: path.replace(/\/plugin\.json$/, ""),
                directory: path.split("/").slice(-2, -1)[0] ?? "",
                name: manifest?.name ?? "",
                description: manifest?.description ?? "",
                version: manifest?.version ?? "",
                entry: manifest?.entry ?? "Page.qml",
                valid: manifest !== null
            });
        }
        result.sort((a, b) => (a.name || a.directory).localeCompare(b.name || b.directory));
        return result;
    }

    function refresh(): void {
        loading = true;
        plugins = [];
        opened = null;
        scanProc.running = true;
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                visible: !root.listVisible
                icon: "arrow_back"
                type: IconButton.Tonal
                isRound: true
                onClicked: root.opened = null
            }

            StyledText {
                Layout.fillWidth: true
                text: root.listVisible ? root.loading ? Tr.tr("Looking for plugins…") : Tr.tr("%1 plugins").arg(root.plugins.length) : root.opened?.name ?? ""
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            IconButton {
                visible: root.listVisible
                icon: "refresh"
                type: IconButton.Tonal
                isRound: true
                enabled: !root.loading
                onClicked: root.refresh()
            }
        }

        SectionHeader {
            visible: root.listVisible && root.plugins.length > 0
            text: Tr.tr("Installed")
        }

        Repeater {
            model: root.listVisible ? root.plugins : []

            delegate: NavRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.plugins.length - 1
                icon: "extension"
                text: modelData.name || modelData.directory
                subtext: modelData.valid ? modelData.description : Tr.tr("plugin.json is not valid JSON")
                onClicked: root.opened = modelData
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: root.listVisible && !root.loading && root.plugins.length === 0
            text: Tr.tr("No plugins installed. A plugin is a folder under ~/.config/lilith/plugins with a plugin.json manifest and a QML entry file.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Loader {
            id: loader

            visible: !root.listVisible
            Layout.fillWidth: true
            Layout.preferredHeight: 640
            source: root.listVisible ? "" : `file://${root.opened.directoryPath}/${root.opened.entry}`
        }

        StyledText {
            Layout.fillWidth: true
            visible: !root.listVisible && loader.status === Loader.Error
            text: Tr.tr("This plugin failed to load. Check its entry file: %1").arg(root.opened?.entry ?? "")
            color: Colours.palette.m3error
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        // Non-visual: PageBase's default property is an Item.
        Process {
            id: scanProc

            command: [
                "sh", "-c",
                `dir="$1"; [ -d "$dir" ] || exit 0; for f in "$dir"/*/plugin.json; do [ -f "$f" ] || continue; printf 'PLUGIN:%s\\n' "$f"; cat "$f"; printf '\\n'; done`,
                "sh", `${Paths.home}/.config/lilith/plugins`
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    root.plugins = root.parse(text);
                    root.loading = false;
                }
            }

            onExited: root.loading = false
        }
    }
}
