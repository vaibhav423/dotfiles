vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false

vim.schedule(function()
  local config = require "codecompanion.config"
  config.display.chat.window.layout = "buffer"
  config.interactions.chat.keymaps.new_window = {
    callback = function()
      vim.fn.system {
        "tmux",
        "new-window",
        "-t",
        "gemini-chat",
        "nvim",
        "-S",
        vim.fn.expand "~/.config/nvim/lua/common/personal/codecompanion_open.lua",
      }
    end,
    description = "New CodeCompanion window",
    modes = { n = "gn" },
  }

  require("codecompanion").chat()
end)
