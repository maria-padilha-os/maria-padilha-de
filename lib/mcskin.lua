-- Midnight Commander's skin, generated from the scheme.
--
-- mc reads a skin at startup and keeps it until restarted; there is no
-- reload signal. The [aliases] block is the only part that moves, so the
-- layout below it is stable whatever the wallpaper does.

local M = {}

-- alias -> scheme keys, first present wins.
local ALIASES = {
    { "Main", { "surface", "background" } },
    { "MainFg", { "onSurface", "onBackground" } },
    { "MarkedFg", { "primary" } },
    { "HeaderFg", { "onSurfaceVariant", "outline" } },
    { "Selected", { "primaryContainer", "surfaceContainerHighest" } },
    { "SelectedFg", { "onPrimaryContainer", "onSurface" } },
    { "Dialog", { "surfaceContainerHigh", "surfaceContainer" } },
    { "DialogFg", { "onSurface", "onBackground" } },
    { "DialogFocus", { "primary" } },
    { "DialogFocusFg", { "onPrimary", "onBackground" } },
    { "Input", { "surfaceContainer", "surfaceContainerLow" } },
    { "PaleFg", { "outline", "outlineVariant" } },
    { "ShadowFg", { "shadow", "surfaceContainerLowest" } },
    { "ShadowBg", { "surfaceContainerLowest", "background" } },
    { "Error", { "error" } },
    { "ErrorFg", { "onError", "onBackground" } },
    { "ErrorFocus", { "errorDim", "error" } },
    { "Top", { "surfaceContainerHigh", "surfaceContainer" } },
    { "TopFg", { "onSurfaceVariant", "onSurface" } },
    { "Menu", { "surfaceContainer", "surfaceContainerHigh" } },
    { "MenuFg", { "onSurface", "onBackground" } },
    { "MenuSelected", { "primary" } },
    { "MenuSelectedFg", { "onPrimary", "onBackground" } },
    { "Bottom", { "surfaceContainerHighest", "surfaceContainerHigh" } },
    { "BottomFg", { "onSurfaceVariant", "onSurface" } },
    { "BottomNumber", { "primary" } },
    { "BottomNumberFg", { "onPrimary", "onBackground" } },
    { "Help", { "surfaceContainer", "surfaceContainerHigh" } },
    { "HelpFg", { "onSurface", "onBackground" } },
    { "HelpBoldFg", { "primary" } },
    { "HelpItalicFg", { "tertiary", "secondary" } },
    { "HelpLinkFg", { "blue", "primary" } },
    { "EditorLineNumber", { "outline" } },
    { "EditorWhitespace", { "outlineVariant", "outline" } },
    { "EditorVoid", { "surfaceContainerLowest", "background" } },
    { "EditorBookmark", { "primary" } },
    { "EditorFindAll", { "tertiary", "secondary" } },
    { "EditorFrameFg", { "outline" } },
    { "EditorFrameActiveFg", { "primary" } },
    { "EditorFrameDragFg", { "secondary", "primary" } },
    { "ViewerBoldFg", { "primary" } },
    { "ViewerUnderlinedFg", { "blue", "primary" } },
    { "DiffAdd", { "success", "green" } },
    { "DiffAddFg", { "onSuccess", "onBackground" } },
    { "DiffChangedLine", { "tertiary", "secondary" } },
    { "DiffChangedFg", { "onTertiary", "onBackground" } },
    { "DiffGap", { "error" } },
    { "DiffGapFg", { "onError", "onBackground" } },
    { "DirFg", { "blue", "primary" } },
    { "ExecFg", { "success", "green" } },
    { "SymlinkFg", { "mauve", "pink" } },
    { "StaleLinkFg", { "red", "error" } },
    { "DeviceFg", { "yellow", "peach" } },
    { "SpecialFg", { "peach", "yellow" } },
    { "CoreFg", { "maroon", "red" } },
    { "TempFg", { "overlay0", "outline" } },
    { "ArchiveFg", { "sky", "blue" } },
    { "DocFg", { "lavender", "mauve" } },
    { "SourceFg", { "teal", "blue" } },
    { "MediaFg", { "sapphire", "blue" } },
    { "GraphFg", { "pink", "mauve" } },
    { "DbFg", { "peach", "yellow" } },
}

-- Aliases that resolve to the terminal's background instead of a surface
-- colour. MC's `default` keyword is only valid in the background slot and
-- leaves the cell unpainted, so the terminal's own background — and the
-- window opacity behind it — shows through.
--
-- State and diff highlights are deliberately absent: they are small opaque
-- blocks whose foreground aliases (SelectedFg, ErrorFg, DiffAddFg, ...) are
-- picked to contrast with those blocks. Turning them into `default` would
-- drop the block and can leave dark-on-dark or light-on-light text.
local TRANSPARENT = {
    Main = true,
    Dialog = true,
    Input = true,
    Top = true,
    Menu = true,
    Bottom = true,
    Help = true,
    ShadowBg = true,
    EditorVoid = true,
    EditorLineNumber = true,
}

-- The [aliases] block mc expects, as text.
function M.aliases(colours)
    local out = { "[aliases]" }
    for _, entry in ipairs(ALIASES) do
        local name = entry[1]
        if TRANSPARENT[name] then
            out[#out + 1] = ("    %s = default"):format(name)
        else
            local value
            for _, key in ipairs(entry[2]) do
                if colours[key] then
                    value = colours[key]
                    break
                end
            end
            if value then
                out[#out + 1] = ("    %s = #%s"):format(name, value)
            end
        end
    end
    return table.concat(out, "\n")
end

return M
