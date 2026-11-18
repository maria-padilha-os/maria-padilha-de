-- Package update state and the only path that can apply updates.
--
-- The shell reads the pending list and the confirmation copy from here. The
-- command wrapper in bin/padilha exposes the same functions, so the settings
-- page and a terminal cannot drift apart. pacman remains the package manager:
-- this module only queries it with -Qu/-Si and, after an explicit
-- confirmation, asks the existing polkit agent (pkexec) to run -Syu. There is
-- no daemon, no setuid helper, no automatic timer and no reboot path.

local json = require("json")

local M = {}

M.LARGE_UPDATE_BYTES = 500 * 1024 * 1024
M.LOW_BATTERY_PERCENT = 20
M.DEFAULT_ESCALATION = "pkexec"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end

local function file_exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

local function command_exists(command)
    if not command or command == "" then
        return false
    end
    local pipe = io.popen("command -v " .. quote(command) .. " >/dev/null 2>&1")
    if not pipe then
        return false
    end
    local ok = pipe:close()
    return ok == true
end

local function capture(command)
    local errfile = os.tmpname()
    local pipe = io.popen("LC_ALL=C " .. command .. " 2>" .. quote(errfile))
    if not pipe then
        os.remove(errfile)
        return "", "could not start the package manager", false
    end
    local output = pipe:read("*a") or ""
    local ok = pipe:close()
    local error_text = read_file(errfile) or ""
    os.remove(errfile)
    return output, error_text, ok == true
end

-- pacman -Qu prints "name installed -> candidate". The optional [ignored]
-- suffix is part of the query output, not part of the version.
function M.parse_upgrade_list(text)
    local updates = {}
    for raw_line in tostring(text or ""):gsub("\r", ""):gmatch("[^\n]+") do
        local line = raw_line:gsub("%s+$", "")
        if line:match("%S") then
            local name, old_version, new_version, tail =
                line:match("^(%S+)%s+(%S+)%s+%-%>%s+(%S+)(.*)$")
            if name and old_version and new_version then
                updates[#updates + 1] = {
                    name = name,
                    oldVersion = old_version,
                    newVersion = new_version,
                    ignored = tail:match("%[ignored%]") ~= nil,
                }
            end
        end
    end
    return updates
end

function M.parse_size(value)
    if type(value) == "number" then
        return value
    end

    local text = trim(value)
    if text == "" or text == "None" or text == "Unknown" then
        return nil
    end

    local number, unit = text:match("^([%d%.]+)%s*([KMGTP]i?B)$")
    if not number then
        number = text:match("^([%d%.]+)")
        unit = "B"
    end

    local amount = tonumber(number)
    if not amount then
        return nil
    end

    local factors = {
        B = 1,
        KiB = 1024,
        MiB = 1024 ^ 2,
        GiB = 1024 ^ 3,
        TiB = 1024 ^ 4,
        PiB = 1024 ^ 5,
        KB = 1000,
        MB = 1000 ^ 2,
        GB = 1000 ^ 3,
        TB = 1000 ^ 4,
        PB = 1000 ^ 5,
    }
    local factor = factors[unit or "B"]
    if not factor then
        return nil
    end
    return math.floor(amount * factor + 0.5)
end

function M.format_bytes(bytes)
    local value = tonumber(bytes)
    if not value or value < 0 then
        return "unknown"
    end

    local units = { "B", "KiB", "MiB", "GiB", "TiB", "PiB" }
    local index = 1
    while value >= 1024 and index < #units do
        value = value / 1024
        index = index + 1
    end

    if index == 1 then
        return string.format("%d B", math.floor(value + 0.5))
    elseif value >= 100 then
        return string.format("%.0f %s", value, units[index])
    elseif value >= 10 then
        return string.format("%.1f %s", value, units[index])
    end
    return string.format("%.2f %s", value, units[index])
end

