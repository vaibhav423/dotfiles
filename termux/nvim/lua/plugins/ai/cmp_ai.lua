return {
  "Saghen/blink.cmp",
  optional = true,
  opts = function(_, opts)
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
        local copilot = require("copilot.suggestion")
        if copilot.is_visible() then copilot.accept_word() end
      end,
      "fallback",
    }
    opts.keymap["<C-Down>"] = {
      function()
        local copilot = require("copilot.suggestion")
        if copilot.is_visible() then copilot.accept_line() end
      end,
      "fallback",
    }
    opts.keymap["<C-q>"] = {
      function()
        local copilot = require("copilot.suggestion")
        if copilot.is_visible() then copilot.dismiss() end
      end,
      "fallback",
    }
    opts.keymap["<C-n>"] = {
      function()
        local copilot = require("copilot.suggestion")
        if copilot.is_visible() then copilot.next() end
      end,
      "fallback",
    }
    opts.keymap["<C-p>"] = {
      function()
        local copilot = require("copilot.suggestion")
        if copilot.is_visible() then copilot.prev() end
      end,
      "fallback",
    }
  end,
}
