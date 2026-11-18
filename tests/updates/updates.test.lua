#!/usr/bin/env lua
-- Pure tests for lib/updates.lua. No pacman, pkexec, display or network is
-- used: the fixtures are the exact text shapes those commands print.

local root = os.getenv("PADILHA_ROOT") or "."
package.path = root .. "/lib/?.lua;" .. package.path

local updates = require("updates")

local passed = 0
local failed = 0

local function ok(message)
    passed = passed + 1
    io.write("  ok   ", message, "\n")
end

local function bad(message, detail)
    failed = failed + 1
    io.write("  FAIL ", message, "\n")
    if detail and detail ~= "" then
        io.write("       ", tostring(detail):gsub("\n", "\n       "), "\n")
    end
end

local function test(name, body)
    local success, error_text = pcall(body)
    if success then
        ok(name)
    else
        bad(name, error_text)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected %s, got %s)", message or "values differ",
            tostring(expected), tostring(actual)), 2)
    end
end

local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local fixture = root .. "/tests/updates/fixtures/"

io.write("update list parsing\n")

test("a pacman -Qu line keeps name, installed version and candidate", function()
    local list = updates.parse_upgrade_list(read(fixture .. "query.txt"))
    equal(#list, 3)
    equal(list[1].name, "linux")
    equal(list[1].oldVersion, "6.12.1-arch1-1")
    equal(list[1].newVersion, "6.12.2-arch1-1")
    equal(list[2].name, "mesa")
    equal(list[2].newVersion, "1:24.3.1-1")
    equal(list[3].ignored, true)
end)

test("malformed query output is ignored instead of becoming a package", function()
    local list = updates.parse_upgrade_list("warning: database is old\nnot a line\nfoo 1.0-1 -> 1.1-1\n")
    equal(#list, 1)
    equal(list[1].name, "foo")
    equal(#updates.parse_upgrade_list(""), 0)
end)

test("pacman -Si blocks carry repository, version and both sizes", function()
    local packages = updates.parse_package_info(read(fixture .. "info.txt"))
    equal(packages.linux.repository, "core")
    equal(packages.linux.version, "6.12.2-arch1-1")
    equal(packages.linux.downloadBytes, 600 * 1024 * 1024)
    equal(packages.mesa.downloadBytes, math.floor(1.5 * 1024 * 1024 + 0.5))
    equal(packages.mesa.installBytes, 12 * 1024 * 1024)
    equal(packages["ignored-package"].downloadBytes, 1024 * 1024)
    equal(packages["not-a-package"], nil)
end)

test("size strings accept IEC units and unknown values become nil", function()
    equal(updates.parse_size("1 KiB"), 1024)
    equal(updates.parse_size("1.50 MiB"), math.floor(1.5 * 1024 * 1024 + 0.5))
    equal(updates.parse_size("2 GiB"), 2 * 1024 * 1024 * 1024)
    equal(updates.parse_size(""), nil)
    equal(updates.parse_size("None"), nil)
    equal(updates.parse_size("not a size"), nil)
end)

test("byte labels stay readable and never claim a missing size", function()
    equal(updates.format_bytes(0), "0 B")
    equal(updates.format_bytes(1536), "1.50 KiB")
    equal(updates.format_bytes(600 * 1024 * 1024), "600 MiB")
    equal(updates.format_bytes(nil), "unknown")
end)

io.write("summary and warnings\n")

test("the summary totals known sizes and reports missing ones", function()
    local list = {
        { name = "a", downloadBytes = 1024, installBytes = 2048 },
        { name = "b", downloadBytes = nil, installBytes = nil },
    }
    local summary = updates.summarise(list)
    equal(summary.count, 2)
    equal(summary.downloadBytes, 1024)
    equal(summary.installBytes, 2048)
    equal(summary.unknownDownload, 1)
    equal(summary.unknownInstall, 1)
    equal(summary.sizesComplete, false)
    equal(summary.large, false)
end)

test("a large update is measured by both download and installed size", function()
    local by_download = updates.summarise({
        { downloadBytes = updates.LARGE_UPDATE_BYTES, installBytes = 1 },
    })
    equal(by_download.large, true)
    local by_install = updates.summarise({
        { downloadBytes = 1, installBytes = updates.LARGE_UPDATE_BYTES },
    })
    equal(by_install.large, true)
    local small = updates.summarise({
        { downloadBytes = 1024, installBytes = 2048 },
    })
    equal(small.large, false)
end)

test("low battery warns even for a small update", function()
    local warnings = updates.warnings(updates.summarise({}), {
        present = true,
        percent = 15,
        onAc = false,
    })
    equal(#warnings, 1)
    equal(warnings[1], "battery-low")
end)

test("a large update on battery warns about AC", function()
    local summary = updates.summarise({
        { downloadBytes = updates.LARGE_UPDATE_BYTES, installBytes = 1 },
    })
    local warnings = updates.warnings(summary, {
        present = true,
        percent = 80,
        onAc = false,
    })
    equal(#warnings, 1)
    equal(warnings[1], "not-on-ac-large")
end)

test("small updates, AC power and desktops do not warn", function()
    local small = updates.summarise({ { downloadBytes = 1024, installBytes = 2048 } })
    equal(#updates.warnings(small, { present = true, percent = 80, onAc = false }), 0)
    local large = updates.summarise({ { downloadBytes = updates.LARGE_UPDATE_BYTES, installBytes = 1 } })
    equal(#updates.warnings(large, { present = true, percent = 80, onAc = true }), 0)
    equal(#updates.warnings(large, { present = false, percent = 0, onAc = true }), 0)
end)

io.write("confirmation\n")

test("only y and yes are confirmations", function()
    equal(updates.is_yes("y"), true)
    equal(updates.is_yes(" YES \n"), true)
    equal(updates.is_yes("n"), false)
    equal(updates.is_yes(""), false)
    equal(updates.is_yes(nil), false)
end)

test("apply refuses before running anything without confirmation", function()
    local result, error_text = updates.apply({ confirmed = false })
    equal(result, nil)
    if not error_text:match("confirmation") then
        error("confirmation refusal was not explained: " .. tostring(error_text))
    end
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
    os.exit(1)
end