-- pacman -Si prints one package per blank-line separated block. Only the
-- fields that identify the candidate and its size matter here.
function M.parse_package_info(text)
    local packages = {}
    local normalised = tostring(text or ""):gsub("\r", "")
    if normalised == "" then
        return packages
    end

    for block in (normalised .. "\n\n"):gmatch("(.-)\n\n") do
        if block:match("%S") then
            local entry = {
                repository = "",
                version = "",
                downloadBytes = nil,
                installBytes = nil,
            }
            for line in block:gmatch("[^\n]+") do
                local key, value = line:match("^([^:]+):%s*(.-)%s*$")
                if key then
                    key = trim(key)
                    if key == "Repository" then
                        entry.repository = trim(value)
                    elseif key == "Version" then
                        entry.version = trim(value)
                    elseif key == "Download Size" then
                        entry.downloadBytes = M.parse_size(value)
                    elseif key == "Installed Size" then
                        entry.installBytes = M.parse_size(value)
                    elseif key == "Name" then
                        entry.name = trim(value)
                    end
                end
            end
            if entry.name and entry.name ~= "" then
                packages[entry.name] = entry
            end
        end
    end
    return packages
end

local function annotate(update, candidate)
    local download = candidate and candidate.downloadBytes or nil
    local install = candidate and candidate.installBytes or nil
    update.repository = candidate and candidate.repository or ""
    update.downloadBytes = download
    update.installBytes = install
    update.downloadLabel = M.format_bytes(download)
    update.installLabel = M.format_bytes(install)
    update.sizesComplete = download ~= nil and install ~= nil
    if candidate and candidate.version ~= "" then
        update.candidateVersion = candidate.version
    end
    return update
end

function M.summarise(updates)
    local summary = {
        count = #updates,
        downloadBytes = 0,
        installBytes = 0,
        unknownDownload = 0,
        unknownInstall = 0,
    }
    for _, update in ipairs(updates) do
        if update.downloadBytes then
            summary.downloadBytes = summary.downloadBytes + update.downloadBytes
        else
            summary.unknownDownload = summary.unknownDownload + 1
        end
        if update.installBytes then
            summary.installBytes = summary.installBytes + update.installBytes
        else
            summary.unknownInstall = summary.unknownInstall + 1
        end
    end

    summary.downloadLabel = M.format_bytes(summary.downloadBytes)
    summary.installLabel = M.format_bytes(summary.installBytes)
    summary.sizesComplete = summary.unknownDownload == 0 and summary.unknownInstall == 0
    summary.large = summary.downloadBytes >= M.LARGE_UPDATE_BYTES
        or summary.installBytes >= M.LARGE_UPDATE_BYTES
    summary.largeBytes = M.LARGE_UPDATE_BYTES
    summary.lowBatteryPercent = M.LOW_BATTERY_PERCENT
    return summary
end

local function power_supply_dir()
    return os.getenv("PADILHA_UPDATE_POWER_SUPPLY") or "/sys/class/power_supply"
end

function M.battery_state()
    local state = {
        present = false,
        percent = 100,
        onAc = true,
        status = "",
    }
    local directory = power_supply_dir()
    local pipe = io.popen(
        "for path in " .. quote(directory) .. "/*; do [ -d \"$path\" ] && printf '%s\\n' \"$path\"; done 2>/dev/null"
    )
    if not pipe then
        return state
    end

    local ac_online = false
    for path in pipe:lines() do
        local kind = trim(read_file(path .. "/type") or "")
        if kind == "Battery" then
            local capacity = tonumber(trim(read_file(path .. "/capacity") or ""))
            if capacity then
                state.present = true
                state.percent = math.max(0, math.min(100, math.floor(capacity + 0.5)))
                state.status = trim(read_file(path .. "/status") or "")
            end
        elseif kind ~= "" then
            local online = trim(read_file(path .. "/online") or "")
            if online == "1" then
                ac_online = true
            end
        end
    end
    pipe:close()

    if state.present then
        state.onAc = ac_online
    else
        state.onAc = true
        state.percent = 100
    end
    return state
end

