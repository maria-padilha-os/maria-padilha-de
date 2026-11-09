import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool assistant

    // The sidebar and assistant share the right drawer. Keep the invariant
    // here too, so the IPC `drawers toggle` path cannot open both.
    onAssistantChanged: if (assistant && sidebar) sidebar = false
    onSidebarChanged: if (sidebar && assistant) assistant = false

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
