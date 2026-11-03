-- Reads cases on stdin and prints padilha-theme's colour maths:
--   hex RRGGBB      -> "hue chroma tone hex"
--   hct H C T       -> "hex"
local root = arg[1] or "."
package.path = root .. "/lib/?.lua;" .. package.path
local C = require("colour")

for line in io.lines() do
    local kind, a, b, c = line:match("^(%a+)%s+(%S+)%s*(%S*)%s*(%S*)$")
    if kind == "hex" then
        local r, g, bl = C.from_hex(a)
        local h, ch, t = C.hct_from_rgb(r, g, bl)
        print(string.format("%.4f %.4f %.4f %s", h, ch, t, C.hex_from_hct(h, ch, t)))
    elseif kind == "hct" then
        print(C.hex_from_hct(tonumber(a), tonumber(b), tonumber(c)))
    end
end