function M.warnings(summary, battery)
    local codes = {}
    if battery.present and battery.percent <= M.LOW_BATTERY_PERCENT then
        codes[#codes + 1] = "battery-low"
    end
    if battery.present and not battery.onAc and summary.large then
        codes[#codes + 1] = "not-on-ac-large"
    end
    return codes
end

function M.pacman_command()
    return os.getenv("PADILHA_PACMAN") or "pacman"
end

function M.check()
    local pacman = M.pacman_command()
    if not command_exists(pacman) then
        return nil, "pacman was not found; Maria Padilha expects an Arch-based system"
    end

    local query, query_error, query_ok = capture(quote(pacman) .. " -Qu")
    if query == "" and not query_ok and query_error:match("%S") then
        if query_error:lower():match("error") or query_error:lower():match("not found") then
            return nil, trim(query_error)
        end
    end

    local updates = M.parse_upgrade_list(query)
    if query:match("%S") and #updates == 0 then
        return nil, "could not parse the package update list"
    end

    if #updates > 0 then
        local names = {}
        for _, update in ipairs(updates) do
            names[#names + 1] = quote(update.name)
        end
        local info_text = capture(quote(pacman) .. " -Si " .. table.concat(names, " "))
        local info = M.parse_package_info(info_text)
        for _, update in ipairs(updates) do
            annotate(update, info[update.name])
        end
    end

    local summary = M.summarise(updates)
    local battery = M.battery_state()
    return {
        updates = updates,
        count = summary.count,
        downloadBytes = summary.downloadBytes,
        installBytes = summary.installBytes,
        downloadLabel = summary.downloadLabel,
        installLabel = summary.installLabel,
        unknownDownload = summary.unknownDownload,
        unknownInstall = summary.unknownInstall,
        sizesComplete = summary.sizesComplete,
        large = summary.large,
        largeBytes = summary.largeBytes,
        lowBatteryPercent = summary.lowBatteryPercent,
        battery = battery,
        warnings = M.warnings(summary, battery),
        checkedAt = os.time(),
    }
end

function M.log_dir()
    local state = os.getenv("XDG_STATE_HOME")
    if not state or state == "" then
        state = (os.getenv("HOME") or ".") .. "/.local/state"
    end
    return state:gsub("/+$", "") .. "/padilha/updates"
end

local function make_log_path()
    local directory = M.log_dir()
    local made = os.execute("mkdir -p " .. quote(directory))
    if not made then
        return nil, "could not create " .. directory
    end

    local stamp = os.date("!%Y%m%dT%H%M%SZ")
    local base = directory .. "/update-" .. stamp
    local path = base .. ".log"
    local index = 1
    while file_exists(path) do
        path = base .. "-" .. index .. ".log"
        index = index + 1
    end
    return path
end

local function read_tail(path, count)
    local text = read_file(path) or ""
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    local start = math.max(1, #lines - (count or 40) + 1)
    local tail = {}
    for index = start, #lines do
        tail[#tail + 1] = lines[index]
    end
    return table.concat(tail, "\n")
end

local function status_of(ok, how, code)
    if ok == true then
        return 0
    end
    if type(ok) == "number" then
        return ok
    end
    if how == "exit" and type(code) == "number" then
        return code
    end
    return 1
end

function M.is_yes(value)
    local answer = trim(value):lower()
    return answer == "y" or answer == "yes"
end

function M.apply(options)
    options = options or {}
    if options.confirmed ~= true then
        return nil, "refusing to apply updates without explicit confirmation"
    end

    local data, error_text = M.check()
    if not data then
        return nil, error_text
    end

    if data.count == 0 then
        return {
            ok = true,
            status = 0,
            count = 0,
            downloadBytes = 0,
            installBytes = 0,
            downloadLabel = "0 B",
            installLabel = "0 B",
            logPath = "",
            logTail = "",
            warnings = data.warnings,
            message = "No updates are available.",
        }
    end

    local log_path, log_error = make_log_path()
    if not log_path then
        return nil, log_error
    end

    local log = io.open(log_path, "wb")
    if not log then
        return nil, "could not write " .. log_path
    end
    log:write("Maria Padilha update log\n")
    log:write("Started: ", os.date("!%Y-%m-%dT%H:%M:%SZ"), "\n")
    log:write("Updates: ", tostring(data.count), "\n")
    if #data.warnings > 0 then
        log:write("Warnings: ", table.concat(data.warnings, ", "), "\n")
    end
    log:close()

    local function fail(status, message)
        local failed = io.open(log_path, "ab")
        if failed then
            failed:write("Result: ", message, "\n")
            failed:close()
        end
        return {
            ok = false,
            status = status,
            count = data.count,
            downloadBytes = data.downloadBytes,
            installBytes = data.installBytes,
            downloadLabel = data.downloadLabel,
            installLabel = data.installLabel,
            warnings = data.warnings,
            logPath = log_path,
            logTail = read_tail(log_path, 40),
            message = message,
        }
    end

    local pacman = M.pacman_command()
    local escalation = os.getenv("PADILHA_UPDATE_ESCALATE")
    if escalation == nil then
        escalation = M.DEFAULT_ESCALATION
    end

    local uid = trim((function()
        local pipe = io.popen("id -u")
        if not pipe then
            return ""
        end
        local value = pipe:read("*a")
        pipe:close()
        return value
    end)())

    local prefix = ""
    if uid ~= "0" then
        if escalation == "" then
            return fail(127, "Applying updates needs root; set PADILHA_UPDATE_ESCALATE to an existing helper.")
        end
        if not command_exists(escalation) then
            return fail(127, "Privilege helper '" .. escalation .. "' was not found.")
        end
        prefix = quote(escalation) .. " "
    end

    local command = prefix .. quote(pacman) .. " -Syu --noconfirm"
    local command_log = io.open(log_path, "ab")
    if command_log then
        command_log:write("Command: ", command:gsub("'", ""), "\n\n")
        command_log:close()
    end

    local ok, how, code = os.execute(command .. " >> " .. quote(log_path) .. " 2>&1")
    local status = status_of(ok, how, code)
    local tail = read_tail(log_path, 40)

    local result = {
        ok = status == 0,
        status = status,
        count = data.count,
        downloadBytes = data.downloadBytes,
        installBytes = data.installBytes,
        downloadLabel = data.downloadLabel,
        installLabel = data.installLabel,
        warnings = data.warnings,
        logPath = log_path,
        logTail = tail,
    }
    if result.ok then
        result.message = string.format("%d package update(s) applied.", data.count)
    else
        result.message = string.format("The package manager failed with exit status %d.", status)
    end
    return result
end

function M.latest_log()
    local directory = M.log_dir()
    local pipe = io.popen("ls -1t " .. quote(directory) .. "/*.log 2>/dev/null | head -n 1")
    if not pipe then
        return nil
    end
    local path = trim(pipe:read("*a") or "")
    pipe:close()
    if path == "" then
        return nil
    end
    return path
end

function M.print_check(data)
    if data.count == 0 then
        io.write("System is up to date.\n")
        return
    end

    io.write(string.format("%d update(s) available: %s download, %s installed.\n",
        data.count, data.downloadLabel, data.installLabel))
    for _, update in ipairs(data.updates) do
        local ignored = update.ignored and " [ignored]" or ""
        io.write(string.format("%-32s %s -> %s  (%s download, %s installed)%s\n",
            update.name,
            update.oldVersion,
            update.newVersion,
            update.downloadLabel,
            update.installLabel,
            ignored))
    end
    for _, warning in ipairs(data.warnings) do
        if warning == "battery-low" then
            io.write(string.format("warning: battery is low (%d%%); plug in the charger before applying.\n",
                data.battery.percent))
        elseif warning == "not-on-ac-large" then
            io.write(string.format(
                "warning: this is a large update (%s download) while on battery; " ..
                "plug in the charger.\n", data.downloadLabel))
        end
    end
end

function M.print_apply(result)
    io.write(result.message, "\n")
    if result.logPath and result.logPath ~= "" then
        io.write("Log: ", result.logPath, "\n")
    end
    if not result.ok and result.logTail and result.logTail ~= "" then
        io.write(result.logTail, "\n")
    end
end

function M.encode(value)
    return json.encode(value)
end

return M
