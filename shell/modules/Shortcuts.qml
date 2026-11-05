import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    // Open the dashboard directly on `tab`; pressing the same shortcut again
    // closes it. The index is built from the enabled tabs only, matching the
    // order in the dashboard's tab bar (Content.qml).
    // Open the dashboard directly on an extension tab; pressing the same
    // shortcut again closes it. Enables the tab first if needed.
    property string pendingExtensionId: ""

    Timer {
        id: extensionRetry

        interval: 400
        onTriggered: {
            if (root.pendingExtensionId.length > 0)
                root.openExtension(root.pendingExtensionId);
        }
    }

    function openExtension(extensionId: string): void {
        if (root.hasFullscreen)
            return;
        let index = Extensions.tabIndex(extensionId);
        if (index < 0) {
            // The scan may still be in flight on a fresh shell.
            if (Extensions.list.length === 0) {
                root.pendingExtensionId = extensionId;
                Extensions.refresh();
                extensionRetry.restart();
                return;
            }
            Extensions.setTabEnabled(extensionId, true);
            index = Extensions.tabIndex(extensionId);
        }
        root.pendingExtensionId = "";
        if (index < 0)
            return;
        const screenState = ShellState.forActive();
        if (screenState.dashboard && screenState.dashboardTab === index) {
            screenState.dashboard = false;
            return;
        }
        screenState.dashboardTab = index;
        screenState.dashboard = true;
    }

    function openDashboard(tab: string): void {
        if (root.hasFullscreen)
            return;
        const tabs = [
            {
                id: "dash",
                enabled: GlobalConfig.dashboard.showDashboard
            },
            {
                id: "media",
                enabled: GlobalConfig.dashboard.showMedia
            },
            {
                id: "performance",
                enabled: GlobalConfig.dashboard.showPerformance
            },
            {
                id: "weather",
                enabled: GlobalConfig.dashboard.showWeather
            }
        ];
        let index = 0;
        let target = -1;
        for (const t of tabs) {
            if (!t.enabled)
                continue;
            if (t.id === tab) {
                target = index;
                break;
            }
            index++;
        }
        if (target < 0)
            return;
        const screenState = ShellState.forActive();
        if (screenState.dashboard && screenState.dashboardTab === target) {
            screenState.dashboard = false;
            return;
        }
        screenState.dashboardTab = target;
        screenState.dashboard = true;
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = ShellState.forActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.dashboard = !screenState.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardDash"
        description: "Open dashboard on the dashboard tab"
        onPressed: root.openDashboard("dash")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardMedia"
        description: "Open dashboard on the media tab"
        onPressed: root.openDashboard("media")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardPerformance"
        description: "Open dashboard on the performance tab"
        onPressed: root.openDashboard("performance")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardWeather"
        description: "Open dashboard on the weather tab"
        onPressed: root.openDashboard("weather")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionTranslator"
        description: "Open dashboard on the translator tab"
        onPressed: root.openExtension("translator")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionCalculator"
        description: "Open dashboard on the calculator tab"
        onPressed: root.openExtension("calculator")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionMaps"
        description: "Open dashboard on the maps tab"
        onPressed: root.openExtension("maps")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionTuner"
        description: "Open dashboard on the guitar tuner tab"
        onPressed: root.openExtension("tuner")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.session = !screenState.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const screenState = ShellState.forActive();
                screenState.launcher = !screenState.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.sidebar = !screenState.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            screenState.utilities = !screenState.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const screenState = ShellState.forActive();
                screenState[drawer] = !screenState[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const screenState = ShellState.forActive();
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            const screenState = ShellState.forActive();
            if (typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        target: "nexus"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
