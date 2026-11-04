-- Padilha terminal.
--
-- WezTerm is configured in Lua, like the compositor and the desktop config,
-- and it renders from the same palette as everything else: the sixteen ANSI
-- colours are the `term0`..`term15` roles Caelestia already writes into
-- scheme.json for foot's escape sequences.

local wezterm = require 'wezterm'
local config = (wezterm.config_builder and wezterm.config_builder()) or {}

local SCHEME = (os.getenv 'HOME') .. '/.local/state/caelestia/scheme.json'

-- Read once per config load. A wallpaper change does not reload it yet; our
-- theme engine will touch this file when it lands.
local function scheme()
    local f = io.open(SCHEME, 'r')
    if not f then return nil end
    local body = f:read '*a'
    f:close()
    local ok, data = pcall(wezterm.json_parse, body)
    if not ok or type(data) ~= 'table' then return nil end
    return data
end

local data = scheme() or {}
local c = data.colours or {}
local mode = data.mode

local function hex(name, fallback)
    local value = c[name]
    if not value then return fallback end
    return '#' .. (value:gsub('^#', ''))
end

config.colors = {
    foreground = hex('onSurface', '#e6edf3'),
    background = hex('surface', '#000000'),
    cursor_bg = hex('secondary', '#f1b7cb'),
    cursor_border = hex('secondary', '#f1b7cb'),
    cursor_fg = hex('surface', '#000000'),
    selection_bg = hex('secondary', '#f1b7cb'),
    selection_fg = hex('onSecondary', '#000000'),
    ansi = {
        hex('term0', '#1a1a1a'), hex('term1', '#e06c75'),
        hex('term2', '#98c379'), hex('term3', '#e5c07b'),
        hex('term4', '#61afef'), hex('term5', '#c678dd'),
        hex('term6', '#56b6c2'), hex('term7', '#dcdfe4'),
    },
    brights = {
        hex('term8', '#5c6370'), hex('term9', '#e06c75'),
        hex('term10', '#98c379'), hex('term11', '#e5c07b'),
        hex('term12', '#61afef'), hex('term13', '#c678dd'),
        hex('term14', '#56b6c2'), hex('term15', '#ffffff'),
    },
}

-- Matches foot: JetBrains Mono 12, 25px of padding, no decorations, and mc on
-- top of fish (F10 quits mc into the shell in the same window).
config.font = wezterm.font_with_fallback { 'JetBrains Mono Nerd Font', 'Noto Color Emoji' }
config.font_size = 12.0
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' } -- foot draws them separately

config.window_padding = { left = 25, right = 25, top = 25, bottom = 25 }
config.window_decorations = 'NONE'
-- Slightly less transparent than the deep-night look; the Hyprland WezTerm
-- rule matches this so the global 0.95 opacity rule cannot flatten it.
config.window_background_opacity = 0.85
config.default_prog = { 'sh', '-c', 'MC_SKIN=caelestia mc; exec fish' }

config.scrollback_lines = 10000
config.audible_bell = 'Disabled'
config.check_for_updates = false
config.use_ime = true
config.hide_tab_bar_if_only_one_tab = true
-- SUPER+Q is the compositor's close; WezTerm should not ask again.
config.window_close_confirmation = 'NeverPrompt'

return config
