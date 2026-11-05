-- Colour maths for padilha-theme.
--
-- sRGB ↔ CIE XYZ (D65) ↔ CAM16, and HCT on top: hue and chroma from CAM16,
-- tone from CIE L*. The algorithm is the one Material Color Utilities
-- describes (Apache-2.0); this is our own Lua implementation of it, and
-- tests/theme/check-colour.py holds it to the reference numbers.
--
-- Conventions: RGB components are 0..255, linear RGB and XYZ are 0..100,
-- hue is degrees, chroma is CAM16 colourfulness, tone is L* (0..100).

local M = {}

local sqrt, log, exp = math.sqrt, math.log, math.exp
local pow = function(a, b)
    return a ^ b
end
local abs, min, max, pi = math.abs, math.min, math.max, math.pi
local cos, sin = math.cos, math.sin
local atan2 = function(y, x)
    return math.atan(y, x)
end

-- sRGB (D65)
M.white_point = { 95.047, 100.0, 108.883 }

local SRGB_TO_XYZ = {
    { 0.41233895, 0.35762064, 0.18051042 },
    { 0.2126, 0.7152, 0.0722 },
    { 0.01932141, 0.11916382, 0.95034478 },
}

local XYZ_TO_SRGB = {
    { 3.2413774792388685, -1.5376652402851851, -0.49885366846268053 },
    { -0.9691452513005321, 1.8758853451067872, 0.04156585616912061 },
    { 0.05562093689691305, -0.20395524564742123, 1.0571799111220335 },
}

local function mul(m, x, y, z)
    return m[1][1] * x + m[1][2] * y + m[1][3] * z, m[2][1] * x + m[2][2] * y + m[2][3] * z,
        m[3][1] * x + m[3][2] * y + m[3][3] * z
end

function M.linearize(c)
    local n = c / 255
    if n <= 0.040449936 then
        return n / 12.92 * 100
    end
    return pow((n + 0.055) / 1.055, 2.4) * 100
end

function M.delinearize(v)
    local n = v / 100
    local s
    if n <= 0.0031308 then
        s = n * 12.92
    else
        s = 1.055 * pow(n, 1 / 2.4) - 0.055
    end
    return min(255, max(0, math.floor(s * 255 + 0.5)))
end

function M.xyz_from_rgb(r, g, b)
    return mul(SRGB_TO_XYZ, M.linearize(r), M.linearize(g), M.linearize(b))
end

function M.rgb_from_xyz(x, y, z)
    local lr, lg, lb = mul(XYZ_TO_SRGB, x, y, z)
    return M.delinearize(lr), M.delinearize(lg), M.delinearize(lb)
end

-- CIE L*
local function lab_f(t)
    local e, kappa = 216 / 24389, 24389 / 27
    if t > e then
        return pow(t, 1 / 3)
    end
    return (kappa * t + 16) / 116
end

local function lab_invf(ft)
    local e, kappa = 216 / 24389, 24389 / 27
    local ft3 = ft * ft * ft
    if ft3 > e then
        return ft3
    end
    return (116 * ft - 16) / kappa
end

function M.y_from_lstar(lstar)
    return 100 * lab_invf((lstar + 16) / 116)
end

function M.lstar_from_y(y)
    return lab_f(y / 100) * 116 - 16
end

function M.lstar_from_rgb(r, g, b)
    local _, y = M.xyz_from_rgb(r, g, b)
    return M.lstar_from_y(y)
end

--------------------------------------------------------------------------
-- Viewing conditions
--------------------------------------------------------------------------

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function make_viewing_conditions()
    local wp = M.white_point
    local r_w = wp[1] * 0.401288 + wp[2] * 0.650173 + wp[3] * -0.051461
    local g_w = wp[1] * -0.250268 + wp[2] * 1.204414 + wp[3] * 0.045854
    local b_w = wp[1] * -0.002079 + wp[2] * 0.048952 + wp[3] * 0.953127

    local adapting_luminance = (200 / pi) * M.y_from_lstar(50) / 100
    local surround, background_lstar = 2.0, 50.0

    local f = 0.8 + surround / 10
    local c = f >= 0.9 and lerp(0.59, 0.69, (f - 0.9) * 10) or lerp(0.525, 0.59, (f - 0.8) * 10)
    local d = f * (1 - (1 / 3.6) * exp((-adapting_luminance - 42) / 92))
    d = min(1, max(0, d))
    local nc = f

    local rgb_d = {
        d * (100 / r_w) + 1 - d,
        d * (100 / g_w) + 1 - d,
        d * (100 / b_w) + 1 - d,
    }

    local k = 1 / (5 * adapting_luminance + 1)
    local k4 = k * k * k * k
    local k4_f = 1 - k4
    local fl = k4 * adapting_luminance + 0.1 * k4_f * k4_f * pow(5 * adapting_luminance, 1 / 3)

    local n = M.y_from_lstar(background_lstar) / wp[2]
    local z = 1.48 + sqrt(n)
    local nbb = 0.725 / pow(n, 0.2)
    local ncb = nbb

    local factors = {
        pow((fl * rgb_d[1] * r_w) / 100, 0.42),
        pow((fl * rgb_d[2] * g_w) / 100, 0.42),
        pow((fl * rgb_d[3] * b_w) / 100, 0.42),
    }
    local rgb_a = {
        (400 * factors[1]) / (factors[1] + 27.13),
        (400 * factors[2]) / (factors[2] + 27.13),
        (400 * factors[3]) / (factors[3] + 27.13),
    }
    local aw = (2 * rgb_a[1] + rgb_a[2] + 0.05 * rgb_a[3]) * nbb

    return {
        n = n,
        aw = aw,
        nbb = nbb,
        ncb = ncb,
        c = c,
        nc = nc,
        rgb_d = rgb_d,
        fl = fl,
        f_l_root = pow(fl, 0.25),
        z = z,
    }
