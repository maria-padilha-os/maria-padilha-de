-- Paired day/night themes.
--
-- A theme is two wallpapers: one for the light half of the day and one for
-- the dark half. The images are stored as absolute paths in
-- ~/.config/padilha/themes.json; the same file records which theme is active.
-- padilha-daylight resolves the active theme for the current period, and the
-- Nexus themes page manages the list through the `padilha theme` commands.

local json = require("json")

local M = {}

local home = os.getenv("HOME") or ""
M.config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
M.path = M.config .. "/padilha/themes.json"

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local lib_dir = source:match("^(.*)/[^/]+$") or "."
local root = lib_dir .. "/.."

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

local function load_raw()
    local text = read_file(M.path)
    if not text then
        return { themes = {}, active = "" }
    end
    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= "table" then
        return nil, "cannot parse " .. M.path
    end
    if type(data.themes) ~= "table" then
        data.themes = {}
    end
    if type(data.active) ~= "string" then
        data.active = ""
    end
    return data
end

local function save(data)
    os.execute("mkdir -p " .. quote(M.config .. "/padilha"))
    local tmp = M.path .. ".tmp"
    local f = io.open(tmp, "wb")
    if not f then
        return nil, "cannot write " .. tmp
    end
    f:write(json.encode(data))
    f:close()
    local ok, err = os.rename(tmp, M.path)
    if not ok then
        os.remove(tmp)
        return nil, err
    end
    return true
end

local function slug(name)
    local id = tostring(name or ""):lower():gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if id == "" then
        id = "theme"
    end
    return id
end

local function sorted_themes(data)
    local list = {}
    for id, theme in pairs(data.themes) do
        if type(theme) == "table" then
            list[#list + 1] = {
                id = id,
                name = theme.name or id,
                day = theme.day or "",
                night = theme.night or "",
            }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function M.list()
    local data, err = load_raw()
    if not data then
        return nil, err
    end
    return sorted_themes(data), data.active or ""
end

function M.get(theme_id)
    local data, err = load_raw()
    if not data then
        return nil, err
    end
    if type(theme_id) == "string" and theme_id ~= "" then
        local direct = data.themes[theme_id]
        if direct then
            return {
                id = theme_id,
                name = direct.name or theme_id,
                day = direct.day or "",
                night = direct.night or "",
            }
        end
        local wanted = theme_id:lower()
        for id, theme in pairs(data.themes) do
            if type(theme) == "table" and tostring(theme.name or id):lower() == wanted then
                return {
                    id = id,
                    name = theme.name or id,
                    day = theme.day or "",
                    night = theme.night or "",
                }
            end
        end
    end
    return nil, "theme not found: " .. tostring(theme_id)
end

function M.active()
    local data = load_raw()
    return data and data.active or ""
end

function M.set_active(theme_id)
    local data, err = load_raw()
    if not data then
        return nil, err
    end
    if theme_id and theme_id ~= "" then
        if not data.themes[theme_id] then
            return nil, "theme not found: " .. tostring(theme_id)
        end
        data.active = theme_id
    else
        data.active = ""
    end
    return save(data)
end

function M.add(name, day, night)
    if type(name) ~= "string" or name:match("^%s*$") then
        return nil, "theme needs a name"
    end
    if type(day) ~= "string" or type(night) ~= "string" or day == "" or night == "" then
        return nil, "theme needs a day image and a night image"
    end
    for _, field in ipairs({ day, night }) do
        local f = io.open(field, "rb")
        if not f then
            return nil, "cannot read image: " .. field
        end
        f:close()
    end

    local data, err = load_raw()
    if not data then
        return nil, err
    end

    local id = slug(name)
    local base = id
    local n = 2
    while data.themes[id] do
        id = base .. "-" .. n
        n = n + 1
    end
    data.themes[id] = {
        name = name,
        day = day,
        night = night,
    }
    local ok, save_err = save(data)
    if not ok then
        return nil, save_err
    end
    return id
end

function M.remove(theme_id)
    local data, err = load_raw()
    if not data then
        return nil, err
    end
    if not data.themes[theme_id] then
        return nil, "theme not found: " .. tostring(theme_id)
    end
    data.themes[theme_id] = nil
    if data.active == theme_id then
        data.active = ""
    end
    return save(data)
end

-- The scheduler's day/night boundary is shared with padilha-daylight, whose
-- user override lives in ~/.config/padilha/daylight.lua.
function M.period()
    local day_start, night_start = 6, 18
    local primary = M.config .. "/padilha/daylight.lua"
    local legacy = M.config .. "/lilith/daylight.lua"
    local user = primary
    local probe = io.open(primary, "rb")
    if probe then
        probe:close()
    else
        local legacy_probe = io.open(legacy, "rb")
        if legacy_probe then
            legacy_probe:close()
            user = legacy
        end
    end
    for _, path in ipairs({ root .. "/share/defaults.lua", user }) do
        local chunk = loadfile(path)
        if chunk then
            local ok, value = pcall(chunk)
            if ok and type(value) == "table" then
                day_start = tonumber(value.day_start) or day_start
                night_start = tonumber(value.night_start) or night_start
            end
        end
    end
    if day_start < 0 or day_start > 23 or night_start < 0 or night_start > 23 or night_start <= day_start then
        return "night"
    end
    local hour = tonumber(os.date("%H")) or 0
    return hour >= day_start and hour < night_start and "day" or "night"
end

function M.image_for(period)
    local data, err = load_raw()
    if not data then
        return nil, err
    end
    if data.active == "" then
        return nil, "no active theme"
    end
    local theme = data.themes[data.active]
    if type(theme) ~= "table" then
        return nil, "active theme is missing"
    end
    local image = period == "day" and theme.day or theme.night
    if type(image) ~= "string" or image == "" then
        return nil, "theme has no " .. period .. " image"
    end
    return image, data.active, theme
end

return M
