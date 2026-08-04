-- C# / .NET (substitui o astrocommunity.pack.cs)
-- Usa omnisharp como LSP e csharpier como formatter.
-- Não usa csharp-ls porque o Mason registry tem nome divergente (`csharp-language-server`)
-- enquanto o pacote no NuGet é `csharp-ls`, o que faz o dotnet tool install falhar.

---@type LazySpec
return {
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = function(_, opts)
      if opts.ensure_installed ~= "all" then
        opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "c_sharp" })
      end
    end,
  },

  -- LSP via mason-lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "omnisharp" })
    end,
  },

  -- Formatter via none-ls
  {
    "jay-babu/mason-null-ls.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "csharpier" })
    end,
  },

  -- DAP
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "coreclr" })
    end,
  },

  -- conform.nvim formatter assignment
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        cs = { "csharpier" },
      },
    },
  },
}
