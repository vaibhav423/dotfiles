--- https://docs.astronvim.com/recipes/status/#_top
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    status = {
      components = {
        lsp = {
          on_click = {
            name = "heirline_lst",
            callback = function() end,
          },
        },
        -- git_branch = {
        --   on_click = {
        --     name = "foo",
        --     callback = function() end,
        --   },
        -- },
      },
    },
  },
}
