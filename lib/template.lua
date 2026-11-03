-- Render a template with the scheme's colours.
--
-- Templates use `{{ $name }}` for a colour and `{{ $mode }}` for the scheme
-- mode; that is the whole language. `hash` says whether the template wants
-- `#rrggbb` or bare `rrggbb` (theme files that add their own #).
--
-- An unknown colour is an error, not an empty string: a template that asks
-- for a role the scheme does not have is a bug in one of the two, and it
-- should be found by the test suite rather than by an invisible label.

local M = {}

local function fail(msg)
    error(msg, 0)
end

-- text, colours, { hash = bool, mode = "light"|"dark" } -> rendered text
function M.render(text, colours, opts)
    opts = opts or {}
    local out, missing = {}, {}

    local rendered = text:gsub("{{%s*%$(%w+)%s*}}", function(name)
        if name == "mode" then
            return (opts.mode or ""):gsub("^%l", string.upper)
        end
        local value = colours[name]
        if not value then
            missing[#missing + 1] = name
            return ""
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
    for name in text:gmatch("{{%s*%$(%w+)%s*}}") do
        if name ~= "mode" then
            names[name] = true
        end
    end
    return names
end

return M
