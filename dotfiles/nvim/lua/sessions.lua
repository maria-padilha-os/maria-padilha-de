-- Remember the tab/split layout of each working directory across restarts.
--
-- Neovim does not persist this by itself: `:mksession` exists, but nothing
-- calls it. This module saves one session per cwd on exit and restores it when
-- nvim is started in that same cwd without file arguments.
local M = {}

local autosave_dir = vim.fn.stdpath "state" .. "/sessions"

-- Keep tabs, splits, buffers, folds and the cwd. Deliberately dropped:
--   terminal -- jobs cannot be resurrected, they would re-spawn stale CLIs
--   globals  -- plugin state (e.g. terminal ids) must not be restored blindly
--   options  -- would override this config on every start
vim.opt.sessionoptions = {
  "blank",
  "buffers",
  "curdir",
  "folds",
  "help",
  "tabpages",
  "winsize",
}

local function session_file()
  -- One file per working directory: cwd with every non-alphanumeric escaped.
  return autosave_dir .. "/" .. vim.fn.getcwd():gsub("[^%w]", "%%") .. ".vim"
end

-- Windows that make no sense in a saved layout: floating terminals/menus and
-- plugin sidebars. They are closed (and their scratch buffers wiped) right
-- before saving so the session only contains real file windows.
local function drop_transient_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local transient = vim.api.nvim_win_get_config(win).relative ~= ""
      or vim.bo[buf].buftype == "terminal"
      or vim.bo[buf].filetype == "NvimTree"

    if transient and #vim.api.nvim_list_wins() > 1 then
      pcall(vim.api.nvim_win_close, win, true)
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

-- `git commit` and friends open a throwaway buffer inside .git/; exiting them
-- must not overwrite the layout of the project they were run from.
local function is_git_message_buffer()
  for _, buf in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if buf.name:find "/%.git/" then
      return true
    end
  end
  return false
end

-- Opening nvim in a directory and leaving again should not erase a layout
-- saved earlier: only persist sessions that contain something worth keeping.
local function trivial_layout()
  return vim.fn.tabpagenr "$" == 1
    and #vim.api.nvim_tabpage_list_wins(0) == 1
    and #vim.fn.getbufinfo { buflisted = 1 } == 1
    and vim.api.nvim_buf_get_name(0) == ""
end

-- `nvim -S file`, `-c cmd` and `+cmd` already state what to open; sourcing a
-- session on top would undo that explicit request.
local function explicit_start()
  for _, arg in ipairs(vim.v.argv) do
    if arg == "-S" or arg == "-c" or arg == "--cmd" or arg:sub(1, 1) == "+" then
      return true
    end
  end
  return false
end

function M.save()
  if is_git_message_buffer() then
    return
  end

  drop_transient_windows()

  if trivial_layout() then
    return
  end

  vim.fn.mkdir(autosave_dir, "p")
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_file()))
  if not ok then
    vim.notify("session: could not save: " .. tostring(err), vim.log.levels.WARN)
  end
end

function M.restore()
  local file = session_file()
  if vim.fn.filereadable(file) == 0 then
    return
  end

  local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(file))
  if not ok then
    vim.notify("session: could not restore: " .. tostring(err), vim.log.levels.WARN)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", { callback = M.save })

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Files on the command line are an explicit request; a plain `nvim` in a
    -- known directory is a restart, so bring the tabs back.
    if vim.fn.argc() > 0 or explicit_start() then
      return
    end
    -- Let lazy.nvim/NvChad finish starting up before touching windows.
    vim.schedule(M.restore)
  end,
})

return M