end

M.vc = make_viewing_conditions()

--------------------------------------------------------------------------
-- CAM16
--------------------------------------------------------------------------

local function signum(x)
    if x < 0 then
        return -1
    elseif x > 0 then
        return 1
    end
    return 0
end

local function sanitize_degrees(d)
    d = d % 360
    return d
end

-- XYZ -> CAM16 { hue, chroma, j }
function M.cam16_from_xyz(x, y, z, vc)
    vc = vc or M.vc
    local r_c = 0.401288 * x + 0.650173 * y - 0.051461 * z
    local g_c = -0.250268 * x + 1.204414 * y + 0.045854 * z
    local b_c = -0.002079 * x + 0.048952 * y + 0.953127 * z

    local r_d = vc.rgb_d[1] * r_c
    local g_d = vc.rgb_d[2] * g_c
    local b_d = vc.rgb_d[3] * b_c

    local r_af = pow((vc.fl * abs(r_d)) / 100, 0.42)
    local g_af = pow((vc.fl * abs(g_d)) / 100, 0.42)
    local b_af = pow((vc.fl * abs(b_d)) / 100, 0.42)

    local r_a = (signum(r_d) * 400 * r_af) / (r_af + 27.13)
    local g_a = (signum(g_d) * 400 * g_af) / (g_af + 27.13)
    local b_a = (signum(b_d) * 400 * b_af) / (b_af + 27.13)

    local a = (11 * r_a - 12 * g_a + b_a) / 11
    local b = (r_a + g_a - 2 * b_a) / 9
    local u = (20 * r_a + 20 * g_a + 21 * b_a) / 20
    local p2 = (40 * r_a + 20 * g_a + b_a) / 20

    local hue = sanitize_degrees(atan2(b, a) * 180 / pi)
    local ac = p2 * vc.nbb
    local j = 100 * pow(ac / vc.aw, vc.c * vc.z)

    local hue_prime = hue < 20.14 and hue + 360 or hue
    local e_hue = 0.25 * (cos(hue_prime * pi / 180 + 2) + 3.8)
    local p1 = (50000 / 13) * e_hue * vc.nc * vc.ncb
    local t = (p1 * sqrt(a * a + b * b)) / (u + 0.305)
    local alpha = pow(t, 0.9) * pow(1.64 - pow(0.29, vc.n), 0.73)
    local chroma = alpha * sqrt(j / 100)

    return { hue = hue, chroma = chroma, j = j }
end

-- CAM16 (j, chroma, hue) -> XYZ
function M.xyz_from_cam16(j, chroma, hue, vc)
    vc = vc or M.vc
    if j <= 0 then
        return 0, 0, 0
    end
    local alpha = chroma <= 0 and 0 or chroma / sqrt(j / 100)
    local t = alpha == 0 and 0 or pow(alpha / pow(1.64 - pow(0.29, vc.n), 0.73), 1 / 0.9)
    local h_rad = hue * pi / 180

    local e_hue = 0.25 * (cos(h_rad + 2) + 3.8)
    local ac = vc.aw * pow(j / 100, 1 / vc.c / vc.z)
    local p1 = e_hue * (50000 / 13) * vc.nc * vc.ncb
    local p2 = ac / vc.nbb

    local h_sin, h_cos = sin(h_rad), cos(h_rad)
    local gamma = 23 * (p2 + 0.305) * t / (23 * p1 + 11 * t * h_cos + 108 * t * h_sin)
    local a = gamma * h_cos
    local b = gamma * h_sin

    local r_a = (460 * p2 + 451 * a + 288 * b) / 1403
    local g_a = (460 * p2 - 891 * a - 261 * b) / 1403
    local b_a = (460 * p2 - 220 * a - 6300 * b) / 1403

    local function unadapt(aa)
        local base = max(0, (27.13 * abs(aa)) / (400 - abs(aa)))
        return signum(aa) * (100 / vc.fl) * pow(base, 1 / 0.42)
    end

    local r_f = unadapt(r_a) / vc.rgb_d[1]
    local g_f = unadapt(g_a) / vc.rgb_d[2]
    local b_f = unadapt(b_a) / vc.rgb_d[3]

    return 1.86206786 * r_f - 1.01125463 * g_f + 0.14918677 * b_f,
        0.38752654 * r_f + 0.62144744 * g_f - 0.00897398 * b_f,
        -0.01584150 * r_f - 0.03412294 * g_f + 1.04996444 * b_f
