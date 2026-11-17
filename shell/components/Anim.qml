import QtQuick
import Caelestia.Config
import qs.services

NumberAnimation {
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
        SlowSpatial,
        FastEffects,
        DefaultEffects,
        SlowEffects
    }

    property int type: Anim.DefaultSpatial

    duration: {
        let ms = Tokens.anim.durations.normal;
        if (type >= Anim.StandardSmall && type <= Anim.SlowEffects) {
            if (type === Anim.FastSpatial)
                ms = Tokens.anim.durations.expressiveFastSpatial;
            else if (type === Anim.DefaultSpatial)
                ms = Tokens.anim.durations.expressiveDefaultSpatial;
            else if (type === Anim.SlowSpatial)
                ms = Tokens.anim.durations.expressiveSlowSpatial;
            else if (type === Anim.FastEffects)
                ms = Tokens.anim.durations.expressiveFastEffects;
            else if (type === Anim.DefaultEffects)
                ms = Tokens.anim.durations.expressiveDefaultEffects;
            else if (type === Anim.SlowEffects)
                ms = Tokens.anim.durations.expressiveSlowEffects;
            else {
                const types = ["small", "normal", "large", "extraLarge"];
                const idx = type % 4; // 0-7 are the 4 standard types
                ms = Tokens.anim.durations[types[idx]];
            }
        }
        return Accessibility.motion(ms);
    }
    easing: {
        if (type === Anim.FastSpatial)
            return Tokens.anim.expressiveFastSpatial;
        if (type === Anim.DefaultSpatial)
            return Tokens.anim.expressiveDefaultSpatial;
        if (type === Anim.SlowSpatial)
            return Tokens.anim.expressiveSlowSpatial;
        if (type === Anim.FastEffects)
            return Tokens.anim.expressiveFastEffects;
        if (type === Anim.DefaultEffects)
            return Tokens.anim.expressiveDefaultEffects;
        if (type === Anim.SlowEffects)
            return Tokens.anim.expressiveSlowEffects;

        if (type >= Anim.EmphasizedSmall && type <= Anim.EmphasizedExtraLarge)
            return Tokens.anim.emphasized;
        return Tokens.anim.standard;
    }
}
