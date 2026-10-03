vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false

vim.schedule(function()
  require("codecompanion.config").display.chat.window.layout = "buffer"
  require("codecompanion").chat()

  vim.keymap.set("n", "<Leader>an", function()
    vim.fn.system { "tmux", "new-window", "-t", "gemini-chat", "nvim", "-S", vim.fn.expand "~/.config/nvim/lua/common/personal/codecompanion_open.lua" }
  end, { desc = "New CodeCompanion window" })
end)
