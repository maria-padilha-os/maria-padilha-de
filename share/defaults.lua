-- Two wallpapers, two moods: white for the day, black for the night.
--
-- Both are painted around the same red, so the seed is the same in both
-- modes: the candle red of the artwork (HCT hue 29, chroma 72). The desktop
-- is black and red because the paintings are, not because a red was picked
-- out of a hat. Point `wallpaper` at any other image and its own seed is used
-- instead; `seed = nil` enables that.
--
-- Override any of this in ~/.config/padilha/daylight.lua (same shape, shallow
-- merge over this table).

return {
    day_start = 6,   -- 06:00 to 17:59 is the light half
    night_start = 18,

    day = {
        wallpaper = "share/wallpapers/day.jpg",
        seed = "b12e1b",
    },
    night = {
        wallpaper = "share/wallpapers/night.jpg",
        seed = "b12e1b",
    },
}
