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

  -- Refactoring / busca-substituição / git (adicionados via análise de plugins)
  { import = "astrocommunity.editing-support.refactoring-nvim" }, -- extract/inline (estilo JetBrains)
  { import = "astrocommunity.search.grug-far-nvim" }, -- search & replace no projeto (estilo VSCode)
  { import = "astrocommunity.git.diffview-nvim" }, -- diffs, merge conflict e histórico de arquivo

  -- Condicionais por caso de uso
  { import = "astrocommunity.programming-language-support.kulala-nvim" }, -- client HTTP/.http
  { import = "astrocommunity.pack.full-dadbod" }, -- client SQL (dadbod + UI + autocomplete)
  { import = "astrocommunity.editing-support.multicursors-nvim" }, -- multi-cursor estilo VSCode
  { import = "astrocommunity.editing-support.yanky-nvim" }, -- histórico de yank/paste (ring)
}
