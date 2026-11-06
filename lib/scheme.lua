-- The Padilha palette: one seed colour in, the shell's whole colour set out.
--
-- The role table is Material 3's: six tonal palettes (primary, secondary,
-- tertiary, neutral, neutral-variant, error) and a fixed tone per role. The
-- seed only moves hue and chroma; tone comes from the table, so contrast is a
-- design decision, not a property of the wallpaper.
--
-- Named terminal and editor colours are harmonised towards the primary hue,
-- the same idea as Material's "harmonize", so nothing on screen clashes with
-- the wallpaper even though gruvbox and catppuccin were designed in a vacuum.

local C = require("colour")

local M = {}

local min, abs = math.min, math.abs

--------------------------------------------------------------------------
-- Variants: how the seed becomes six palettes
--------------------------------------------------------------------------

local variants = {
    -- hue shift, chroma, for: primary, secondary, tertiary
    tonalspot = { p = { 0, 36 }, s = { 0, 16 }, t = { 60, 24 } },
    vibrant = { p = { 0, 60 }, s = { 0, 24 }, t = { 30, 32 } },
    fidelity = { p = { 0, 48 }, s = { 0, 16 }, t = { 15, 24 } },
    content = { p = { 0, 0 }, s = { 0, 0.33 }, t = { 60, 0.5 } },
    expressive = { p = { 30, 40 }, s = { 15, 24 }, t = { 75, 32 } },
    fruitsalad = { p = { 0, 48 }, s = { 30, 16 }, t = { 60, 24 } },
    rainbow = { p = { 0, 48 }, s = { 0, 16 }, t = { 60, 24 } },
    neutral = { p = { 0, 6 }, s = { 0, 6 }, t = { 0, 6 } },
    monochrome = { p = { 0, 0 }, s = { 0, 0 }, t = { 0, 0 } },
}

