-- Small deterministic JSON reader/writer: sorted keys, two-space indent.
-- Enough for the config and scheme files, and it keeps diffs stable between
-- runs. The reader is deliberately strict: a truncated scheme should fail
-- loudly instead of yielding half a palette.

local M = {}

local function decode_error(text, pos, message)
    local line = 1
    for _ in text:sub(1, pos):gmatch("\n") do
        line = line + 1
    end
    error(("invalid JSON at line %d: %s"):format(line, message), 0)
end

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

-- Parses the JSON the writer above (and padilha-config) produces. Arrays come
-- back as plain sequences; `null` is nil, so it disappears from tables, which
-- is what the palette reader wants.
local function decode(text)
    local pos = 1

    local function skip()
        local _, stop = text:find("^[ \t\r\n]*", pos)
        if stop then
            pos = stop + 1
        end
    end

    local parse_value

    local function parse_string()
        pos = pos + 1
        local out = {}
        while true do
            local c = text:sub(pos, pos)
            if c == "" then
                decode_error(text, pos, "unterminated string")
            elseif c == '"' then
                pos = pos + 1
                return table.concat(out)
            elseif c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                local simple = {
                    ['"'] = '"',
                    ["\\"] = "\\",
                    ["/"] = "/",
                    b = "\b",
                    f = "\f",
                    n = "\n",
                    r = "\r",
                    t = "\t",
                }
                if e == "u" then
                    local code = tonumber(text:sub(pos + 2, pos + 5), 16)
                    if not code then
                        decode_error(text, pos, "bad \\u escape")
                    end
                    if code >= 0xD800 and code <= 0xDBFF and text:sub(pos + 6, pos + 7) == "\\u" then
                        local low = tonumber(text:sub(pos + 8, pos + 11), 16)
                        if low and low >= 0xDC00 and low <= 0xDFFF then
                            code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                            pos = pos + 6
                        end
                    end
                    if code < 0 or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF) then
                        decode_error(text, pos, "unpaired \\u escape")
                    end
                    out[#out + 1] = utf8.char(code)
                    pos = pos + 6
                elseif simple[e] then
                    out[#out + 1] = simple[e]
                    pos = pos + 2
                else
                    decode_error(text, pos, "bad escape \\" .. e)
                end
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
    end

    local function parse_number()
        local num = text:match("^-?%d+%.?%d*[eE][-+]?%d+", pos) or text:match("^-?%d+%.?%d*", pos)
        if not num then
            decode_error(text, pos, "expected a value")
        end
        pos = pos + #num
        return tonumber(num)
    end

    local function parse_object()
        pos = pos + 1
        local out = {}
        skip()
        if text:sub(pos, pos) == "}" then
            pos = pos + 1
            return out
        end
        while true do
            skip()
            if text:sub(pos, pos) ~= '"' then
                decode_error(text, pos, "expected a key")
            end
            local key = parse_string()
            skip()
            if text:sub(pos, pos) ~= ":" then
                decode_error(text, pos, "expected ':'")
            end
            pos = pos + 1
            out[key] = parse_value()
            skip()
            local c = text:sub(pos, pos)
            pos = pos + 1
            if c == "}" then
                return out
            elseif c ~= "," then
                decode_error(text, pos - 1, "expected ',' or '}'")
            end
        end
    end

    local function parse_array()
        pos = pos + 1
        local out = {}
        skip()
        if text:sub(pos, pos) == "]" then
            pos = pos + 1
            return out
        end
        while true do
            out[#out + 1] = parse_value()
            skip()
            local c = text:sub(pos, pos)
            pos = pos + 1
            if c == "]" then
                return out
            elseif c ~= "," then
                decode_error(text, pos - 1, "expected ',' or ']'")
            end
        end
    end

    parse_value = function()
        skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            return parse_object()
        elseif c == "[" then
            return parse_array()
        elseif c == '"' then
            return parse_string()
        elseif c == "t" and text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif c == "f" and text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif c == "n" and text:sub(pos, pos + 3) == "null" then
            pos = pos + 4
            return nil
        end
        return parse_number()
    end

    local value = parse_value()
    skip()
    if pos <= #text then
        decode_error(text, pos, "trailing data")
    end
    return value
end

function M.decode(text)
    if type(text) ~= "string" then
        error("json.decode expects a string", 2)
    end
    return decode(text)
end

return M
