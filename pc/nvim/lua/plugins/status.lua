return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    status = {
      components = {
        lsp = {
          on_click = {
            name = "heirline_lsp",
            callback = function() end,
          },
        },
      },
    },
  },
}
