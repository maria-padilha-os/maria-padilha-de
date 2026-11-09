-- Restricted Lua data dumper for the assistant configuration.
--
-- The backend reads ai.lua as data, never as code.  The chunk is loaded with an
-- empty environment: there is no os, io, require, load, dofile, package or
-- debug.  Only a table of plain values can come back.  Errors are reported
-- with a line number, never with a value from the file.

local here = (arg[0] or ""):match("^(.*)/[^/]+$") or "."
package.path = here .. "/../?.lua;" .. here .. "/?.lua;" .. package.path

local json = require("json")

local function fail(message)
    local text = tostring(message)
    -- Lua's syntax errors quote the offending token.  Never copy a value from
    -- the configuration into a log or an error shown by the panel.
    text = text:gsub("near '.-'", "near <token>")
    text = text:gsub('near ".-"', "near <token>")
    io.stderr:write("config: ", text, "\n")
    os.exit(1)
end

local function check(value, seen, depth, count)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "string" then
        return count + 1
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            fail("number is not finite")
        end
        return count + 1
    elseif kind ~= "table" then
        fail("unsupported value type " .. kind)
    end

    if seen[value] then
        fail("table refers to itself")
    end
    if depth > 64 then
        fail("table is nested too deeply")
    end
    seen[value] = true
    count = count + 1
    if count > 100000 then
        fail("table has too many values")
    end
    for key, child in pairs(value) do
        local key_kind = type(key)
        if key_kind ~= "string" and key_kind ~= "number" then
            fail("table keys must be strings or numbers")
        end
        if key_kind == "string" and #key > 4096 then
            fail("table key is too long")
        end
        if key_kind == "number" and
            (key ~= key or key == math.huge or key == -math.huge) then
            fail("table key is not finite")
        end
        count = check(child, seen, depth + 1, count)
    end
    seen[value] = nil
    return count
end

local path = arg[1]
if not path or path == "" then
    fail("no configuration path")
end

local file, open_error = io.open(path, "rb")
if not file then
    fail(open_error or "cannot open the configuration")
end
local source = file:read("*a")
file:close()
if not source then
    fail("cannot read the configuration")
end
if #source > 1048576 then
    fail("configuration is larger than 1 MiB")
end

local chunk, syntax_error
if _VERSION == "Lua 5.1" and type(loadstring) == "function" then
    chunk, syntax_error = loadstring(source, "@" .. path)
else
    chunk, syntax_error = load(source, "@" .. path, "t", {})
end
if not chunk then
    fail(syntax_error or "syntax error")
end
-- Lua 5.1/LuaJIT has no environment argument to load; keep the same
-- no-globals rule there rather than silently running with _G.
if type(setfenv) == "function" then
    setfenv(chunk, {})
end

local ok, value = pcall(chunk)
if not ok then
    fail(value)
end
if type(value) ~= "table" then
    fail("configuration must return a table")
end
check(value, {}, 0, 0)

local encoded_ok, encoded = pcall(json.encode, value)
if not encoded_ok then
    fail(encoded or "cannot encode the configuration")
end
io.write(encoded)
