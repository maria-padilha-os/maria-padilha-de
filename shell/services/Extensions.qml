pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    property var list: []
    property bool loading: false

    // Handles passed to an extension's root item (it must declare `property var api`).
    readonly property var api: ({
            config: GlobalConfig,
            colours: Colours,
            brightness: Brightness,
            hypr: Hypr,
            paths: Paths
        })

    // Extensions that declare a dashboard tab and are enabled for it.
    readonly property var tabs: list.filter(ext => ext.tab.length > 0 && root.isTabEnabled(ext.id))

    function isTabEnabled(id: string): bool {
        return (GlobalConfig.dashboard.extensionTabs ?? []).includes(id);
    }

    function setTabEnabled(id: string, enabled: bool): void {
        const current = (GlobalConfig.dashboard.extensionTabs ?? []).slice();
        const index = current.indexOf(id);
        if (enabled === (index !== -1))
            return;
        if (enabled)
            current.push(id);
        else
            current.splice(index, 1);
        GlobalConfig.dashboard.extensionTabs = current;
    }

    function refresh(): void {
        loading = true;
        scanProc.running = true;
    }

    function parse(output: string): var {
        const result = [];
        for (const chunk of output.split("EXTENSION:")) {
            const trimmed = chunk.trim();
            if (!trimmed)
                continue;
            const newline = trimmed.indexOf("\n");
            const rawDir = newline === -1 ? trimmed : trimmed.slice(0, newline);
            const body = newline === -1 ? "" : trimmed.slice(newline + 1);
            const dirPath = rawDir.replace(/\/+$/, "");
            const id = dirPath.split("/").slice(-1)[0] ?? "";
            let manifest = null;
            try {
                manifest = JSON.parse(body);
            } catch (e) {
                manifest = null;
            }
            result.push({
                id: id,
                dirPath: dirPath,
                name: manifest?.name ?? id,
                description: manifest?.description ?? "",
                version: manifest?.version ?? "",
                icon: manifest?.icon ?? "extension",
                entry: manifest?.entry ?? "Page.qml",
                tab: manifest?.tab ?? "",
                entryUrl: `file://${dirPath}/${manifest?.entry ?? "Page.qml"}`,
                tabUrl: manifest?.tab ? `file://${dirPath}/${manifest.tab}` : "",
                valid: manifest !== null
            });
        }
        result.sort((a, b) => a.name.localeCompare(b.name));
        return result;
    }

    Component.onCompleted: refresh()

    Process {
        id: scanProc

        command: [
            "sh", "-c",
            `dir="$1"; [ -d "$dir" ] || exit 0; for d in "$dir"/*/; do [ -f "$d/extension.json" ] || continue; printf 'EXTENSION:%s\\n' "$d"; cat "$d/extension.json"; printf '\\n'; done`,
            "sh", `${Paths.home}/.config/lilith/extensions`
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                root.list = root.parse(text);
                root.loading = false;
            }
        }

        onExited: root.loading = false
    }
}
