-- plugins/tools/noice.lua
-- Noice with ONLY the cmdline popup enabled. Everything else off.

return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    cmdline    = { enabled = true, view = "cmdline_popup" },
    messages   = { enabled = false },
    popupmenu  = { enabled = false },
    notify     = { enabled = false },
    lsp = {
      progress      = { enabled = false },
      hover         = { enabled = false },
      signature     = { enabled = false },
      message       = { enabled = false },
      documentation = { enabled = false },
    },
    health  = { checker = false },
    presets = {
      bottom_search         = false,
      command_palette       = false,
      long_message_to_split = false,
    },
    routes = {},
    views  = {},
  },
}
