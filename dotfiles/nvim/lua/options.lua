require "nvchad.options"
local opt = vim.opt
-- local o = vim.o

opt.foldmethod = "indent"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevel = 99
opt.wrap = false

vim.cmd[[ au FileType vim setlocal fo-=c fo-=r fo-=o ]]

vim.filetype.add({
  extension = {
    script = "lua",
    gui_script = "lua",
    fp = "glsl",
    fs = "glsl",
    vp = "glsl",
  }
})
