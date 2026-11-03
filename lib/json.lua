-- Small deterministic JSON writer: sorted keys, two-space indent. Enough for
-- the config and scheme files, and it keeps diffs stable between runs.

local M = {}

local function is_array(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then
            return false
        end
        n = n + 1
    end
    return n == #t
end

local function escape(s)
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
        local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return map[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function encode(value, indent, seen)
    local kind = type(value)
    if kind == "nil" then
        return "null"
    elseif kind == "boolean" then
        return tostring(value)
    elseif kind == "number" then
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return string.format("%.6g", value)
    elseif kind == "string" then
        return escape(value)
    elseif kind ~= "table" then
        error("cannot encode " .. kind)
    end

    if seen[value] then
        error("cannot encode a table that contains itself")
    end
    seen[value] = true

    local pad = indent .. "  "
    local out = {}
    if is_array(value) then
        for i = 1, #value do
            out[i] = pad .. encode(value[i], pad, seen)
        end
        seen[value] = nil
        if #out == 0 then
            return "[]"
        end
        return "[\n" .. table.concat(out, ",\n") .. "\n" .. indent .. "]"
    end

    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        out[#out + 1] = pad .. escape(k) .. ": " .. encode(value[k], pad, seen)
    end
    seen[value] = nil
    if #out == 0 then
        return "{}"
    end
    return "{\n" .. table.concat(out, ",\n") .. "\n" .. indent .. "}"
end

function M.encode(value)
    return encode(value, "", {}) .. "\n"
end

return M
