-- termux/nvim/lua/core/unq-autocmds.lua
-- Termux-specific autocommands that extend common.core.autocmds.

return {
  -- Clean up fold-toggle heading cache when a buffer is wiped
  fold_toggle_cleanup = {
    {
      event = "BufWipeout",
      desc = "Clear fold-toggle heading cache for wiped buffer",
      callback = function(args) require("personal.fold_toggle").clear_cache(args.buf) end,
    },
  },
}