end

--------------------------------------------------------------------------
-- HCT
--------------------------------------------------------------------------

-- RGB -> { h, c, t }
function M.hct_from_rgb(r, g, b)
    local x, y, z = M.xyz_from_rgb(r, g, b)
    local cam = M.cam16_from_xyz(x, y, z)
    return cam.hue, cam.chroma, M.lstar_from_y(y)
end

local function in_gamut(x, y, z)
    local lr, lg, lb = mul(XYZ_TO_SRGB, x, y, z)
    return lr >= -0.001 and lr <= 100.001 and lg >= -0.001 and lg <= 100.001 and lb >= -0.001 and lb <= 100.001
end

-- Reduce chroma until the colour at this tone fits in sRGB.
local function clamp_chroma(hue, chroma, y_target)
    if chroma <= 0 then
        return 0
    end
    local function fits(c)
        -- J at the tone boundary is found by the caller; here approximate with
        -- the same J search so the gamut test is honest.
        local j
        local lo, hi = 0, 100
        for _ = 1, 24 do
            j = (lo + hi) / 2
            local _, yy = M.xyz_from_cam16(j, c, hue)
            if yy < y_target then
                lo = j
            else
                hi = j
            end
        end
        local x, y, z = M.xyz_from_cam16(j, c, hue)
        return in_gamut(x, y, z)
    end
    if fits(chroma) then
        return chroma
    end
    local lo, hi = 0, chroma
    for _ = 1, 24 do
        local mid = (lo + hi) / 2
        if fits(mid) then
            lo = mid
        else
            hi = mid
        end
    end
    return lo
end

-- HCT (h, c, t) -> r, g, b
function M.rgb_from_hct(hue, chroma, tone)
    local y_target = M.y_from_lstar(tone)
    if tone <= 0 then
        return 0, 0, 0
    end
    if tone >= 100 then
        return 255, 255, 255
    end

    chroma = clamp_chroma(hue, max(0, chroma), y_target)

    -- Fix hue and chroma, bisect J until Y matches the tone.
    local lo, hi = 0, 100
    local j = lo
    for _ = 1, 32 do
        j = (lo + hi) / 2
        local _, y = M.xyz_from_cam16(j, chroma, hue)
        if y < y_target then
            lo = j
        else
            hi = j
        end
    end
    local x, y, z = M.xyz_from_cam16((lo + hi) / 2, chroma, hue)
    return M.rgb_from_xyz(x, y, z)
end

--------------------------------------------------------------------------
-- CAM16-UCS, for blends and harmonisation
--------------------------------------------------------------------------

function M.ucs_from_xyz(x, y, z, vc)
    vc = vc or M.vc
    local cam = M.cam16_from_xyz(x, y, z, vc)
    local m = cam.chroma * vc.f_l_root
    local mstar = (1 / 0.0228) * log(1 + 0.0228 * m)
    local jstar = ((1 + 100 * 0.007) * cam.j) / (1 + 0.007 * cam.j)
    local rad = cam.hue * pi / 180
    return jstar, mstar * cos(rad), mstar * sin(rad)
end

function M.xyz_from_ucs(jstar, astar, bstar, vc)
    vc = vc or M.vc
    local m = sqrt(astar * astar + bstar * bstar)
    local big_m = (exp(m * 0.0228) - 1) / 0.0228
    local chroma = big_m / vc.f_l_root
    local hue = atan2(bstar, astar) * 180 / pi
    if hue < 0 then
        hue = hue + 360
    end
    local j = jstar / (1 - (jstar - 100) * 0.007)
    return M.xyz_from_cam16(j, chroma, hue, vc)
end

-- Blend two colours in CAM16-UCS: ratio 0 gives `a`, 1 gives `b`.
function M.blend(a, b, ratio)
    local ar, ag, ab = M.from_hex(a)
    local br, bg, bb = M.from_hex(b)
    local j1, a1, b1 = M.ucs_from_xyz(M.xyz_from_rgb(ar, ag, ab))
    local j2, a2, b2 = M.ucs_from_xyz(M.xyz_from_rgb(br, bg, bb))
    local x, y, z = M.xyz_from_ucs(j1 + (j2 - j1) * ratio, a1 + (a2 - a1) * ratio, b1 + (b2 - b1) * ratio)
    return M.to_hex(M.rgb_from_xyz(x, y, z))
end

--------------------------------------------------------------------------
-- Hex helpers
--------------------------------------------------------------------------

function M.to_hex(r, g, b)
    return string.format("%02x%02x%02x", r, g, b)
end

function M.from_hex(hex)
    hex = hex:gsub("^#", "")
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

function M.hct_from_hex(hex)
    return M.hct_from_rgb(M.from_hex(hex))
end

function M.hex_from_hct(h, c, t)
    return M.to_hex(M.rgb_from_hct(h, c, t))
end

return M
