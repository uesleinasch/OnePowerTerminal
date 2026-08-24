-- Alinha o colorscheme ao flavor escolhido por `powerterminal theme`.
-- O plugin em si vem de `astrocommunity.colorscheme.catppuccin` (community.lua);
-- aqui só resolvemos o flavor e dizemos ao AstroUI para usá-lo.

local DEFAULT = "mocha"
local FLAVOURS = { latte = true, frappe = true, macchiato = true, mocha = true }

-- Lido em runtime, não gerado: o arquivo é a fonte única compartilhada com o
-- kitty e o prompt, então trocar o tema não precisa reescrever este spec.
local function flavour()
  local path = vim.fn.expand "~/.config/powerterminal/theme"
  if vim.fn.filereadable(path) == 0 then return DEFAULT end
  local value = vim.trim(vim.fn.readfile(path, "", 1)[1] or "")
  return FLAVOURS[value] and value or DEFAULT
end

---@type LazySpec
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    ---@diagnostic disable-next-line: missing-fields
    opts = { flavour = flavour() },
  },
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = { colorscheme = "catppuccin" },
  },
}
