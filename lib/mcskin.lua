-- Midnight Commander's skin, generated from the scheme.
--
-- Upstream mc reads a skin at startup and keeps it until restarted. The
-- Maria Padilha fork supports SIGUSR1 reload; lib/mcreload signals it only
-- when `mc -V` advertises the fork's live-skin-reload marker. The [aliases]
-- block is the only part that moves, so the layout below it is stable.

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

-- The [aliases] block mc expects, as text.
--
-- Every surface is explicit: `default` would make mc inherit the terminal's
-- background, which can still be the previous theme when a long-running
-- terminal opens a new mc, so the generated skin has to be self-contained.
function M.aliases(colours)
    local out = { "[aliases]" }
    for _, entry in ipairs(ALIASES) do
        local value
        for _, key in ipairs(entry[2]) do
            if colours[key] then
                value = colours[key]
                break
            end
        end
        if value then
            out[#out + 1] = ("    %s = #%s"):format(entry[1], value)
        end
    end
    return table.concat(out, "\n")
end

return M
