-- polish.lua: runs after all plugins are loaded.
-- Used only for final setup that cannot live inside a plugin spec.

-- Add jeerem command abbreviation
vim.cmd("cnoreabbrev jeerem Jeerem")

local droid = vim.fn.executable("droid") == 1
local termux_api_dir = "/usr/local/bin/"
local has_termux_api = vim.fn.executable(termux_api_dir .. "termux-clipboard-get") == 1

if droid then
  vim.g.clipboard = {
    name = "droid",
    copy = {
      ["+"] = function(lines, regtype)
        local text = table.concat(lines, "\n")
        local b64 = vim.base64.encode(text)
        vim.fn.system({ "droid", "clipboard-set", b64 })
      end,
      ["*"] = function(lines, regtype)
        local text = table.concat(lines, "\n")
        local b64 = vim.base64.encode(text)
        vim.fn.system({ "droid", "clipboard-set", b64 })
      end,
    },
    paste = {
      ["+"] = function()
        local output = vim.fn.system({ "droid", "clipboard", "get" })
        return vim.split(output:gsub("\n$", ""), "\n")
      end,
      ["*"] = function()
        local output = vim.fn.system({ "droid", "clipboard", "get" })
        return vim.split(output:gsub("\n$", ""), "\n")
      end,
    },
    cache_enabled = 0,
  }
elseif has_termux_api then
  vim.g.clipboard = {
    name = "termux-api",
    copy = {
      ["+"] = { termux_api_dir .. "termux-clipboard-set" },
      ["*"] = { termux_api_dir .. "termux-clipboard-set" },
    },
    paste = {
      ["+"] = { termux_api_dir .. "termux-clipboard-get" },
      ["*"] = { termux_api_dir .. "termux-clipboard-get" },
    },
    cache_enabled = 0,
  }
elseif vim.env.SSH_TTY then
  vim.g.clipboard = {
    name = 'osc52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
      ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
    },
    paste = {
      ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
      ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
    },
  }
else
  vim.opt.clipboard:append("unnamedplus")
end


-- stable method works crossplatform

-- if vim.env.SSH_TTY then
--   vim.o.clipboard = "unnamedplus"
--
--   local function paste()
--     return {
--       vim.fn.split(vim.fn.getreg(""), "\n"),
--       vim.fn.getregtype(""),
--     }
--   end
--
--   -- this method wont paste from system clipboard if u do justP
--   vim.g.clipboard = {
--     name = "OSC 52",
--     copy = {
--       ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
--       ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
--     },
--     paste = {
--       ["+"] = paste,
--       ["*"] = paste,
--     },
--   }
--
-- end
