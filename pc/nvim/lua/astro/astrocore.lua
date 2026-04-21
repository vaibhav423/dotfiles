-- AstroCore: central configuration for options, autocmds, and mappings.
-- Mappings live in lua/personal/mappings.lua — add new keymaps there.
-- normally u dont need opts = function(-, opts) way for astrocore but since we need to merge table from different 
-- file it is necessity
-- Documentation: `:h astrocore`
-- https://github.com/AstroNvim/astrocore#%EF%B8%8F-configuration

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
        -- clipboard handled lazily; see init.lua VimEnter autocmd
      },
      g = {
        -- copilot_chat_prefix = "<Leader>a",
      },
    })
    -- commands
    opts.commands = vim.tbl_deep_extend("force", opts.commands or {}, require("core.commands"))
    opts.commands = vim.tbl_deep_extend("force", opts.commands or {}, require("core.unq-commands"))

    -- Autocommands
    opts.autocmds = vim.tbl_deep_extend("force", opts.autocmds or {}, require("core.autocmds"))
    opts.autocmds = vim.tbl_deep_extend("force", opts.autocmds or {}, require("core.unq-autocmds"))

    -- Mappings 
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, require("core.mappings"))
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, require("core.unq-mappings"))

    return opts
  end,
}
