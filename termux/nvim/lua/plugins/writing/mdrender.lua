return {
  "MeanderingProgrammer/render-markdown.nvim",
  keys = {
    {
      "<leader>mt",
      function() require("lib.mdrender").toggle_converter() end,
      desc = "Toggle markdown latex converter",
    },
  },
  opts = function()
    -- Initialise converter state (persists across plugin reloads within a session)
    if vim.g.markdown_latex_converter == nil then
      vim.g.markdown_latex_converter = "utftex"
    end
    return {
      latex = { converter = vim.g.markdown_latex_converter },
    }
  end,
  config = function(_, opts)
    require("render-markdown").setup(opts)
  end,
}
