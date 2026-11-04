require "nvchad.mappings"
local term = require("nvchad.term")

local nomap = vim.keymap.del
nomap({"n", "t"}, "<A-i>")
nomap({"n", "t"}, "<A-h>")
nomap("n", "<C-n>")

local map = vim.keymap.set
local replace = vim.api.nvim_replace_termcodes

--map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map({"n", "i", "v"}, "<C-s>", "<cmd> w <cr>",                                       {desc = "General ﬚  save file"})
map("n",             "<F3>",  "<cmd> w <CR>",                                       {desc = "General ﬚  save file" })
map("n",             "lç",    "<cmd> w <CR>",                                       {desc = "General ﬚  save file" })
map("n",             "<F2>",  "<cmd> qa <CR>",                                      {desc = "General close all files"})
map("n",             "<F4>",  "<cmd> q <CR>",                                       {desc = "General quit" })
map("n",             "<A-ç>", "<cmd> q <CR>",                                       {desc = "General ﬚  save file"})
map("t",             "<A-ç>", replace("<C-c> exit<CR> exit<CR><C-\\><C-N>:q<CR>", true, true, true), { desc = "Term close term" })
map("n",             "<F9>", "<cmd> source Session.vim <CR>",                       {desc = "General load session" })
map("n",             "ç",     "<cmd> :lua vim.diagnostic.open_float() <CR>",        {desc = "General show floating diagnostics"})
map({"n", "v"},      "\\",    "<C-\\><C-N>:NvimTreeToggle<CR>",                     {desc = "General toggle nvim-tree"})

-- Tab/Buf
map("n", "<A-n>", "<cmd> tabnext <CR>",                                     {desc = "Tab/Buf next tab" })
map("n", "<A-p>", "<cmd> tabprev <CR>",                                     {desc = "Tab/Buf prev tab"})
map("n", "<A-N>", "<cmd> lua require('nvchad.tabufline').move_buf(1)<CR>",  {desc = "Tab/Buf move buffer left"})
map("n", "<A-P>", "<cmd> lua require('nvchad.tabufline').move_buf(-1)<CR>", {desc = "Tab/Buf move buffer right"})

-- Close terminal buffers automatically when the process exits
vim.api.nvim_create_autocmd("TermClose", {
  pattern = "*",
  callback = function(args)
    -- Only close if it's a terminal buffer and we're still in it
    vim.schedule(function()
      local buf = args.buf
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end)
  end,
})

-- Geometry for a borderless float that fills everything to the right of
-- nvim-tree (the sidebar plus its vertical separator stay visible). With no
-- tree open it fills the whole editor. NvChad turns these fractions back into
-- cells with math.ceil, so the tiny epsilon keeps integer columns exact.
local free_area_float = function ()
  local cols = vim.o.columns
  local left, width = 0, cols

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      local col = vim.api.nvim_win_get_position(win)[2]
      local w = vim.api.nvim_win_get_width(win)
      if col == 0 then
        left = w + 1 -- skip the separator column drawn next to the tree
        width = cols - left
      else
        width = col - 1
      end
      break
    end
  end

  local eps = 1e-6
  return {
    relative = "editor",
    width = math.max(width, 1) / cols - eps,
    height = 1.0, -- clamped by Neovim to the editor height above the cmdline
    row = 0,
    col = left / cols - eps,
    border = "none",
  }
end

local mterm = function (pos, id, cmd)
  return function ()
    -- cmd may be a function so the command can be built at press time (e.g.
    -- from the current project root) instead of once at startup.
    local command = type(cmd) == "function" and cmd() or cmd

    if id == "1" then
      term.toggle { pos = pos, id = id, cmd = command, float_opts = { width = 1.0, height = 0.33, row = 0.7 } }
    elseif id == "2" then
      term.toggle { pos = pos, id = id, cmd = command, float_opts = { width = 0.75, height = 0.66, col = 0.25 } }
    elseif id == "3" then
      term.toggle { pos = pos, id = id, cmd = command, float_opts = { width = 0.49, height = 1.0, col = 0.5 } }
    elseif id == "4" then
      term.toggle { pos = pos, id = id, cmd = command, float_opts = free_area_float() }
    else
      term.toggle { pos = pos, id = id, cmd = command}
    end
  end
end
-- Term
map({ "n", "t", "i" },      "<A-j>", mterm("float", "1"),                               { desc = "Term toggle f"   })
map({ "n", "t", "i" },      "<A-k>", mterm("float", "2"),                               { desc = "Term toggle F"   })
map({ "n", "t", "i" },      "<A-l>", mterm("float", "3"),                               { desc = "Term toggle v"   })
map({ "n", "t", "i" },      "<A-h>", mterm("float", "4"),                               { desc = "Term toggle hf"  })
map({ "n", "t", "i" },      "<A-;>", mterm("sp",    "h"),                               { desc = "Term toggle h"   })
map({ "n", "t", "i" },      "<A-:>", mterm("vsp",   "v"),                               { desc = "Term toggle v"   })
--map({ "t", "t", "i" },      "<C-t>", replace("<C-\\><C-N>", true, true, true),          { desc = "Term normal mode"})

-- AI
-- NB: call the binary, not the `dsh-tui` shell alias: nvim terminals run
-- `&shell -c`, which never sources .zshrc/.bashrc, so aliases don't exist there.
map("n", "<leader>ld", mterm("float", "4", "dsh --profile dsh-tui . && exit"), { desc = "dsh-tui"  })
map("n", "<leader>lq", mterm("float", "4", "qwen && exit"     ), { desc = "quencode"   })

-- cli apps
map("n", "<leader>lg", mterm("float", "3", "lazygit && exit"), { desc = "lazygit"})
map("n", "<leader>lb", mterm("float", "2", "btop && exit"), { desc = "btop"})
map("n", "<leader>lm", mterm("float", "2", "mc && exit"), { desc = "mc"})

-- defold: both game repos ship tools/defold/run.sh, which resolves the project
-- from its own path; find that root from the buffer so the mapping works no
-- matter where nvim was started.
local defold = function (args)
  return function ()
    local root = vim.fs.root(0, "game.project") or vim.fn.getcwd()
    local script = vim.fn.shellescape(root .. "/tools/defold/run.sh")
    return ("%s%s && exit"):format(script, args ~= "" and (" " .. args) or "")
  end
end

map("n", "<BS>",   mterm("float", "1", defold ""),           { desc = "defold build & run" })
map("n", "<A-BS>", mterm("float", "1", defold "--no-build"), { desc = "defold relaunch"     })
