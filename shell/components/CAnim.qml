import QtQuick
import Caelestia.Config
import qs.services

ColorAnimation {
    duration: Accessibility.motion(Tokens.anim.durations.expressiveSlowEffects)
    easing: Tokens.anim.expressiveSlowEffects
}
