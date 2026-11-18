// Offscreen stand-in for Quickshell.Wayland's layer-shell enums.
pragma Singleton

import QtQml

QtObject {
    enum Mode {
        Ignore,
        Auto,
        Exclusive
    }
}
