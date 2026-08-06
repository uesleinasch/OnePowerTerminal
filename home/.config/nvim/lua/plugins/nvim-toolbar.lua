---@type LazySpec
return {
  {
    "uesleinasch/nvim-toolbar",
    event = "VeryLazy",
    opts = {
      -- "window" mantem as abas de buffer do heirline na tabline
      position = "window",
      echo = true,
      hover = true,
    },
  },
}
