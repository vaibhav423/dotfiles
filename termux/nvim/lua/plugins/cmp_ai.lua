return {
  "Saghen/blink.cmp",
  optional = true,
  opts = function(_, opts)
    local copilot = require "copilot.suggestion"
    if not opts.keymap then opts.keymap = {} end
    opts.keymap["<Tab>"] = {
      "snippet_forward",
      function()
        if vim.g.ai_accept then return vim.g.ai_accept() end
      end,
      "fallback",
    }
    opts.keymap["<C-Left>"] = { "snippet_backward", "fallback" }
    opts.keymap["<C-Right>"] = {
      function()
        if copilot.is_visible() then copilot.accept_word() end
      end,
      "fallback",
    }
    opts.keymap["<C-Down>"] = {
      function()
        if copilot.is_visible() then copilot.accept_line() end
      end,
      "fallback",
    }
    opts.keymap["<C-q>"] = {
      function()
        if copilot.is_visible() then copilot.dismiss() end
      end,
      "fallback",
    }
    opts.keymap["<C-n>"] = {
      function()
        if copilot.is_visible() then copilot.next() end
      end,
      "fallback",
    }
    opts.keymap["<C-p>"] = {
      function()
        if copilot.is_visible() then copilot.prev() end
      end,
      "fallback",
    }
  end,
}
