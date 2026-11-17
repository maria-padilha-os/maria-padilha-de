pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils
import "ExtensionManifest.js" as ExtensionManifest

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

    // Extensions that declare a usable dashboard tab and are enabled for it.
    readonly property var tabs: list.filter(ext => ext.canEnable && root.isTabEnabled(ext.id))

    readonly property int enabledCount: list.filter(ext => !ext.shadowed && root.isTabEnabled(ext.id)).length
    readonly property int problemCount: list.filter(ext => ext.errors.length > 0 || ext.warnings.length > 0).length

    function isTabEnabled(id: string): bool {
        return ExtensionManifest.isEnabled(GlobalConfig.dashboard.extensionTabs ?? [], id);
    }

    function setTabEnabled(id: string, enabled: bool): void {
        if (enabled === root.isTabEnabled(id))
            return;
        GlobalConfig.dashboard.extensionTabs = ExtensionManifest.setEnabled(GlobalConfig.dashboard.extensionTabs ?? [], id, enabled);
    }

    // Absolute index of an extension tab in the dashboard tab bar (built-ins
    // that are enabled first, then enabled extensions in sorted order).
    function tabIndex(id: string): int {
        const builtins = [
            GlobalConfig.dashboard.showDashboard,
            GlobalConfig.dashboard.showMedia,
            GlobalConfig.dashboard.showPerformance,
            GlobalConfig.dashboard.showWeather
        ].filter(Boolean).length;
        const index = root.tabs.findIndex(ext => ext.id === id);
        return index < 0 ? -1 : builtins + index;
    }

    function filtered(query: string, mode: string): var {
        const items = list.map(ext => Object.assign({}, ext, {
                enabled: root.isTabEnabled(ext.id)
            }));
        return ExtensionManifest.filterCatalog(items, query, mode);
    }

    function permissionLabel(permission: string): string {
        return ExtensionManifest.permissionLabel(permission);
    }

    function permissionDescription(permission: string): string {
        return ExtensionManifest.permissionDescription(permission);
    }

    function permissionSummary(permissions: var): string {
        return ExtensionManifest.permissionSummary(permissions);
    }

    function describeTab(extension: var): string {
        return ExtensionManifest.describeTab(extension);
    }

    function describeShortcut(extension: var): string {
        return ExtensionManifest.describeShortcut(extension);
    }

    function refresh(): void {
        loading = true;
        scanProc.running = true;
    }

    function parse(output: string): var {
        return ExtensionManifest.catalogFromScan(output);
    }

    Component.onCompleted: refresh()

    Process {
        id: scanProc

        // User extensions take precedence over later bases, then the checkout
        // trees while developing, then the installed copies. Duplicate ids are
        // deliberately kept in the output: the manager marks shadowed copies
        // and real duplicates instead of silently hiding one of them.
        command: [
            "sh", "-c",
            // Resolve each base before walking it: when the shell is a symlink
            // (~/.config/quickshell/caelestia -> checkout/shell), lexical ".."
            // in a QML file URL would drop into ~/.config/quickshell instead
            // of the checkout's extensions directory.
            `priority=0; for base in "$1" "$2" "$3" "$4" "$5" "$6"; do priority=$((priority + 1)); [ -d "$base" ] || continue; base=$(realpath "$base"); for d in "$base"/*/; do [ -f "$d/extension.json" ] || continue; printf 'EXTENSION:%s\\nPRIORITY:%s\\nFILES:' "$d" "$priority"; find "$d" -mindepth 1 -printf '%P\\t' 2>/dev/null; printf '\\n'; if command -v python3 >/dev/null 2>&1 && grep -q '"commands"' "$d/extension.json" 2>/dev/null && out=$(python3 "$7" "$d/extension.json" 2>/dev/null); then printf 'COMMANDS:%s\\n' "$out"; else printf 'COMMANDS:?\\n'; fi; cat "$d/extension.json"; printf '\\n'; done; done`,
            "sh", `${Paths.home}/.config/padilha/extensions`, `${Paths.home}/.config/lilith/extensions`, `${Quickshell.shellDir}/../extensions`, `${Quickshell.shellDir}/../share/extensions`, "/usr/lib/maria-padilha/share/extensions", "/usr/lib/lilith/share/extensions", `${Quickshell.shellDir}/services/extension-commands.py`
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
