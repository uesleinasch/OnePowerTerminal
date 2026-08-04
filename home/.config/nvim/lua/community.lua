-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Lua (config development)
  { import = "astrocommunity.pack.lua" },

  -- TypeScript / Angular / Web
  { import = "astrocommunity.pack.typescript-all-in-one" },
  { import = "astrocommunity.pack.angular" },
  { import = "astrocommunity.pack.html-css" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.tailwindcss" },

  -- Haskell
  { import = "astrocommunity.pack.haskell" },

  -- C# / .NET — pack desativado por bug no Mason registry de csharp-ls.
  -- Configuração mínima em plugins/csharp.lua (omnisharp + csharpier + netcoredbg).

  -- Motion / Editing (produtividade)
  { import = "astrocommunity.motion.flash-nvim" },
  { import = "astrocommunity.motion.harpoon" },
  { import = "astrocommunity.motion.nvim-surround" },

  -- Diagnostics
  { import = "astrocommunity.diagnostics.trouble-nvim" },

  -- Quality-of-life
  { import = "astrocommunity.editing-support.todo-comments-nvim" },
  { import = "astrocommunity.recipes.vscode-icons" },
}
