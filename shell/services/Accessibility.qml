pragma Singleton

import QtQuick
import Quickshell

// Accessibility switches the user can set without editing the compiled shell
// config. They are environment variables on purpose: the values must be known
// before the first QML frame, and they must keep working when the config file
// is temporarily broken.
Singleton {
    id: root

    readonly property var truthy: /^(1|true|yes|on)$/i

    // PADILHA_REDUCED_MOTION=1 removes non-essential animation. Anim,
    // AnchorAnim and CAnim all ask this singleton for their duration, so a
    // component only has to use those instead of a bare NumberAnimation.
    readonly property bool reducedMotion: truthy.test((Quickshell.env("PADILHA_REDUCED_MOTION") || "").trim())

    // Screen-reader users often ask for less visual motion and more explicit
    // state text. Components can check this to prefer "Muted" over an icon.
    readonly property bool verboseState: truthy.test((Quickshell.env("PADILHA_VERBOSE_STATE") || "").trim())

    readonly property int focusRingWidth: 2

    function motion(ms: int): int {
        return reducedMotion ? 0 : Math.max(0, ms);
    }
}
