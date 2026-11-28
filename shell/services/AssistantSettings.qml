pragma Singleton

import Quickshell

PersistentProperties {
    // Persisted in the shell state with the rest of the reloadable UI state.
    property bool enabled: true
    property bool showIndicator: true
    property bool speakReplies: false
    property bool wakeEnabled: false
    property real uiScale: 0.86
    property real textScale: 0.92
    // Remember whether the drawer was open, so a shell restart does not
    // silently cut the user off from the conversation.
    property bool open: false
    // Last session/agent tab selected in the widget. Restored after the
    // backend reports its default session so the conversation does not
    // silently jump back to OS maintenance on a shell restart.
    property string lastSessionId: ""

    reloadableId: "assistant"
}
