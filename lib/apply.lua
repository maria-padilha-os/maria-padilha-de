-- Write a scheme to every application that can be told about it.
--
-- Each entry is a file, the template it is rendered from, and what has to be
-- poked afterwards: btop, htop and cava reload on SIGUSR2, GTK needs dconf,
-- terminals take OSC sequences. Paths are relative to the XDG directory in
-- the `base` field so a test can point the whole thing at a scratch tree.

local T = require("template")

local M = {}

local home = os.getenv("HOME") or ""
M.bases = {
    config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config"),
    state = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state"),
    data = os.getenv("XDG_DATA_HOME") or (home .. "/.local/share"),
}

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function mkdir(path)
    local dir = path:match("^(.*)/[^/]+$")
    if dir and dir ~= "" then
        os.execute("mkdir -p " .. quote(dir))
    end
end

-- Write to a temporary file next to the target and rename, so a reader never
-- sees half a theme.
function M.write(path, text)
    mkdir(path)
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then
        return nil, err or ("cannot write " .. tmp)
    end
    f:write(text)
    f:close()
    local ok, rename_err = os.rename(tmp, path)
    if not ok then
        os.remove(tmp)
        return nil, rename_err
    end
    return true
end

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local lib_dir = source:match("^(.*)/[^/]+$") or "."

local function read_template(name)
    local path = lib_dir .. "/../share/templates/" .. name
    local f = io.open(path, "r")
    if not f then
        return nil, path
    end
    local text = f:read("*a")
    f:close()
    return text
end

-- The list of applications. `template` is a file in share/templates/;
-- `base` picks the XDG directory; `hash` asks for #rrggbb; `reload` is a
-- shell command run after the file is written; `enabled` is the config key.
M.apps = {
    { id = "hypr", base = "config", dest = "hypr/scheme/current.lua", lua_table = true, enabled = "enableHypr" },
    { id = "fuzzel", base = "config", dest = "fuzzel/fuzzel.ini", template = "fuzzel.ini", enabled = "enableFuzzel" },
    { id = "btop", base = "config", dest = "btop/themes/caelestia.theme", template = "btop.theme", hash = true,
        reload = "killall -USR2 btop", enabled = "enableBtop" },
    { id = "htop", base = "config", dest = "htop/htoprc", template = "htop.theme", hash = true,
        reload = "killall -USR2 htop", enabled = "enableHtop" },
    { id = "nvtop", base = "config", dest = "nvtop/nvtop.colors", template = "nvtop.colors", hash = true,
        enabled = "enableNvtop" },
    { id = "cava", base = "config", dest = "cava/config", template = "cava.conf", hash = true,
        reload = "killall -USR2 cava", enabled = "enableCava" },
    { id = "gtk3", base = "config", dest = "gtk-3.0/gtk.css", template = "gtk.css", hash = true,
        enabled = "enableGtk" },
    { id = "gtk3-thunar", base = "config", dest = "gtk-3.0/thunar.css", template = "thunar.css", hash = true,
        enabled = "enableGtk" },
    { id = "gtk4", base = "config", dest = "gtk-4.0/gtk.css", template = "gtk.css", hash = true,
        enabled = "enableGtk" },
    { id = "gtk4-thunar", base = "config", dest = "gtk-4.0/thunar.css", template = "thunar.css", hash = true,
        enabled = "enableGtk" },
    { id = "qt-colours", base = "config", dest = "qtengine/caelestia.colors", template = "qt{mode}.colors",
        hash = true, enabled = "enableQt" },
    { id = "qt-engine", base = "config", dest = "qtengine/config.json", template = "qtengine.json",
        enabled = "enableQt" },
}

--------------------------------------------------------------------------
-- Special writers
--------------------------------------------------------------------------

