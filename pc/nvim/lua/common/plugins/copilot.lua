-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/completion/copilot-lua-cmp/init.lua
-- https://github.com/zbirenbaum/copilot.lua
local function has_words_before()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
end

local function copilot_action(action)
  local copilot = require "copilot.suggestion"
  return function()
    if copilot.is_visible() then
      copilot[action]()
      return true -- doesn't run the next command
    end
  end
end

return {
  "zbirenbaum/copilot.lua",
  specs = {
    { import = "astrocommunity.completion.copilot-lua" },
    {
      "saghen/blink.cmp",
      optional = true,
      opts = function(_, opts)
        if not opts.keymap then opts.keymap = {} end

        opts.keymap["<Tab>"] = {
          copilot_action "accept",
          "select_next",
          "snippet_forward",
          function(cmp)
            if has_words_before() or vim.api.nvim_get_mode().mode == "c" then return cmp.show() end
          end,
          "fallback",
        }
        opts.keymap["<C-X>"] = { copilot_action "next" }
        opts.keymap["<C-Z>"] = { copilot_action "prev" }
        opts.keymap["<C-Right>"] = { copilot_action "accept_word" }
        opts.keymap["<C-w>"] = { copilot_action "accept_word" }
        opts.keymap["<C-Down>"] = { copilot_action "accept_line" }
        opts.keymap["<C-J>"] = { copilot_action "accept_line", "select_next", "fallback" }
        opts.keymap["<C-e>"] = { copilot_action "dismiss" }
      end,
    },
  },
}
