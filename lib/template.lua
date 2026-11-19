-- Render a template with the scheme's colours.
--
-- Templates use `{{ $name }}` for a colour and `{{ $mode }}` for the scheme
-- mode; that is almost the whole language. `{{ $name | rgb }}` writes the same
-- colour as `r,g,b`, for formats such as KDE's window-manager blend fields
-- that cannot take a hex value. `hash` says whether a plain colour wants
-- `#rrggbb` or bare `rrggbb` (theme files that add their own #).
--
-- An unknown colour is an error, not an empty string: a template that asks
-- for a role the scheme does not have is a bug in one of the two, and it
-- should be found by the test suite rather than by an invisible label.

local M = {}

local PLACEHOLDER = "{{%s*%$(%w+)%s*([^}]-)%s*}}"

local function fail(msg)
    error(msg, 0)
end

local function filter_name(raw)
    return (raw:gsub("^%s*|?%s*", ""):gsub("%s*$", ""))
end

-- text, colours, { hash = bool, mode = "light"|"dark" } -> rendered text
function M.render(text, colours, opts)
    opts = opts or {}
    local missing = {}

    local rendered = text:gsub(PLACEHOLDER, function(name, raw_filter)
        local filter = filter_name(raw_filter)
        if name == "mode" then
            if filter ~= "" then
                fail("the mode placeholder does not take a filter")
            end
            return (opts.mode or ""):gsub("^%l", string.upper)
        end
        local value = colours[name]
        if not value then
            missing[#missing + 1] = name
            return ""
        end
        if filter == "rgb" then
            local hex = value:gsub("#", "")
            if not hex:match("^%x%x%x%x%x%x$") then
                fail("colour '" .. name .. "' is not a six-digit hex value")
            end
            return string.format(
                "%d,%d,%d",
                tonumber(hex:sub(1, 2), 16),
                tonumber(hex:sub(3, 4), 16),
                tonumber(hex:sub(5, 6), 16))
        elseif filter ~= "" then
            fail("template filter '" .. filter .. "' is not supported")
        end
        return (opts.hash and "#" or "") .. value
    end)

    if #missing > 0 then
        table.sort(missing)
        fail("template needs colours the scheme does not have: " .. table.concat(missing, ", "))
    end

    return rendered
end

-- All the colour names a template refers to.
function M.names(text)
    local names = {}
    for name in text:gmatch(PLACEHOLDER) do
        if name ~= "mode" then
            names[name] = true
        end
    end
    return names
end

return M
