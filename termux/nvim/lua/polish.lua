-- polish.lua: runs after all plugins are loaded.
-- Used only for final setup that cannot live inside a plugin spec.

-- Encryption support for .enc files
require("lib.encryption").setup()

-- Jeerem date-countdown command
require("lib.jeerem").setup()

-- OSC 52 clipboard when connected over SSH
if vim.env.SSH_TTY then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end
