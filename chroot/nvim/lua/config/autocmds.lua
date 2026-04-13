return {
      -- Fold persistence (save/restore fold state per buffer)
      fold_persistence = {
        {
          event = { "BufWinLeave", "BufLeave" },
          pattern = "?*",
          desc = "Save fold state when leaving buffer",
          callback = function(args) require("lib.fold_persist").save(args.buf) end,
        },
        {
          event = "BufReadPost",
          pattern = "?*",
          desc = "Clear fold restore flag when buffer is re-read",
          callback = function(args) vim.b[args.buf].folds_restored = nil end,
        },
        {
          event = { "BufWinEnter", "FileType" },
          pattern = "?*",
          desc = "Restore fold state after foldexpr is set up",
          callback = function(args) require("lib.fold_persist").restore(args.buf) end,
        },
      },

      -- Clean up fold-toggle heading cache when a buffer is wiped
      fold_toggle_cleanup = {
        {
          event = "BufWipeout",
          desc = "Clear fold-toggle heading cache for wiped buffer",
          callback = function(args) require("lib.fold_toggle").clear_cache(args.buf) end,
        },
      },
    }
