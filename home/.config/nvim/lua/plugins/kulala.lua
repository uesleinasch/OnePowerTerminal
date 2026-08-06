-- Move o prefixo global do Kulala (HTTP/REST) de <Leader>r para <Leader>k.
--
-- Motivo: o pack astrocommunity.programming-language-support.kulala-nvim define
-- `global_keymaps_prefix = "<leader>r"`, que colide com o refactoring.nvim
-- (também em <Leader>r, com sufixos iguais: ri, rc, rb). Pior: o Kulala usa
-- <Leader>r como gatilho lazy, então abrir um .http passaria a sobrescrever os
-- atalhos de refactor na sessão. Com <Leader>k os dois coexistem.
--
-- Reverter: apague este arquivo (o Kulala volta para <Leader>r).

return {
  "mistweaverco/kulala.nvim",
  opts = {
    global_keymaps_prefix = "<Leader>k",
  },
}
