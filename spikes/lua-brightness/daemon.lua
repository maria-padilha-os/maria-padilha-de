#!/usr/bin/env lua
-- Experimental Lua port of bin/padilha-brightness, dry-run by default.
--
-- It mirrors the Python daemon's state machine: poll the panel brightness,
-- detect a manual change and hold it for HOLD_HOURS, otherwise follow the
-- time-of-day curve.  With --write it calls brightnessctl; the dry run only
-- records what it would do.
--
-- Production would use lua-posix for sleep() and flock(); this spike uses
-- os.execute("sleep") and a directory lock so it can be tested without
-- installing anything.

local function env(name, fallback)
    local value = os.getenv(name)
    if value and value ~= "" then
        return value
    end
    return fallback
end

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local HOLD_HOURS = tonumber(env("PADILHA_BRIGHTNESS_HOLD_HOURS", env("LILITH_BRIGHTNESS_HOLD_HOURS", "4")))
local POLL_SECONDS = tonumber(env("PADILHA_BRIGHTNESS_POLL", "2"))
local BACKLIGHT_DIR = env("PADILHA_BACKLIGHT_DIR", "/sys/class/backlight")

local ANCHORS = {
    { 0, 15 },
    { 6 * 60, 20 },
    { 7 * 60 + 30, 70 },
    { 12 * 60, 100 },
    { 17 * 60, 85 },
    { 19 * 60, 55 },
    { 21 * 60, 30 },
    { 23 * 60, 20 },
    { 24 * 60, 15 },
}

local WRITE = false
local LOG_PATH = nil
local MAX_CYCLES = nil

-- Python's round() is half-to-even.
local function pyround(value)
    local lower = math.floor(value)
    local fraction = value - lower
    if fraction > 0.5 then
        return lower + 1
    elseif fraction < 0.5 then
        return lower
    elseif lower % 2 == 0 then
        return lower
    end
    return lower + 1
end

