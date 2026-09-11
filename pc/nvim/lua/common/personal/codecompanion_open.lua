vim.o.laststatus = 0
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false

vim.schedule(function()
  require("codecompanion.config").display.chat.window.layout = "buffer"
  require("codecompanion").chat()
end)
