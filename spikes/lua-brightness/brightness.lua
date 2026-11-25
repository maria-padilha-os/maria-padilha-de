#!/usr/bin/env lua
-- Experimental Lua port of the brightness curve from bin/padilha-brightness.
--
-- This is a spike: it never writes the backlight.  It exists to compare the
-- curve against the Python daemon and to measure the resident memory of an
-- equivalent Lua 5.5 process.

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

-- Python's round() is half-to-even; match it exactly so the comparison is
-- about the curve, not the rounding mode.
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

local function base_epoch()
    return os.time({ year = 2026, month = 11, day = 25, hour = 0, min = 0, sec = 0 })
end

local function print_table()
    local base = base_epoch()
    for minute = 0, 1439 do
        io.write(minute, ",", target_percent(base + minute * 60), "\n")
    end
end

local function dry_run(cycles)
    cycles = tonumber(cycles) or 5
    for index = 1, cycles do
        local now = os.time()
        io.write(now, ",", target_percent(now), "\n")
        io.stdout:flush()
        if index < cycles then
            os.execute("sleep 2")
        end
    end
end

local mode = arg[1]
if mode == "--table" then
    print_table()
elseif mode == "--target" then
    local epoch = tonumber(arg[2]) or os.time()
    print(target_percent(epoch))
elseif mode == "--dry-run" then
    dry_run(arg[2])
else
    io.stderr:write("usage: brightness.lua --table | --target [epoch] | --dry-run [cycles]\n")
    os.exit(2)
end
