return {

      -- Fold persistence (save/restore fold state per buffer)
      fold_persistence = {
        {
          event = { "BufWinLeave", "BufLeave" },
          pattern = "?*",
          desc = "Save fold state when leaving buffer",
          callback = function(args) require("personal.fold_persist").save(args.buf) end,
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
          callback = function(args) require("personal.fold_persist").restore(args.buf) end,
        },
      },

      -- -- Clean up fold-toggle heading cache when a buffer is wiped
      -- fold_toggle_cleanup = {
      --   {
      --     event = "BufWipeout",
      --     desc = "Clear fold-toggle heading cache for wiped buffer",
      --     callback = function(args)
      --       local ok, m = pcall(require, "personal.fold_toggle")
      --       if ok and m.clear_cache then m.clear_cache(args.buf) end
      --     end,
      --   },
      -- },

      -- Encryption support for .enc files
      encryption_plugin = {
        {
          event = "BufReadPost",
          pattern = "*.enc",
          desc = "Auto-decrypt when opening .enc files",
          callback = function()
            -- Disable swap files for encrypted files
            vim.opt_local.swapfile = false
            vim.opt_local.backup = false
            vim.opt_local.writebackup = false
            vim.opt_local.undofile = false
            
            require("personal.encryption").decrypt_buffer()
          end,
        },
        {
          event = "BufWriteCmd",
          pattern = "*.enc",
          desc = "Auto-encrypt when writing .enc files",
          callback = function()
            require("personal.encryption").encrypt_buffer()
          end,
        },
        {
          event = "BufDelete",
          pattern = "*.enc",
          desc = "Clear password cache when buffer is closed",
          callback = function()
            -- We cannot just call M.clear_password() easily without it prompting if not cached,
            -- but the original logic was:
            -- local filepath = vim.api.nvim_buf_get_name(0)
            -- password_cache[filepath] = nil
            -- Since password_cache is local to personal/encryption, we need a method to clear it by filepath
            -- or we just use M.clear_password() which does exactly that for the current buffer.
            require("personal.encryption").clear_password()
          end,
        },
      },
    }
