import QtQuick
import Caelestia.Config
import qs.services

AnchorAnimation {
    enum Type {
        StandardSmall = 0,
        Standard,
        StandardLarge,
        StandardExtraLarge,
        EmphasizedSmall,
        Emphasized,
        EmphasizedLarge,
        EmphasizedExtraLarge,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial
    }

    property int type: AnchorAnim.DefaultSpatial

    duration: {
        let ms = Tokens.anim.durations.expressiveDefaultSpatial;
        if (type >= AnchorAnim.StandardSmall && type <= AnchorAnim.SlowSpatial) {
            if (type == AnchorAnim.FastSpatial)
                ms = Tokens.anim.durations.expressiveFastSpatial;
            else if (type == AnchorAnim.DefaultSpatial)
                ms = Tokens.anim.durations.expressiveDefaultSpatial;
            else if (type == AnchorAnim.SlowSpatial)
                ms = Tokens.anim.durations.expressiveSlowSpatial;
            else {
                const types = ["small", "normal", "large", "extraLarge"];
                const idx = type % 4; // 0-7 are the 4 standard types
                ms = Tokens.anim.durations[types[idx]];
            }
        }
        return Accessibility.motion(ms);
    }
    easing: {
        if (type == AnchorAnim.FastSpatial)
            return Tokens.anim.expressiveFastSpatial;
        if (type == AnchorAnim.DefaultSpatial)
            return Tokens.anim.expressiveDefaultSpatial;
        if (type == AnchorAnim.SlowSpatial)
            return Tokens.anim.expressiveSlowSpatial;

        if (type >= AnchorAnim.StandardSmall && type <= AnchorAnim.StandardExtraLarge)
            return Tokens.anim.standard;
        if (type >= AnchorAnim.EmphasizedSmall && type <= AnchorAnim.EmphasizedExtraLarge)
            return Tokens.anim.emphasized;

        return Tokens.anim.expressiveDefaultSpatial;
    }
}
