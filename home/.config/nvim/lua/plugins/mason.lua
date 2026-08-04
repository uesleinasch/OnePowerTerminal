-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- Lua
        "lua-language-server",
        "stylua",

        -- TypeScript / Angular / Web
        "typescript-language-server",
        "angular-language-server",
        "eslint-lsp",
        "eslint_d",
        "prettierd",
        "html-lsp",
        "css-lsp",
        "json-lsp",
        "tailwindcss-language-server",

        -- Haskell
        -- NOTE: haskell-language-server is best installed via ghcup, not Mason.
        --       Run: `ghcup install hls` once on the system.
        "fourmolu",

        -- C# / .NET
        -- NOTE: requires `dotnet-sdk` on the system PATH.
        "omnisharp",
        "csharpier",
        "netcoredbg",

        -- Misc
        "tree-sitter-cli",
      },
    },
  },
}
