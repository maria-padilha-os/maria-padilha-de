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

        Greeter {}
    }
}
