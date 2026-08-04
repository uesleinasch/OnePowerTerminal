---@type LazySpec
return {
  "basola21/PDFview",
  lazy = false,
  dependencies = { "nvim-telescope/telescope.nvim" },
  keys = {
    {
      "<leader>jj",
      function() require("pdfview.renderer").next_page() end,
      desc = "PDFview: próxima página",
    },
    {
      "<leader>kk",
      function() require("pdfview.renderer").previous_page() end,
      desc = "PDFview: página anterior",
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("BufReadPost", {
      pattern = "*.pdf",
      callback = function()
        local file_path = vim.api.nvim_buf_get_name(0)
        require("pdfview").open(file_path)
      end,
    })
  end,
}
