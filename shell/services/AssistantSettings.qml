pragma Singleton

import Quickshell

PersistentProperties {
    // Persisted in the shell state with the rest of the reloadable UI state.
    property bool enabled: true
    property bool showIndicator: true

    reloadableId: "assistant"
}