local function hypr_lua(colours)
    local keys = {}
    for name in pairs(colours) do
        keys[#keys + 1] = name
    end
    table.sort(keys)
    local out = { "return {" }
    for _, name in ipairs(keys) do
        out[#out + 1] = string.format('  %s = "%s",', name, colours[name])
    end
    out[#out + 1] = "}"
    return table.concat(out, "\n") .. "\n"
end

local function ansi(hex, ...)
    return string.format("\27]%s;rgb:%s/%s/%s\27\\", table.concat({ ... }, ";"), hex:sub(1, 2), hex:sub(3, 4),
        hex:sub(5, 6))
end

-- OSC 10/11/12/17 and the 256-colour slots, as terminals expect them.
function M.sequences(colours)
    local seq = {
        ansi(colours.onSurface, 10),
        ansi(colours.surface, 11),
        ansi(colours.secondary, 12),
        ansi(colours.secondary, 17),
    }
    for i = 0, 15 do
        seq[#seq + 1] = ansi(colours["term" .. i], 4, i)
    end
    seq[#seq + 1] = ansi(colours.primary, 4, 16)
    seq[#seq + 1] = ansi(colours.secondary, 4, 17)
    seq[#seq + 1] = ansi(colours.tertiary, 4, 18)
    return table.concat(seq)
end

--------------------------------------------------------------------------
-- Apply
--------------------------------------------------------------------------

local function config_value(config, key, default)
    local theme = config and config.theme
    if theme and theme[key] ~= nil then
        return theme[key]
    end
    return default
end

-- scheme, { config = <table from cli.json, optional>, prefix = dir, signals = bool, dconf = bool }
function M.apply(scheme, opts)
    opts = opts or {}
    local bases = {
        config = (opts.prefix or "") .. M.bases.config,
        state = (opts.prefix or "") .. M.bases.state,
        data = (opts.prefix or "") .. M.bases.data,
    }
    local written, errors = {}, {}
    local colours = scheme.colours
    local config = opts.config

    -- scheme.json first: everything else can lag, this cannot.
    local ok, err = M.write(bases.state .. "/caelestia/scheme.json", require("json").encode(scheme))
    if not ok then
        errors[#errors + 1] = "scheme.json: " .. tostring(err)
    else
        written[#written + 1] = "scheme.json"
    end

    for _, app in ipairs(M.apps) do
        if config_value(config, app.enabled, true) ~= false then
            local text
            if app.lua_table then
                text = hypr_lua(colours)
            else
                local name = app.template:gsub("{mode}", scheme.mode)
                local template, path = read_template(name)
                if not template then
                    errors[#errors + 1] = app.id .. ": no template at " .. tostring(path)
                    goto continue
                end
                local good, rendered = pcall(T.render, template, colours, { hash = app.hash, mode = scheme.mode })
                if not good then
                    errors[#errors + 1] = app.id .. ": " .. tostring(rendered)
                    goto continue
                end
                text = rendered
            end

            local target = bases[app.base] .. "/" .. app.dest
            local wrote, write_err = M.write(target, text)
            if not wrote then
                errors[#errors + 1] = app.id .. ": " .. tostring(write_err)
            else
                written[#written + 1] = app.dest
                if opts.signals and app.reload then
                    os.execute(app.reload .. " 2>/dev/null")
                end
            end
        end
        ::continue::
    end

    -- foot keeps both palettes in one config and switches with a signal.
    local foot_theme = scheme.mode == "light" and "light" or "dark"
    local foot_ok = M.write(bases.config .. "/foot/theme-default.ini",
        "[main]\ninitial-color-theme=" .. foot_theme .. "\n")
    if foot_ok then
        written[#written + 1] = "foot/theme-default.ini"
        if opts.signals then
            os.execute("pkill -" .. (foot_theme == "light" and "USR2" or "USR1") .. " -x foot 2>/dev/null; "
                .. "pkill -" .. (foot_theme == "light" and "USR2" or "USR1") .. " -x footclient 2>/dev/null")
        end
    else
        errors[#errors + 1] = "foot/theme-default.ini: could not write"
    end

    -- Terminal sequences: written always, broadcast only when asked.
    local seq = M.sequences(colours)
    local wrote, seq_err = M.write(bases.state .. "/caelestia/sequences.txt", seq)
    if wrote then
        written[#written + 1] = "sequences.txt"
    else
        errors[#errors + 1] = "sequences.txt: " .. tostring(seq_err)
    end

    if opts.broadcast then
        local tmp = bases.state .. "/caelestia/sequences.txt"
        os.execute(string.format(
            'for p in /dev/pts/[0-9]*; do timeout 0.1 tee "$p" < %s > /dev/null 2>&1 || true; done',
            quote(tmp)))
    end

    if opts.dconf then
        os.execute("dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-" .. scheme.mode .. "'\" 2>/dev/null")
        os.execute("dconf write /org/gnome/desktop/interface/gtk-theme \"'adw-gtk3-dark'\" 2>/dev/null")
        os.execute("dconf write /org/gnome/desktop/interface/icon-theme \"'Papirus-" ..
            scheme.mode:gsub("^%l", string.upper) .. "'\" 2>/dev/null")
    end

    if opts.hooks and config and config.theme and config.theme.postHook then
        os.execute(config.theme.postHook)
    end

    return written, errors
end

return M
