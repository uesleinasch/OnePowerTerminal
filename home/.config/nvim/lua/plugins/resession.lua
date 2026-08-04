-- Auto-save / auto-load de sessões por diretório.
-- Sai do nvim e volta no mesmo lugar (buffers, splits, tabs).

---@type LazySpec
return {
  "stevearc/resession.nvim",
  opts = {
    autosave = {
      enabled = true,
      interval = 60,
      notify = false,
    },
  },
  init = function()
    local resession = require "resession"

    -- Salva sessão por diretório atual ao sair do nvim
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function() resession.save(vim.fn.getcwd(), { dir = "dirsession", notify = false }) end,
    })

    -- Carrega sessão do diretório atual ao entrar (apenas se nvim foi aberto sem argumentos)
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc(-1) == 0 then
          local ok = pcall(resession.load, vim.fn.getcwd(), { dir = "dirsession", silence_errors = true })
          if not ok then return end
        end
      end,
      nested = true,
    })
  end,
}
