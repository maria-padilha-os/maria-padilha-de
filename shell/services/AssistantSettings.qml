pragma Singleton

import Quickshell

PersistentProperties {
    // Persisted in the shell state with the rest of the reloadable UI state.
    property bool enabled: true
    property bool showIndicator: true
    property bool speakReplies: false
    property bool wakeEnabled: false
    property real widthRatio: 0.5

    reloadableId: "assistant"
}
