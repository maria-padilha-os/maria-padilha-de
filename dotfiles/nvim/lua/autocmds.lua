require "nvchad.autocmds"

-- The terminal sends SIGWINCH when the Hyprland window is resized. Neovim
-- normally redraws, but NvChad's UI and uneven splits can lag behind; equalise
-- the splits and force a repaint so the layout matches the new dimensions.
local resize_group = vim.api.nvim_create_augroup("padilha_resize", { clear = true })
local resize_timer = vim.uv.new_timer()

vim.api.nvim_create_autocmd("VimResized", {
  group = resize_group,
  desc = "Reflow splits and repaint after the window changes size",
  callback = function()
    -- SIGWINCH can arrive before the new grid size settles; wait a beat so
    -- wincmd = sees the final columns/lines instead of the old ones.
    resize_timer:stop()
    resize_timer:start(60, 0, vim.schedule_wrap(function()
      vim.cmd "tabdo wincmd ="
      vim.cmd "redraw!"
    end))
  end,
})

--local autocmd = vim.api.nvim_create_autocmd
--
--autocmd({ "BufWinEnter" }, {
--  pattern = "*",
--  callback = function()
--    -- Only run if the file actually has lines to fold
--    if vim.fn.line("$") > 1 then
--      -- zM sets foldlevel to 0; zR sets it exactly to the file's max depth
--      vim.cmd("normal! zMzr")
--    end
--  end,
--})
