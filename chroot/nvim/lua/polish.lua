-- polish.lua: runs after all plugins are loaded.
-- Used only for final setup that cannot live inside a plugin spec.

-- Add jeerem command abbreviation
vim.cmd("cnoreabbrev jeerem Jeerem")

local droid = vim.fn.executable("droid") == 1
local ssh_conn = vim.env.SSH_CONNECTION or ""
local is_localhost_ssh = ssh_conn:match("^127%.0%.0%.1") or ssh_conn:match("^::1")

if not vim.env.SSH_TTY then
  vim.opt.clipboard:append("unnamedplus")
elseif droid and is_localhost_ssh then
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
else
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
