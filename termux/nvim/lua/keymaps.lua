vim.keymap.set("n", "<leader>rt", ":w<CR>:RunCode<CR>", { noremap = true, silent = false })
vim.keymap.set("n", "<leader>rr", ":w<CR>:RunFile better_term<CR>", { noremap = true, silent = false })
local betterTerm = require "betterTerm"
-- toggle copilot auto-trigger for current buffer
vim.keymap.set("n", "<leader>tc", function()
  local ok, suggestion = pcall(require, "copilot.suggestion")
  if not ok then
    vim.notify("Copilot plugin not loaded", vim.log.levels.WARN)
    return
  end
  suggestion.toggle_auto_trigger()
end, { desc = "Toggle Copilot auto-trigger" })

-- accept a single word suggestion from copilot
-- Toggle the first terminal (ID defaults to index_base, which is 0)
vim.keymap.set({ "n", "t" }, "<C-;>", function() betterTerm.open() end, { desc = "Toggle terminal" })

-- Open a specific terminal
vim.keymap.set({ "n", "t" }, "<C-/>", function() betterTerm.open(1) end, { desc = "Toggle terminal 1" })

-- Select a terminal to focus
vim.keymap.set("n", "<leader>tt", betterTerm.select, { desc = "Select terminal" })

-- Rename the current terminal
vim.keymap.set("n", "<leader>tr", betterTerm.rename, { desc = "Rename terminal" })

-- Toggle the tabs bar
vim.keymap.set("n", "<leader>tb", betterTerm.toggle_tabs, { desc = "Toggle terminal tabs" })
vim.keymap.set("n", "<leader>rf", ":RunFile<CR>", { noremap = true, silent = false })
vim.keymap.set("n", "<leader>rft", ":RunFile tab<CR>", { noremap = true, silent = false })
vim.keymap.set("n", "<leader>rp", ":RunProject<CR>", { noremap = true, silent = false })
vim.keymap.set('n', '<leader>jr', ':Jeerem<CR>', { noremap = true, silent = true, desc = 'Insert system reminder' })
--vim.keymap.set('n', '<leader>fw', function()
--  require("snacks").picker.files { dirs = { "/storage/emulated/0/Documents/Fire" }, desc = "Fire Workspace Files" }
--end, { desc = "Find Fire workspace files" })
