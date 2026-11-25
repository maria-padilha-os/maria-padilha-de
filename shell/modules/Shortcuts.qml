import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
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
            // A missing, broken or duplicate extension must not be enabled by a
            // stale shortcut.
            const extension = Extensions.list.find(ext => ext.id === extensionId && !ext.shadowed);
            if (!extension || !extension.canEnable) {
                root.pendingExtensionId = "";
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
        description: Tr.tr("Open nexus")
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: Tr.tr("Toggle launcher, dashboard and osd")
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
        description: Tr.tr("Toggle dashboard")
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
        description: Tr.tr("Open dashboard on the dashboard tab")
        onPressed: root.openDashboard("dash")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardMedia"
        description: Tr.tr("Open dashboard on the media tab")
        onPressed: root.openDashboard("media")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardPerformance"
        description: Tr.tr("Open dashboard on the performance tab")
        onPressed: root.openDashboard("performance")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboardWeather"
        description: Tr.tr("Open dashboard on the weather tab")
        onPressed: root.openDashboard("weather")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionTranslator"
        description: Tr.tr("Open dashboard on the translator tab")
        onPressed: root.openExtension("translator")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionColourPicker"
        description: Tr.tr("Open dashboard on the colour picker tab")
        onPressed: root.openExtension("colour-picker")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionCalculator"
        description: Tr.tr("Open dashboard on the calculator tab")
        onPressed: root.openExtension("calculator")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionMaps"
        description: Tr.tr("Open dashboard on the maps tab")
        onPressed: root.openExtension("maps")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionTuner"
        description: Tr.tr("Open dashboard on the guitar tuner tab")
        onPressed: root.openExtension("tuner")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionFiles"
        description: Tr.tr("Open dashboard on the files tab")
        onPressed: root.openExtension("filemanager")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionNotes"
        description: Tr.tr("Open dashboard on the notes tab")
        onPressed: root.openExtension("notes")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionDictionary"
        description: Tr.tr("Open dashboard on the dictionary tab")
        onPressed: root.openExtension("dictionary")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionContacts"
        description: Tr.tr("Open dashboard on the contacts tab")
        onPressed: root.openExtension("contacts")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionSystemMonitor"
        description: Tr.tr("Open dashboard on the system monitor tab")
        onPressed: root.openExtension("system-monitor")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionCalendar"
        description: Tr.tr("Open dashboard on the calendar tab")
        onPressed: root.openExtension("calendar")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionPomodoro"
        description: Tr.tr("Open dashboard on the pomodoro tab")
        onPressed: root.openExtension("pomodoro")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionUnitConverter"
        description: Tr.tr("Open dashboard on the unit converter tab")
        onPressed: root.openExtension("unit-converter")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "extensionDiskUsage"
        description: Tr.tr("Open dashboard on the disk usage tab")
        onPressed: root.openExtension("disk-usage")
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: Tr.tr("Toggle session menu")
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
        description: Tr.tr("Toggle launcher")
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
        description: Tr.tr("Interrupt launcher keybind")
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "taskbar"
        description: Tr.tr("Focus the taskbar")
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (screenState)
                screenState.barFocus = !screenState.barFocus;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: Tr.tr("Toggle sidebar")
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (!screenState.sidebar)
                screenState.assistant = false;
            screenState.sidebar = !screenState.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "assistant"
        description: Tr.tr("Toggle assistant")
        onPressed: {
            if (root.hasFullscreen || !AssistantSettings.enabled)
                return;
            const screenState = ShellState.forActive();
            if (!screenState.assistant)
                screenState.sidebar = false;
            screenState.assistant = !screenState.assistant;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: Tr.tr("Toggle utilities")
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
