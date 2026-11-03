-- Shared state for the commands that are not the theme engine itself:
-- which wallpaper is current, which variant was chosen, and what the shell
-- should paint. Kept out of apply.lua so the engine stays about rendering.

local C = require("colour")
local seed = require("seed")
local schememod = require("scheme")
local applymod = require("apply")
local json = require("json")

local M = {}

local home = os.getenv("HOME") or ""
M.config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
M.state = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
M.pictures = os.getenv("XDG_PICTURES_DIR") or (home .. "/Pictures")

local state_dir = M.state .. "/caelestia"
local wall_dir = state_dir .. "/wallpaper"
local variant_file = state_dir .. "/theme.json"

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

function M.current_wallpaper()
    local text = read_file(wall_dir .. "/path.txt")
    if not text then
        return nil
    end
    local path = text:gsub("%s+$", "")
    if path == "" then
        return nil
    end
    return path
end

-- The variant is a user choice, so it lives in state, not in the image.
function M.variant()
    local text = read_file(variant_file)
    if text then
        local ok, value = pcall(function()
            -- theme.json is written by us and is tiny; avoid a JSON reader.
            return text:match('"variant"%s*:%s*"([%w]+)"')
        end)
        if ok and value then
            return value
        end
    end
    return "tonalspot"
end

function M.set_variant(variant)
    os.execute("mkdir -p " .. quote(state_dir))
    local tmp = variant_file .. ".tmp"
    local f = io.open(tmp, "wb")
    if not f then
        return false
    end
    f:write(json.encode({ variant = variant }))
    f:close()
    return os.rename(tmp, variant_file) == true
end

-- Everything needed to paint a wallpaper: the palette and how to apply it.
function M.describe(path, opts)
    opts = opts or {}
    local info, err = seed.from_wallpaper(path)
    if not info then
        return nil, err
    end
    local mode = opts.mode or info.mode
    local variant = opts.variant or M.variant()
    if not schememod.variants then
        return nil, "scheme module has no variants list"
    end
    local built = schememod.build(info.seed.h, info.seed.c, mode, variant)
    return built, info, variant
end

function M.set_wallpaper(path, opts)
    opts = opts or {}
    local built, info, variant = M.describe(path, opts)
    if not built then
        return nil, info
    end

    os.execute("mkdir -p " .. quote(wall_dir))
    local f = io.open(wall_dir .. "/path.txt", "wb")
    if not f then
        return nil, "cannot write the wallpaper state"
    end
    f:write(path, "\n")
    f:close()
    os.execute("ln -sfn " .. quote(path) .. " " .. quote(wall_dir .. "/current"))
    os.execute(string.format("magick %s -resize 480x270^ -gravity center -extent 480x270 -strip %s 2>/dev/null",
        quote(path), quote(wall_dir .. "/thumbnail.jpg")))

    if opts.variant then
        M.set_variant(opts.variant)
    end

    local written, errors = applymod.apply(built, { signals = true, broadcast = true })
    if #errors > 0 then
        return nil, table.concat(errors, "; ")
    end
    return built, #written, variant
end

return M
