pragma Singleton

import Quickshell

PersistentProperties {
    // Persisted in the shell state with the rest of the reloadable UI state.
    property bool enabled: true
    property bool showIndicator: true
    property bool speakReplies: false
    property bool wakeEnabled: false
    // Remember whether the drawer was open, so a shell restart does not
    // silently cut the user off from the conversation.
    property bool open: false

    reloadableId: "assistant"
}
