local vars = require("variables")
local home = os.getenv("HOME")

-- Themes
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", vars.cursorTheme)
hl.env("XCURSOR_SIZE", vars.cursorSize)

-- Toolkit backends
-- Compose dead keys (ABNT2: ' " ^ ~) in Qt apps. The Caelestia lock screen
-- feeds a real TextInput, so this is what turns dead-key sequences into á/ã.
hl.env("QT_IM_MODULE", "compose")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Default terminal, for apps and scripts that honour $TERMINAL.
hl.env("TERMINAL", vars.terminal)

-- XDG specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Local secrets live in env.local.lua (gitignored).
-- Copy env.local.example.lua to env.local.lua and fill in your keys.
do
    local home = os.getenv("HOME")
    local path = home .. "/.config/hypr/hyprland/env.local.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end

-- Others
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- SSH agent socket, started by execs.lua (see hypr/utils/ssh-agent.sh). Set
-- here too so apps get it from the first spawn, not only after the script runs.
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if runtime_dir then
    hl.env("SSH_AUTH_SOCK", runtime_dir .. "/ssh-agent.sock")
end

-- Padilha shell: the project lives in ~/Códigos/padilha now, out of ~/.config,
-- and ~/.config/quickshell/caelestia symlinks into its shell/. The C++ QML
-- modules come from its build tree.
hl.env("QML2_IMPORT_PATH", home .. "/Códigos/padilha/build/qml")

-- The project's own commands (padilha, padilha-shot, padilha-record, ...).
-- Packaged installs put them in /usr/bin and this line can go.
if os.getenv("PATH") then
    hl.env("PATH", home .. "/Códigos/padilha/bin:" .. os.getenv("PATH"))
end
