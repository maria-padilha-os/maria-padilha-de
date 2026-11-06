-- Shared state for the commands that are not the theme engine itself:
-- which wallpaper is current, which variant was chosen, and what the shell
-- should paint. Kept out of apply.lua so the engine stays about rendering.

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

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local lib_dir = source:match("^(.*)/[^/]+$") or "."

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local tmp_counter = 0
local function tmp_path(path)
    tmp_counter = tmp_counter + 1
    local token = tostring({}):match("0x%x+") or tostring(os.time())
    return path .. ".tmp." .. token .. "." .. tmp_counter
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
    local tmp = tmp_path(variant_file)
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

--------------------------------------------------------------------------
-- Doctor: what the first real login will trip over
--------------------------------------------------------------------------

local function exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function dir_exists(path)
    return os.execute("test -d " .. quote(path)) == true
end

-- Match the shell: ~/.config/padilha if it exists, otherwise the old
-- ~/.config/lilith during the migration.
local function config_dir()
    local primary = M.config .. "/padilha"
    local legacy = M.config .. "/lilith"
    if dir_exists(primary) then
        return primary
    end
    if dir_exists(legacy) then
        return legacy
    end
    return primary
end

local function capture(cmd)
    local p = io.popen(cmd .. " 2>/dev/null")
    if not p then
        return nil
    end
    local text = p:read("*a")
    p:close()
    return text
end

local function lua_table(path)
    local chunk = loadfile(path)
    if not chunk then
        return nil
    end
    local ok, value = pcall(chunk)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

-- The daylight window belongs to share/defaults.lua and the user's
-- daylight.lua; doctor must not carry a second, stale copy of 06:00/18:00.
local function daylight_hours()
    local merged = {}
    for _, path in ipairs({
        lib_dir .. "/../share/defaults.lua",
        config_dir() .. "/daylight.lua",
    }) do
        for key, value in pairs(lua_table(path) or {}) do
            merged[key] = value
        end
    end

    local day_start = tonumber(merged.day_start) or 6
    local night_start = tonumber(merged.night_start) or 18
    if day_start < 0 or day_start > 23 or night_start < 0 or night_start > 23 or night_start <= day_start then
        return 6, 18
    end
    return day_start, night_start
end

local function size(path)
    local text = capture("stat -c %s -- " .. quote(path))
    return text and tonumber(text) or nil
end

-- Returns a list of { level, name, detail }; level is "ok", "warn" or "fail".
function M.diagnostics()
    local out = {}
    local function add(level, name, detail)
        out[#out + 1] = { level = level, name = name, detail = detail or "" }
    end

    -- Tools the theme and the session need.
    for _, tool in ipairs({ "magick", "qs", "hyprctl", "notify-send" }) do
        if capture("command -v " .. tool) then
            add("ok", tool, "on PATH")
        else
            add("fail", tool, "missing from PATH")
        end
    end
    if capture("command -v sass") then
        add("ok", "sass", "Discord themes will compile")
    else
        add("warn", "sass", "missing: Discord clients keep their old theme")
    end

    -- The state directory is where the palette and the wallpaper live.
    local probe = state_dir .. "/.doctor"
    local f = io.open(probe, "wb")
    if f then
        f:close()
        os.remove(probe)
        add("ok", "state directory", state_dir .. " is writable")
    else
        add("fail", "state directory", state_dir .. " is not writable")
    end

    local wallpaper = M.current_wallpaper()
    if not wallpaper then
        add("warn", "wallpaper", "none set; padilha-daylight will pick one at login")
    elseif not exists(wallpaper) then
        add("fail", "wallpaper", wallpaper .. " does not exist")
    else
        add("ok", "wallpaper", wallpaper)
    end

    local scheme = state_dir .. "/scheme.json"
    local scheme_size = size(scheme)
    if not scheme_size then
        add("fail", "scheme.json", "missing; run padilha-daylight --once")
    elseif scheme_size < 2000 then
        add("fail", "scheme.json", ("only %d bytes; looks truncated"):format(scheme_size))
    else
        add("ok", "scheme.json", ("%d bytes, variant %s"):format(scheme_size, M.variant()))
    end

    local wall_variant = M.variant()
    local known = false
    for _, v in ipairs(schememod.variants) do
        if v == wall_variant then
            known = true
        end
    end
    if known then
        add("ok", "variant", wall_variant)
    else
        add("fail", "variant", wall_variant .. " is not a variant the engine knows")
    end

    -- Config: compiled file plus the merge baseline.
    local shell = config_dir() .. "/shell.json"
    if exists(shell) then
        add("ok", "shell.json", shell)
    else
        add("warn", "shell.json", "not compiled yet; padilha-session does it at login")
    end
    if exists(shell .. ".base") then
        add("ok", "merge baseline", "settings-UI edits will be carried")
    else
        add("warn", "merge baseline", "no baseline yet: the first compile takes init.lua as truth")
    end

    -- Theme outputs, one sample from each family.
    for _, pair in ipairs({
        { "Hyprland colours", M.config .. "/hypr/scheme/current.lua" },
        { "GTK colours", M.config .. "/gtk-3.0/gtk.css" },
    }) do
        if exists(pair[2]) then
            add("ok", pair[1], pair[2])
        else
            add("warn", pair[1], "missing: run padilha-theme apply")
        end
    end

    -- The compositor we are talking to, against our pin.
    local signature = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature then
        add("warn", "Hyprland", "not running in this environment")
    else
        local version = capture("hyprctl version | head -n 1")
        local pin_file = io.open(lib_dir .. "/../upstream.json", "r")
        local pinned
        if pin_file then
            local pins = pin_file:read("*a")
            pin_file:close()
            pinned = pins:match('"hyprland"%s*:[%s%S]-"pin"%s*:%s*"v([^"]+)"')
        end
        local running = version and version:match("Hyprland ([0-9.]+)")
        if running and pinned and running ~= pinned then
            add("warn", "Hyprland", ("running %s, pinned %s"):format(running, pinned))
        elseif running then
            add("ok", "Hyprland", running)
        else
            add("ok", "Hyprland", "running")
        end
    end

    -- The clock: is the palette for the period we are actually in?
    local period = io.open(state_dir .. "/daylight.period", "r")
    local saved
    if period then
        saved = period:read("*l")
        period:close()
    end
    local hour = tonumber(os.date("%H"))
    local day_start, night_start = daylight_hours()
    local want = (hour >= day_start and hour < night_start) and "day" or "night"
    if saved == want then
        add("ok", "daylight", "period is " .. want)
    elseif saved then
        add("warn", "daylight", ("period is %s but the clock says %s; run padilha-daylight --once"):format(saved, want))
    else
        add("warn", "daylight", "has not run yet; run padilha-daylight --once")
    end

    return out
end

return M
