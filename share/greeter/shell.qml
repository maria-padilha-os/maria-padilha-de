//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell

// Maria Padilha greeter, run by greetd inside cage. This is a separate
// Quickshell configuration: it must not read user state or config.
ShellRoot {
    FloatingWindow {
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        width: screen ? screen.width : 1920
        height: screen ? screen.height : 1080
        visible: true
        // Cage maximizes toplevels, but an explicit fullscreen request keeps
        // the card centred on the output instead of inheriting stale geometry.
        fullscreen: true

        Greeter {
            anchors.fill: parent
        }
    }

    // Last-resort escape if the greeter itself is unusable. Exiting makes cage
    // return non-zero, and padilha-greeter-qs falls back to the console
    // tuigreet UI, which does not grab the DRM seat.
    Shortcut {
        sequence: "F12"
        context: Qt.ApplicationShortcut
        onActivated: Quickshell.execDetached(["/usr/bin/kill", "-TERM", "" + Quickshell.processId])
    }
}
