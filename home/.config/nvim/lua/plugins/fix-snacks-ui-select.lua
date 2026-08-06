-- Corrige o erro E5108 "Invalid 'height': Number is not integral" disparado
-- pelo picker de `vim.ui.select` do snacks.nvim (ex.: tecla Y / copy_selector
-- do neo-tree) quando a area do Neovim esta baixa (poucas linhas).
--
-- Causa raiz (snacks.nvim/lua/snacks/picker/select.lua):
--     box.height = math.max(math.min(#items, vim.o.lines * 0.8 - 10), 2)
-- `vim.o.lines * 0.8 - 10` e fracionario. Quando ele fica menor que #items,
-- o math.min escolhe esse valor quebrado, que chega em nvim_win_set_config
-- (so aceita inteiros) e estoura o E5108.
--
-- Nao da para sobrescrever pelo `opts` do snacks: o `layout.config` interno
-- tem precedencia maxima no merge do picker. A unica via limpa e injetar nosso
-- proprio `layout.config` (identico, porem com math.floor) atraves de
-- `opts.snacks` no `vim.ui.select`, que e mesclado por ultimo (select.lua:73).
--
-- Mantemos o picker bonito do snacks. Para reverter, basta apagar este arquivo.

return {
  "AstroNvim/astrocore",
  opts = {
    autocmds = {
      fix_snacks_select_height = {
        {
          event = "User",
          pattern = "VeryLazy",
          once = true,
          desc = "Corrige altura fracionaria do vim.ui.select do snacks (E5108)",
          callback = function()
            vim.schedule(function()
              local ok, picker = pcall(require, "snacks.picker")
              if not ok or vim.g._snacks_select_height_fix then return end
              vim.g._snacks_select_height_fix = true

              vim.ui.select = function(items, sopts, on_choice)
                sopts = sopts or {}
                sopts.snacks = vim.tbl_deep_extend("force", sopts.snacks or {}, {
                  layout = {
                    config = function(layout)
                      for _, box in ipairs(layout.layout) do
                        if box.win == "list" and not box.height then
                          box.height =
                            math.max(math.min(#items, math.floor(vim.o.lines * 0.8 - 10)), 2)
                        end
                      end
                    end,
                  },
                })
                return picker.select(items, sopts, on_choice)
              end
            end)
          end,
        },
      },
    },
  },
}
