-- AstroCore: central configuration for options, autocmds, and mappings.
-- Mappings live in lua/lib/mappings.lua — add new keymaps there.
-- Documentation: `:h astrocore`

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = function(_, opts)
    -- Core feature toggles
    opts.features = vim.tbl_deep_extend("force", opts.features or {}, {
      large_buf = { size = 1024 * 500, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    })

    -- vim.diagnostic.config() values when diagnostics are enabled
    opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
      virtual_text = true,
      underline = true,
    })

    -- Vim options
    opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = false,
        clipboard = "unnamedplus",
      },
      g = {},
    })

    -- Autocommands
    opts.autocmds = vim.tbl_deep_extend("force", opts.autocmds or {}, {
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
    })

    -- Mappings (see lua/lib/mappings.lua)
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, require("lib.mappings"))

    return opts
  end,
}
