return {

  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- { import = "nvchad.blink.lazyspec" }, -- test new blink

  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      view = { preserve_window_proportions = false },
      git = {
        ignore = false,
      },
      actions = {
        open_file = {
          resize_window = false,
        },
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    --build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css",
        "glsl",
        "rust",
      },

      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },

      injections = {
        enable = true,
      },
    },
  },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server", -- "stylua",
        "bash-language-server",
        -- data science
        "pyright",
        -- web dev
        "html-lsp",
        "css-lsp",
        "json-lsp",
        -- games
        "glsl_analyzer",
        -- low level
        "rust-analyzer",
      },
    },
  },

  -----------------------------------------------------------------------------------------
  --- VIBE CODING
  -----------------------------------------------------------------------------------------
  {
    'MeanderingProgrammer/render-markdown.nvim', lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ---@module 'render-markdown'
    opts = {
      anti_conceal = { enabled = false },
      file_types = { 'markdown', 'Avante', 'opencode_output' },
    },
    ft = { 'markdown', 'Avante', 'copilot-chat', 'opencode_output' },
  },

}
