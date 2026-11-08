-- Write a scheme to every application that can be told about it.
--
-- Each entry is a file, the template it is rendered from, and what has to be
-- poked afterwards: btop and cava reload on SIGUSR2, GTK needs dconf,
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

-- A fixed `.tmp` name is fine for one writer and wrong for two. The theme can
-- be applied by the daylight daemon and a wallpaper command at the same time,
-- so make every temporary file unique to the process.
local tmp_counter = 0
local function tmp_path(path)
    tmp_counter = tmp_counter + 1
    local token = tostring({}):match("0x%x+") or tostring(os.time())
    return path .. ".tmp." .. token .. "." .. tmp_counter
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
    local tmp = tmp_path(path)
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

-- Literal replacement: templates are text, not patterns.
local function replace_plain(text, needle, replacement)
    local out, i = {}, 1
    while true do
        local s, e = text:find(needle, i, true)
        if not s then
            out[#out + 1] = text:sub(i)
            return table.concat(out)
        end
        out[#out + 1] = text:sub(i, s - 1)
        out[#out + 1] = replacement
        i = e + 1
    end
end

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

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_dir(path)
    return os.execute("test -d " .. quote(path)) == true
end

local function prefixed(prefix, path)
    if prefix and prefix ~= "" then
        return prefix .. path
    end
    return path
end

-- Firefox creates profiles.ini on its first launch. The default profile is
-- marked Default=1, or named by an [Install...] section; if neither is
-- usable, fall back to the first profile directory that exists. A missing
-- profile is not an error: Firefox is simply not set up yet.
local function profile_from_ini(root, prefix)
    local text = read_file(root .. "/profiles.ini")
    if not text then
        return nil
    end

    local profiles, install_default = {}, nil
    local section
    for raw_line in text:gmatch("[^\r\n]+") do
        local line = trim(raw_line)
        if line:match("^%[") then
            section = line
            if section:match("^%[Profile") then
                profiles[#profiles + 1] = { default = false }
            end
        elseif line ~= "" and not line:match("^[#;]") then
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and section then
                key = trim(key):lower()
                value = trim(value)
                if section:match("^%[Profile") then
                    local profile = profiles[#profiles]
                    if key == "path" then
                        profile.path = value
                    elseif key == "default" then
                        profile.default = value ~= "" and value ~= "0"
                    end
                elseif section:match("^%[Install") and key == "default" then
                    install_default = value
                end
            end
        end
    end

    local function resolve(path)
        if not path or path == "" then
            return nil
        end
        if path:sub(1, 1) == "/" then
            return prefixed(prefix, path)
        end
        return root .. "/" .. path
    end

    -- Modern Firefox records the profile chosen for this installation in the
    -- [Install...] section; that wins over the legacy Profile Default flag.
    if install_default then
        local dir = resolve(install_default)
        if dir and is_dir(dir) then
            return dir
        end
    end
    for _, profile in ipairs(profiles) do
        if profile.default then
            local dir = resolve(profile.path)
            if dir and is_dir(dir) then
                return dir
            end
        end
    end
    for _, profile in ipairs(profiles) do
        local dir = resolve(profile.path)
        if dir and is_dir(dir) then
            return dir
        end
    end
    return nil
end

local function thunderbird_profile(prefix)
    local override = os.getenv("PADILHA_THUNDERBIRD_PROFILE_DIR") or os.getenv("LILITH_THUNDERBIRD_PROFILE_DIR")
    if override and override ~= "" then
        local dir = prefixed(prefix, override)
        if is_dir(dir) then
            return dir
        end
        return nil
    end
    if home == "" then
        return nil
    end
    local xdg_config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
    local roots = {
        xdg_config .. "/thunderbird",
        home .. "/.thunderbird",
        home .. "/.var/app/org.mozilla.Thunderbird/.thunderbird",
        home .. "/snap/thunderbird/common/.thunderbird",
    }
    for _, root in ipairs(roots) do
        local dir = profile_from_ini((prefix or "") .. root, prefix)
        if dir then
            return dir
        end
    end
    return nil
end

local function firefox_profile(prefix)
    local override = os.getenv("PADILHA_FIREFOX_PROFILE_DIR") or os.getenv("LILITH_FIREFOX_PROFILE_DIR")
    if override and override ~= "" then
        local dir = prefixed(prefix, override)
        if is_dir(dir) then
            return dir
        end
        return nil
    end
    if home == "" then
        return nil
    end
    local xdg_config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
    local roots = {
        xdg_config .. "/mozilla/firefox",
        home .. "/.mozilla/firefox",
        home .. "/.var/app/org.mozilla.firefox/.mozilla/firefox",
        home .. "/snap/firefox/common/.mozilla/firefox",
    }
    for _, root in ipairs(roots) do
        local dir = profile_from_ini((prefix or "") .. root, prefix)
        if dir then
            return dir
        end
    end
    return nil
end

-- The optional theme settings. `theme.lua` returns either { theme = {...} }
-- (the documented shape) or the theme table itself, so both
-- `return { theme = { enableBtop = false } }` and `return { enableBtop = false }`
-- work. Keep the old caelestia/cli.lua lookup for pre-rename installs.
function M.load_config()
    local candidates = {
        M.bases.config .. "/padilha/theme.lua",
        M.bases.config .. "/lilith/theme.lua",
        M.bases.config .. "/caelestia/cli.lua",
    }
    for _, path in ipairs(candidates) do
        local chunk = loadfile(path)
        if chunk then
            local ok, value = pcall(chunk)
            if ok and type(value) == "table" then
                if type(value.theme) == "table" then
                    return value
                end
                return { theme = value }
            end
        end
    end
    return {}
end

-- The list of applications. `template` is a file in share/templates/;
-- `base` picks the XDG directory; `hash` asks for #rrggbb; `reload` is a
-- shell command run after the file is written; `enabled` is the config key.
M.apps = {
    { id = "hypr", base = "config", dest = "hypr/scheme/current.lua", lua_table = true, enabled = "enableHypr" },
    { id = "hyprlock", base = "config", dest = "hypr/hyprlock.conf", template = "hyprlock.conf",
        enabled = "enableHyprlock" },
    { id = "fuzzel", base = "config", dest = "fuzzel/fuzzel.ini", template = "fuzzel.ini", enabled = "enableFuzzel" },
    { id = "btop", base = "config", dest = "btop/themes/caelestia.theme", template = "btop.theme", hash = true,
        reload = "killall -USR2 btop", enabled = "enableBtop" },
    { id = "lazygit", base = "config", dest = "lazygit/config.yml", template = "lazygit-{mode}.yml", hash = true,
        enabled = "enableLazygit" },
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
    { id = "micro", base = "config", dest = "micro/colorschemes/padilha.micro", template = "micro.micro",
        hash = true, enabled = "enableMicro" },
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
    local config = opts.config or M.load_config()

    -- scheme.json first: everything else can lag, this cannot.
    local ok, err = M.write(bases.state .. "/caelestia/scheme.json", require("json").encode(scheme))
    if not ok then
        errors[#errors + 1] = "scheme.json: " .. tostring(err)
    else
        written[#written + 1] = "scheme.json"
    end

    -- The pinned bar palette. It is static — black by design — and is read
    -- only when the shell config says bar.palette = "fixed".
    local matte_ok, matte = pcall(dofile, lib_dir .. "/../share/schemes/matte-bar.lua")
    if matte_ok and type(matte) == "table" then
        local wrote, write_err = M.write(bases.state .. "/caelestia/scheme-bar.json", require("json").encode({
            name = "matte-bar",
            flavour = "default",
            mode = "dark",
            variant = "monochrome",
            colours = matte,
        }))
        if wrote then
            written[#written + 1] = "scheme-bar.json"
        else
            errors[#errors + 1] = "scheme-bar.json: " .. tostring(write_err)
        end
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

    -- Spicetify: one ini per mode.
    if config_value(config, "enableSpicetify", true) ~= false then
        local template = read_template("spicetify-" .. scheme.mode .. ".ini")
        if template then
            local text = T.render(template, colours, { mode = scheme.mode })
            local write_ok, write_err = M.write(bases.config .. "/spicetify/Themes/caelestia/color.ini", text)
            if write_ok then
                written[#written + 1] = "spicetify/Themes/caelestia/color.ini"
            else
                errors[#errors + 1] = "spicetify: " .. tostring(write_err)
            end
        end
    end

    -- Discord clients: the theme is SCSS because the upstream stylesheet is;
    -- compile it once, then drop the CSS into whichever clients exist.
    if config_value(config, "enableDiscord", true) ~= false then
        local template = read_template("discord.scss")
        if template then
            local stamp = tostring(os.time()) .. "-" .. tostring(math.random(100000))
            local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/padilha-scss-" .. stamp
            os.execute("mkdir -p " .. quote(tmp))

            local vars = {}
            for name, value in pairs(colours) do
                vars[#vars + 1] = "$" .. name .. ": #" .. value .. ";"
            end
            table.sort(vars)
            local wrote = M.write(tmp .. "/_colours.scss", table.concat(vars, "\n") .. "\n")
                and M.write(tmp .. "/main.scss", template)
                and os.execute("sass --no-source-map " .. quote(tmp .. "/main.scss") .. " " .. quote(tmp .. "/out.css")
                    .. " 2>/dev/null") == true

            local f = wrote and io.open(tmp .. "/out.css", "r")
            local css = f and f:read("*a")
            if f then
                f:close()
            end

            if css then
                for _, client in ipairs({ "Equicord", "Vencord", "BetterDiscord", "equibop", "vesktop", "legcord" }) do
                    local dir = bases.config .. "/" .. client
                    if os.execute("test -d " .. quote(dir)) == true then
                        local write_ok, write_err = M.write(dir .. "/themes/caelestia.theme.css", css)
                        if write_ok then
                            written[#written + 1] = client .. "/themes/caelestia.theme.css"
                        else
                            errors[#errors + 1] = "discord " .. client .. ": " .. tostring(write_err)
                        end
                    end
                end
            else
                errors[#errors + 1] = "discord: sass did not produce a stylesheet"
            end
            os.execute("rm -rf " .. quote(tmp))
        end
    end

    -- Midnight Commander reads one skin file at startup; it is the only app
    -- here we cannot poke with a signal.
    if config_value(config, "enableMc", true) ~= false then
        local template = read_template("mc-skin.ini")
        if template then
            local text = replace_plain(template, "{{ $aliases }}", require("mcskin").aliases(colours))
            local write_ok, write_err = M.write(bases.data .. "/mc/skins/caelestia.ini", text)
            if write_ok then
                written[#written + 1] = "mc/skins/caelestia.ini"
            else
                errors[#errors + 1] = "mc skin: " .. tostring(write_err)
            end
        end
    end

    -- Firefox: the profile directory only exists after the first launch, so
    -- there is nothing to theme until then. Skip quietly; the palette is
    -- written on the next apply once a profile is present.
    if config_value(config, "enableFirefox", true) ~= false then
        local profile = firefox_profile(opts.prefix)
        if profile then
            local template = read_template("firefox.css")
            if not template then
                errors[#errors + 1] = "firefox: no template at share/templates/firefox.css"
            else
                local good, rendered = pcall(T.render, template, colours, { hash = true, mode = scheme.mode })
                if not good then
                    errors[#errors + 1] = "firefox: " .. tostring(rendered)
                else
                    -- Compatibility path: the dotfiles repository's
                    -- firefox/chrome/userChrome.css imports chrome/lilith.css
                    -- and is not ours to rename. The palette inside is Maria
                    -- Padilha's.
                    local dest = profile .. "/chrome/lilith.css"
                    local wrote, write_err = M.write(dest, rendered)
                    if wrote then
                        written[#written + 1] = dest
                    else
                        errors[#errors + 1] = "firefox: " .. tostring(write_err)
                    end
                end
            end
        end
    end

    -- Thunderbird: same palette, separate profile. Its chrome CSS and the
    -- legacy-stylesheets pref only take effect on the next Thunderbird start.
    if config_value(config, "enableThunderbird", true) ~= false then
        local profile = thunderbird_profile(opts.prefix)
        if profile then
            local template = read_template("thunderbird.css")
            if not template then
                errors[#errors + 1] = "thunderbird: no template at share/templates/thunderbird.css"
            else
                local good, rendered = pcall(T.render, template, colours, { hash = true, mode = scheme.mode })
                if not good then
                    errors[#errors + 1] = "thunderbird: " .. tostring(rendered)
                else
                    local css = profile .. "/chrome/padilha.css"
                    local wrote, write_err = M.write(css, rendered)
                    if wrote then
                        written[#written + 1] = css
                    else
                        errors[#errors + 1] = "thunderbird: " .. tostring(write_err)
                    end
                end
            end
        end
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
            'for p in /dev/pts/[0-9]*; do '
                .. 'timeout 0.1 tee "$p" < %s > /dev/null 2>&1 || true; done',
            quote(tmp)))
    end

    if opts.dconf then
        os.execute("dconf write /org/gnome/desktop/interface/color-scheme \"'prefer-"
            .. scheme.mode .. "'\" 2>/dev/null")
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
