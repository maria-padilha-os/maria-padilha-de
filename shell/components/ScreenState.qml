import Quickshell
import "../services/ScreenModel.js" as ScreenModel

PersistentProperties {
    // Null is allowed only for the detached fallback state ShellState returns
    // when the last output disappears.  Normal states always receive the
    // current ShellScreen from the Screens model.
    property ShellScreen modelData
    // Stable connector key shared with Screens. The raw name is still
    // available on modelData for Hyprland and per-monitor config lookups.
    readonly property string outputName: modelData ? ScreenModel.keyFor(modelData, 0) : ""
    readonly property bool attached: modelData !== null

    // Drawer visibilities
    property bool bar
    // Keyboard focus is on the taskbar rather than a panel.
    property bool barFocus
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool assistant

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()

    // The sidebar and assistant share the right drawer. Keep the invariant
    // here too, so the IPC `drawers toggle` path cannot open both.
    // The launcher is the same class of surface: opening it must dismiss the
    // assistant, and opening the assistant must dismiss the launcher.
    onAssistantChanged: {
        if (!assistant)
            return;
        sidebar = false;
        launcher = false;
    }
    onSidebarChanged: if (sidebar && assistant) assistant = false
    onLauncherChanged: {
        if (!launcher)
            return;
        assistant = false;
        sidebar = false;
    }
}