M.variants = {}
for name in pairs(variants) do
    M.variants[#M.variants + 1] = name
end
table.sort(M.variants)

local function palettes(seed_h, seed_c, variant)
    local v = variants[variant] or variants.tonalspot
    v = {
        p = { v.p[1], (variant == "content") and seed_c or v.p[2] },
        s = { v.s[1], (variant == "content") and seed_c / 3 or v.s[2] },
        t = { v.t[1], (variant == "content") and seed_c / 2 or v.t[2] },
    }
    if variant == "monochrome" or variant == "neutral" then
        return {
            p = { seed_h, 0 },
            s = { seed_h, 0 },
            t = { seed_h, 0 },
            n = { seed_h, 0 },
            nv = { seed_h, 0 },
            e = { 25, 0 },
        }
    end
    return {
        p = { (seed_h + v.p[1]) % 360, v.p[2] },
        s = { (seed_h + v.s[1]) % 360, v.s[2] },
        t = { (seed_h + v.t[1]) % 360, v.t[2] },
        n = { seed_h, 6 },
        nv = { seed_h, 8 },
        e = { 25, 84 },
    }
end

--------------------------------------------------------------------------
-- Roles
--------------------------------------------------------------------------

-- { name, palette, tone }
local roles = {
    light = {
        { "primary", "p", 40 }, { "onPrimary", "p", 100 }, { "primaryContainer", "p", 90 },
        { "onPrimaryContainer", "p", 10 }, { "primaryDim", "p", 35 },
        { "inversePrimary", "p", 80 },
        { "primaryFixed", "p", 90 }, { "primaryFixedDim", "p", 80 },
        { "onPrimaryFixed", "p", 10 }, { "onPrimaryFixedVariant", "p", 30 },

        { "secondary", "s", 40 }, { "onSecondary", "s", 100 }, { "secondaryContainer", "s", 90 },
        { "onSecondaryContainer", "s", 10 }, { "secondaryDim", "s", 35 },
        { "secondaryFixed", "s", 90 }, { "secondaryFixedDim", "s", 80 },
        { "onSecondaryFixed", "s", 10 }, { "onSecondaryFixedVariant", "s", 30 },

        { "tertiary", "t", 40 }, { "onTertiary", "t", 100 }, { "tertiaryContainer", "t", 90 },
        { "onTertiaryContainer", "t", 10 }, { "tertiaryDim", "t", 35 },
        { "tertiaryFixed", "t", 90 }, { "tertiaryFixedDim", "t", 80 },
        { "onTertiaryFixed", "t", 10 }, { "onTertiaryFixedVariant", "t", 30 },

        { "error", "e", 40 }, { "onError", "e", 100 }, { "errorContainer", "e", 90 },
        { "onErrorContainer", "e", 10 }, { "errorDim", "e", 30 },

        { "background", "n", 98 }, { "onBackground", "n", 10 },
        { "surface", "n", 98 }, { "onSurface", "n", 10 },
        { "surfaceDim", "n", 87 }, { "surfaceBright", "n", 98 },
        { "surfaceContainerLowest", "n", 100 }, { "surfaceContainerLow", "n", 96 },
        { "surfaceContainer", "n", 94 }, { "surfaceContainerHigh", "n", 92 },
        { "surfaceContainerHighest", "n", 90 },
        { "surfaceVariant", "nv", 90 }, { "onSurfaceVariant", "nv", 30 },
        { "outline", "nv", 50 }, { "outlineVariant", "nv", 80 },
        { "inverseSurface", "n", 20 }, { "inverseOnSurface", "n", 95 },
        { "shadow", "n", 0 }, { "scrim", "n", 0 },
        { "surfaceTint", "p", 40 },
    },
    dark = {
        { "primary", "p", 80 }, { "onPrimary", "p", 20 }, { "primaryContainer", "p", 30 },
        { "onPrimaryContainer", "p", 90 }, { "primaryDim", "p", 75 },
        { "inversePrimary", "p", 40 },
        { "primaryFixed", "p", 90 }, { "primaryFixedDim", "p", 80 },
        { "onPrimaryFixed", "p", 10 }, { "onPrimaryFixedVariant", "p", 30 },

        { "secondary", "s", 80 }, { "onSecondary", "s", 20 }, { "secondaryContainer", "s", 30 },
        { "onSecondaryContainer", "s", 90 }, { "secondaryDim", "s", 75 },
        { "secondaryFixed", "s", 90 }, { "secondaryFixedDim", "s", 80 },
        { "onSecondaryFixed", "s", 10 }, { "onSecondaryFixedVariant", "s", 30 },

        { "tertiary", "t", 80 }, { "onTertiary", "t", 20 }, { "tertiaryContainer", "t", 30 },
        { "onTertiaryContainer", "t", 90 }, { "tertiaryDim", "t", 75 },
        { "tertiaryFixed", "t", 90 }, { "tertiaryFixedDim", "t", 80 },
        { "onTertiaryFixed", "t", 10 }, { "onTertiaryFixedVariant", "t", 30 },

        { "error", "e", 80 }, { "onError", "e", 20 }, { "errorContainer", "e", 30 },
        { "onErrorContainer", "e", 90 }, { "errorDim", "e", 70 },

        { "background", "n", 6 }, { "onBackground", "n", 90 },
        { "surface", "n", 6 }, { "onSurface", "n", 90 },
        { "surfaceDim", "n", 6 }, { "surfaceBright", "n", 24 },
        { "surfaceContainerLowest", "n", 4 }, { "surfaceContainerLow", "n", 10 },
        { "surfaceContainer", "n", 12 }, { "surfaceContainerHigh", "n", 17 },
        { "surfaceContainerHighest", "n", 22 },
        { "surfaceVariant", "nv", 30 }, { "onSurfaceVariant", "nv", 80 },
        { "outline", "nv", 60 }, { "outlineVariant", "nv", 30 },
        { "inverseSurface", "n", 90 }, { "inverseOnSurface", "n", 20 },
        { "shadow", "n", 0 }, { "scrim", "n", 0 },
        { "surfaceTint", "p", 80 },
    },
}

--------------------------------------------------------------------------
-- Helpers operate on {h, c, t}
--------------------------------------------------------------------------

local function to_hct(hex)
    local r, g, b = C.from_hex(hex)
    local h, c, t = C.hct_from_rgb(r, g, b)
    return { h, c, t }
end

local function to_hex(hct)
    return C.hex_from_hct(hct[1], hct[2], hct[3])
end

local function lighten(hct, amount)
    local diff = (100 - hct[3]) * amount
    return { hct[1], hct[2] + diff / 5, hct[3] + diff }
end

local function darken(hct, amount)
    local diff = hct[3] * amount
    return { hct[1], hct[2] - diff / 5, hct[3] - diff }
end

local function mix(a, b, w)
    return to_hct(C.blend(to_hex(a), to_hex(b), w))
end

local function differ(a, b)
    return 180 - abs(abs(a - b) - 180)
end

local function harmonize(from, to, tone_boost)
    local delta = (to[1] - from[1] + 540) % 360 - 180
    local direction = delta >= 0 and 1 or -1
    local hue = (from[1] + min(differ(from[1], to[1]) * 0.8, 100) * direction) % 360
    return { hue, from[2], from[3] * (1 + tone_boost) }
end

local function grayscale(hct, light)
    local v = light and darken(hct, 0.35) or lighten(hct, 0.65)
    return { v[1], 0, v[3] }
end

--------------------------------------------------------------------------
-- The fixed palettes that get harmonised (public: gruvbox, catppuccin)
--------------------------------------------------------------------------

local light_gruvbox = {
    "FDF9F3", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034",
    "121212", "FF6188", "A9DC76", "FC9867", "FFD866", "F47FD4", "78DCE8", "333034",
}
local dark_gruvbox = {
    "282828", "CC241D", "98971A", "D79921", "458588", "B16286", "689D6A", "A89984",
    "928374", "FB4934", "B8BB26", "FABD2F", "83A598", "D3869B", "8EC07C", "EBDBB2",
}

local light_catppuccin = {
    "dc8a78", "dd7878", "ea76cb", "8839ef", "d20f39", "e64553", "fe640b",
    "df8e1d", "40a02b", "179299", "04a5e5", "209fb5", "1e66f5", "7287fd",
}
local dark_catppuccin = {
    "f5e0dc", "f2cdcd", "f5c2e7", "cba6f7", "f38ba8", "eba0ac", "fab387",
    "f9e2af", "a6e3a1", "94e2d5", "89dceb", "74c7ec", "89b4fa", "b4befe",
}

local colour_names = {
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
}

local kcolours = {
    { "klink", "2980b9" },
    { "kvisited", "9b59b6" },
    { "knegative", "da4453" },
    { "kneutral", "f67400" },
    { "kpositive", "27ae60" },
}

--------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------

-- seed: {h, c}; mode: "light" | "dark"; variant: a key of variants
function M.build(seed_h, seed_c, mode, variant)
    variant = variants[variant] and variant or "tonalspot"
    local light = mode == "light"
    local pal = palettes(seed_h, seed_c, variant)
    local colours = {}

    local function put(name, hct)
        colours[name] = to_hex(hct)
    end

    for _, role in ipairs(roles[mode]) do
        local p = pal[role[2]]
        put(role[1], { p[1], p[2], role[3] })
    end

    -- Palette key colours: the tone-50 swatch each ramp is built around.
    put("primaryPaletteKeyColor", { pal.p[1], pal.p[2], 50 })
    put("secondaryPaletteKeyColor", { pal.s[1], pal.s[2], 50 })
    put("tertiaryPaletteKeyColor", { pal.t[1], pal.t[2], 50 })
    put("neutralPaletteKeyColor", { pal.n[1], pal.n[2], 50 })
    put("neutralVariantPaletteKeyColor", { pal.nv[1], pal.nv[2], 50 })
    put("errorPaletteKeyColor", { pal.e[1], pal.e[2], 50 })

    -- Older spelling of the same keys, still read by some templates.
    for _, name in ipairs({ "primary", "secondary", "tertiary", "neutral" }) do
        colours[name .. "_paletteKeyColor"] = colours[name .. "PaletteKeyColor"]
    end
    colours.neutral_variant_paletteKeyColor = colours.neutralVariantPaletteKeyColor

    -- Terminal ramp: gruvbox, bent towards the wallpaper's primary hue.
    local gruvbox = light and light_gruvbox or dark_gruvbox
    for i = 1, 16 do
        local hct = to_hct(gruvbox[i])
        if variant == "monochrome" then
            hct = grayscale(hct, light)
        else
            local boost = (i <= 8 and 0.35 or 0.2) * (light and -1 or 1)
            hct = harmonize(hct, to_hct(colours.primaryPaletteKeyColor), boost)
        end
        put("term" .. (i - 1), hct)
    end

    -- Named accents.
    local catppuccin = light and light_catppuccin or dark_catppuccin
    for i, name in ipairs(colour_names) do
        local hct = to_hct(catppuccin[i])
        if variant == "monochrome" then
            hct = grayscale(hct, light)
        else
            hct = harmonize(hct, to_hct(colours.primaryPaletteKeyColor), light and -0.2 or 0.05)
        end
        put(name, hct)
    end

    -- KDE's link/visited/negative/neutral/positive pairs.
    for _, entry in ipairs(kcolours) do
        local base = harmonize(to_hct(entry[2]), to_hct(colours.primary), 0.1)
        local sel = harmonize(to_hct(entry[2]), to_hct(colours.onPrimaryFixedVariant), 0.1)
        if variant == "monochrome" then
            base = grayscale(base, light)
            sel = grayscale(sel, light)
        end
        put(entry[1], base)
        put(entry[1] .. "Selection", sel)
    end

    -- Deprecated names the shell and old templates still ask for.
    colours.text = colours.onBackground
    colours.subtext1 = colours.onSurfaceVariant
    colours.subtext0 = colours.outline
    colours.overlay2 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.86))
    colours.overlay1 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.71))
    colours.overlay0 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.57))
    colours.surface2 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.43))
    colours.surface1 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.29))
    colours.surface0 = to_hex(mix(to_hct(colours.surface), to_hct(colours.outline), 0.14))
    colours.base = colours.surface
    colours.mantle = to_hex(darken(to_hct(colours.surface), 0.03))
    colours.crust = to_hex(darken(to_hct(colours.surface), 0.05))

    if light then
        colours.success = "4F6354"
        colours.onSuccess = "FFFFFF"
        colours.successContainer = "D1E8D5"
        colours.onSuccessContainer = "0C1F13"
    else
        colours.success = "B5CCBA"
        colours.onSuccess = "213528"
        colours.successContainer = "374B3E"
        colours.onSuccessContainer = "D1E9D6"
    end

    return {
        name = "dynamic",
        flavour = "default",
        mode = mode,
        variant = variant,
        colours = colours,
    }
end

return M
