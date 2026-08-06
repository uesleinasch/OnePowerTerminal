---@type LazySpec
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
  ft = { "markdown" },
  -- Compila o servidor de preview (usa yarn, já disponível no sistema)
  build = "cd app && yarn install",
  init = function()
    vim.g.mkdp_auto_close = 0 -- não fecha o preview ao trocar de buffer
    vim.g.mkdp_theme = "dark"
  end,
  keys = {
    { "<Leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview (browser)" },
  },
}
