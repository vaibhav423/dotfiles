return {
  "kylechui/nvim-surround",
  version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
  event = "VeryLazy",
  opts = {
    surrounds = {
      ["~"]= {
            add = { "~", "~" },
            -- find = function()
            --     return M.get_selection({ motion = "a'" })
            -- end,
            delete = "^(.)().-(.)()$",
            label = "'...'",
        },
    }
  },
}
