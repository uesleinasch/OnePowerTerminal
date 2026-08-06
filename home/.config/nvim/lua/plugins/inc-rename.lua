-- inc-rename.nvim: preview ao vivo do LSP rename (estilo VSCode/JetBrains).
-- Enquanto voce digita o novo nome, todas as ocorrencias sao realcadas e
-- atualizadas em tempo real (usa `inccommand`), em vez do prompt simples.
--
-- Remapeia `grn` (rename nativo do Neovim 0.11) para abrir o :IncRename ja
-- pre-preenchido com o simbolo sob o cursor. Basta editar o nome e <Enter>.
-- Para reverter, apague este arquivo (o `grn` volta ao comportamento padrao).

return {
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
  },
  {
    "AstroNvim/astrocore",
    opts = {
      mappings = {
        n = {
          grn = {
            function() return ":IncRename " .. vim.fn.expand "<cword>" end,
            expr = true,
            desc = "Rename symbol (preview)",
          },
        },
      },
    },
  },
}
