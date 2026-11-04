-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local options = {
  base46 = {
    theme = "ayu_dark",
    -- hl_override = {
    -- 	Comment = { italic = true },
    -- 	["@comment"] = { italic = true },
    -- },
    theme_toggle = { "ayu_dark", "ayu_dark" },
    -- ayu_dark is a dark theme with light text. The terminal now follows the
    -- wallpaper (white during the day), so a transparent Normal made the text
    -- almost unreadable. Keep base46 themes opaque; the caelestia colorscheme
    -- has its own transparency setting.
    transparency = false,
  },

  -- nvdash = { load_on_startup = true },

  ui = {
    tabufline = {
      lazyload = false,
      order = { "buffers", "tabs", "btns" },
    },
  },
}

local status, chadrc = pcall(require, "chadrc")
return vim.tbl_deep_extend("force", options, status and chadrc or {})
