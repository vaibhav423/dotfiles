-- AstroCore: central configuration for options, autocmds, and mappings.
-- Mappings live in lua/personal/mappings.lua — add new keymaps there.
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
        -- clipboard handled lazily; see init.lua VimEnter autocmd
      },
      g = {
        copilot_chat_prefix = "<Leader>a",
      },
    })
    -- commands
    opts.commands = vim.tbl_deep_extend("force", opts.commands or {}, require("core.commands"))

    -- Autocommands
    opts.autocmds = vim.tbl_deep_extend("force", opts.autocmds or {}, require("core.autocmds"))

    -- Mappings 
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, require("core.mappings"))
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, require("core.mappings"))

    return opts
  end,
}
