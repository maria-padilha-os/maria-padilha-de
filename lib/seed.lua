-- Pick the colour a wallpaper should be built from.
--
-- ImageMagick does the decoding and the palette reduction; the interesting
-- part — which of those pixel populations deserves to be the seed — is
-- Material's score: hue excitement first, then chroma, with a nudge towards
-- colours that are present but not necessarily dominant. A mostly-black
-- wallpaper with a red candelabra should come out red, not black.

local C = require("colour")

local M = {}

local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function quote(s)
    return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function run(cmd)
    local p = io.popen(cmd)
    if not p then
        return nil
    end
    local out = p:read("*a")
    p:close()
    return out
end

-- [{ hex = "rrggbb", count = n }], most common first
function M.histogram(path, colours)
    colours = colours or 128
    local cmd = string.format("magick %s -resize 128x128 -filter point -colors %d -format %%c histogram:info:- 2>/dev/null",
        shell_quote(path), colours)
    local out = run(cmd)
    if not out or out == "" then
        return nil, "could not read " .. path
    end

    local list = {}
    for line in out:gmatch("[^\n]+") do
        local count = line:match("^%s*(%d+):")
        local hex = line:match("#(%x%x%x%x%x%x)")
        if count and hex then
            list[#list + 1] = { hex = hex:lower(), count = tonumber(count) }
        end
    end
    if #list == 0 then
        return nil, "no colours in " .. path
    end
    return list
end

-- Average colour and colourfulness from a downscaled image.
local function measure(path)
    local cmd = string.format("magick %s -resize 64x64! -depth 8 txt:- 2>/dev/null", shell_quote(path))
    local out = run(cmd)
    if not out then
        return nil
    end

    local n, sr, sg, sb = 0, 0, 0, 0
    local rg, yb = {}, {}
    for line in out:gmatch("[^\n]+") do
        local hex = line:match("#(%x%x%x%x%x%x)")
        if hex then
            local r, g, b = C.from_hex(hex)
            n = n + 1
            sr, sg, sb = sr + r, sg + g, sb + b
            rg[n] = r - g
            yb[n] = 0.5 * (r + g) - b
        end
    end
    if n == 0 then
        return nil
    end

    local mean_rg, mean_yb = 0, 0
    for i = 1, n do
        mean_rg, mean_yb = mean_rg + rg[i], mean_yb + yb[i]
    end
    mean_rg, mean_yb = mean_rg / n, mean_yb / n

    local var_rg, var_yb = 0, 0
    for i = 1, n do
        var_rg = var_rg + (rg[i] - mean_rg) ^ 2
        var_yb = var_yb + (yb[i] - mean_yb) ^ 2
    end
    var_rg, var_yb = var_rg / n, var_yb / n

    local colourfulness = math.sqrt(var_rg + var_yb) + 0.3 * math.sqrt(mean_rg ^ 2 + mean_yb ^ 2)
    return {
        r = sr / n,
        g = sg / n,
        b = sb / n,
        colourfulness = colourfulness,
    }
end

--------------------------------------------------------------------------
-- Material's score
--------------------------------------------------------------------------

local TARGET_CHROMA = 48
local WEIGHT_PROPORTION = 0.7
local WEIGHT_CHROMA_ABOVE = 0.3
local WEIGHT_CHROMA_BELOW = 0.1

local function sanitize(h)
    return h % 360
end

-- list of {hex, count} -> {h, c, t} of the most "interesting" colour
function M.score(list)
    local hues, populations, population_sum = {}, {}, 0
    local entries = {}

    for _, entry in ipairs(list) do
        local r, g, b = C.from_hex(entry.hex)
        local h, c, t = C.hct_from_rgb(r, g, b)
        local hue = math.floor(sanitize(h))
        hues[#hues + 1] = hue
        populations[#populations + 1] = entry.count
        population_sum = population_sum + entry.count
        entries[#entries + 1] = { h = h, c = c, t = t, hue = hue, count = entry.count }
    end

    if population_sum == 0 then
        return nil
    end

    local hue_population = {}
    for i = 1, 360 do
        hue_population[i] = 0
    end
    for i, hue in ipairs(hues) do
        hue_population[hue + 1] = hue_population[hue + 1] + populations[i]
    end

    local excited = {}
    for i = 1, 360 do
        excited[i] = 0
    end
    for hue = 0, 359 do
        local proportion = hue_population[hue + 1] / population_sum
        for d = -14, 15 do
            local n = math.floor(sanitize(hue + d))
            excited[n + 1] = excited[n + 1] + proportion
        end
    end

    for _, e in ipairs(entries) do
        local proportion = excited[e.hue + 1]
        local chroma_weight = e.c < TARGET_CHROMA and WEIGHT_CHROMA_BELOW or WEIGHT_CHROMA_ABOVE
        e.score = proportion * 100 * WEIGHT_PROPORTION + (e.c - TARGET_CHROMA) * chroma_weight
    end
    table.sort(entries, function(a, b)
        return a.score > b.score
    end)

    local primary
    for cutoff = 20, 0, -1 do
        for _, e in ipairs(entries) do
            if e.c > cutoff and e.t > cutoff * 3 then
                primary = e
                break
            end
        end
        if primary then
            break
        end
    end
    primary = primary or entries[1]

    return { h = primary.h, c = primary.c, t = primary.t }
end

-- path -> { mode = "light"|"dark", variant = "...", seed = {h, c}, hex = "rrggbb" }
function M.from_wallpaper(path)
    local list, err = M.histogram(path)
    if not list then
        return nil, err
    end

    local seed = M.score(list)
    if not seed then
        return nil, "could not score " .. path
    end

    local m = measure(path) or { r = 0, g = 0, b = 0, colourfulness = 0 }
    local mode = C.lstar_from_rgb(m.r, m.g, m.b) > 60 and "light" or "dark"
    local variant = "tonalspot"
    if m.colourfulness < 10 then
        variant = "neutral"
    elseif m.colourfulness < 20 then
        variant = "content"
    end

    return {
        mode = mode,
        variant = variant,
        seed = { h = seed.h, c = seed.c },
        seed_hex = string.format("%02x%02x%02x", C.rgb_from_hct(seed.h, seed.c, seed.t)),
    }
end

return M
