return {
  "MeanderingProgrammer/render-markdown.nvim",
  keys = {
    {
      "<leader>mt",
      function() require("lib.mdrender").toggle_converter() end,
      desc = "Toggle markdown latex converter",
    },
  },
  opts = function(_, opts)
    -- Initialise converter state (persists across plugin reloads within a session)
    if vim.g.markdown_latex_converter == nil then
      vim.g.markdown_latex_converter = "utftex"
    end
    opts.latex = { converter = vim.g.markdown_latex_converter }
    return opts
  end,
}
