-- polish.lua: runs after all plugins are loaded.
-- Used only for final setup that cannot live inside a plugin spec.

-- Encryption support for .enc files
require("lib.encryption").setup()

-- Jeerem date-countdown command
require("lib.jeerem").setup()

-- Use termux-api for clipboard when in Termux (even via SSH)
-- This avoids the 5-second OSC 52 timeout
local termux_api_dir = "/usr/local/bin/"
local has_termux_api = vim.fn.executable(termux_api_dir .. "termux-clipboard-get") == 1

-- if has_termux_api then
--   vim.g.clipboard = {
--     name = "termux-api",
--     copy = {
--       ["+"] = { termux_api_dir .. "termux-clipboard-set" },
--       ["*"] = { termux_api_dir .. "termux-clipboard-set" },
--     },
--     paste = {
--       ["+"] = { termux_api_dir .. "termux-clipboard-get" },
--       ["*"] = { termux_api_dir .. "termux-clipboard-get" },
--     },
--     cache_enabled = 0,
--   }
-- elseif vim.env.SSH_TTY then
if vim.env.SSH_TTY then
  -- Fallback to OSC 52 if Termux API is not available and we are on SSH
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    -- paste = {
    --   ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
    --   ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    -- },
    --
    paste = {                                               
      ["+"] = { termux_api_dir .. "termux-clipboard-get" }, 
      ["*"] = { termux_api_dir .. "termux-clipboard-get" }, 
    },                                                      
    cache_enabled = 0,                                      
  }
end