local function target_percent(epoch)
    local now = os.date("*t", epoch)
    local minutes = now.hour * 60 + now.min + now.sec / 60
    for index = 1, #ANCHORS - 1 do
        local m0, v0 = ANCHORS[index][1], ANCHORS[index][2]
        local m1, v1 = ANCHORS[index + 1][1], ANCHORS[index + 1][2]
        if m0 <= minutes and minutes <= m1 then
            local fraction = m1 > m0 and (minutes - m0) / (m1 - m0) or 0
            return pyround(v0 + (v1 - v0) * fraction)
        end
    end
    return ANCHORS[#ANCHORS][2]
end

local function state_path()
    local base = env("XDG_STATE_HOME", (os.getenv("HOME") or "") .. "/.local/state")
    local primary = base .. "/padilha/brightness.state"
    local legacy = base .. "/lilith/brightness.state"
    local file = io.open(primary, "r")
    if file then
        file:close()
        return primary
    end
    file = io.open(legacy, "r")
    if file then
        file:close()
        return legacy
    end
    return primary
end

local function dirname(path)
    return path:match("^(.*)/[^/]+$") or "."
end

local function read_number(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*l")
    file:close()
    return tonumber((text or ""):match("^%s*(-?%d+)%s*$") or "")
end

local function command_number(command)
    local pipe = io.popen(command .. " 2>/dev/null")
    if not pipe then
        return nil
    end
    local text = pipe:read("*l")
    pipe:close()
    return tonumber(text or "")
end

local function get_percent()
    local pipe = io.popen("ls -1 " .. shell_quote(BACKLIGHT_DIR) .. " 2>/dev/null")
    if pipe then
        local names = {}
        for name in pipe:lines() do
            names[#names + 1] = name
        end
        pipe:close()
        table.sort(names)
        for _, name in ipairs(names) do
            local current = read_number(BACKLIGHT_DIR .. "/" .. name .. "/brightness")
            local maximum = read_number(BACKLIGHT_DIR .. "/" .. name .. "/max_brightness")
            if current and maximum and maximum > 0 then
                return pyround(current * 100 / maximum)
            end
        end
    end
    local current = command_number("brightnessctl g")
    local maximum = command_number("brightnessctl m")
    if current and maximum and maximum > 0 then
        return pyround(current * 100 / maximum)
    end
    return nil
end

local function set_percent(value)
    if WRITE then
        os.execute("brightnessctl s " .. tostring(value) .. "% >/dev/null 2>&1")
    end
end

local function load_state()
    local file = io.open(state_path(), "r")
    if not file then
        return 0, -1
    end
    local values = {}
    for line in file:lines() do
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
        if key then
            values[key] = value
        end
    end
    file:close()
    return tonumber(values.override_until) or 0, tonumber(values.last_applied) or -1
end

local function save_state(override_until, last_applied)
    local path = state_path()
    os.execute("mkdir -p " .. shell_quote(dirname(path)))
    local tmp = path:gsub("%.state$", ".tmp")
    local file = io.open(tmp, "w")
    if not file then
        return
    end
    file:write(string.format("override_until=%.0f\nlast_applied=%d\n", override_until, last_applied))
    file:close()
    os.rename(tmp, path)
end

local function log_line(now, current, target, action)
    if not LOG_PATH then
        return
    end
    local file = io.open(LOG_PATH, "a")
    if not file then
        return
    end
    file:write(string.format("%d,%s,%s,%s\n", now, tostring(current or ""), tostring(target or ""), action))
    file:close()
end

local function sleep(seconds)
    os.execute("sleep " .. tostring(seconds))
end

local function acquire_lock()
    local path = state_path()
    os.execute("mkdir -p " .. shell_quote(dirname(path)))
    local lock = path .. ".lock.d"
    local ok = os.execute("mkdir " .. shell_quote(lock) .. " 2>/dev/null")
    if not ok then
        return nil
    end
    return lock
end

local function parse_args(argv)
    local index = 1
    while index <= #argv do
        local arg = argv[index]
        if arg == "--write" then
            WRITE = true
        elseif arg == "--dry-run" then
            WRITE = false
        elseif arg == "--log" then
            index = index + 1
            LOG_PATH = argv[index]
        elseif arg == "--cycles" then
            index = index + 1
            MAX_CYCLES = tonumber(argv[index])
        elseif arg == "--poll" then
            index = index + 1
            POLL_SECONDS = tonumber(argv[index])
        elseif arg == "--target" then
            index = index + 1
            print(target_percent(tonumber(argv[index]) or os.time()))
            os.exit(0)
        elseif arg == "--help" then
            io.write("usage: daemon.lua [--dry-run|--write] [--log PATH] [--cycles N] [--poll SECONDS]\n")
            os.exit(0)
        end
        index = index + 1
    end
end

local function run()
    local lock = acquire_lock()
    if not lock then
        return 0
    end

    local override_until = load_state()
    local current = get_percent()
    while current == nil do
        sleep(1)
        current = get_percent()
    end

    local last_seen = current
    local last_set = 0
    local last_loop = os.time()
    local cycles = 0
    save_state(override_until, current)

    while true do
        local now = os.time()
        local resumed = now - last_loop > 60
        last_loop = now
        current = get_percent()
        if current == nil then
            sleep(POLL_SECONDS)
        else
            local manual = false
            if resumed then
                last_seen = current
            elseif math.abs(current - last_seen) > 2 and now - last_set > 5 then
                override_until = now + HOLD_HOURS * 3600
                last_seen = current
                save_state(override_until, current)
                log_line(now, current, "", "hold")
                manual = true
            end

            if not manual then
                if now >= override_until then
                    local want = target_percent(now)
                    if math.abs(want - current) >= 1 then
                        set_percent(want)
                        last_seen = want
                        last_set = os.time()
                        save_state(override_until, want)
                        log_line(now, current, want, "set")
                    else
                        last_seen = current
                    end
                else
                    last_seen = current
                end
            end

            cycles = cycles + 1
            if MAX_CYCLES and cycles >= MAX_CYCLES then
                break
            end
            sleep(POLL_SECONDS)
        end
    end

    os.execute("rmdir " .. shell_quote(lock))
    return 0
end

parse_args(arg)
os.exit(run())
