---@type LazySpec
return {

  -- vimtex: used only for math zone detection (in_mathzone condition)
  -- all compilation/LSP/viewer features are disabled
  {
    "lervag/vimtex",
    ft = { "tex", "latex", "markdown" },
    init = function()
      vim.g.vimtex_compiler_enabled = 0
      vim.g.vimtex_view_enabled = 0
      vim.g.vimtex_imaps_enabled = 0
      vim.g.vimtex_doc_enabled = 0
      vim.g.vimtex_syntax_enabled = 1  -- required for in_mathzone()
      vim.g.vimtex_syntax_conceal_disable = 1
    end,
  },

  -- LaTeX snippets for LuaSnip (requires vimtex for math zone detection)
  {
    "evesdropper/luasnip-latex-snippets.nvim",
    ft = { "tex", "latex", "markdown" },
    dependencies = { "L3MON4D3/LuaSnip", "lervag/vimtex" },
  },

  -- Extend LuaSnip so markdown buffers load tex/latex snippets
  {
    "L3MON4D3/LuaSnip",
    optional = true,
    config = function(plugin, opts)
      require("astronvim.plugins.configs.luasnip")(plugin, opts)
      local luasnip = require("luasnip")
      luasnip.filetype_extend("markdown", { "tex", "latex" })
      -- Load user snippets from lua/snippets (this repo path resolves via stdpath)
      local ok_loader, loader = pcall(require, "luasnip.loaders.from_lua")
      if ok_loader and loader then
        -- Let the loader search the runtimepath for `lua/snippets` folders.
        -- Calling lazy_load() with no args is the recommended approach and
        -- avoids hardcoding paths that may differ between machines.
        loader.lazy_load()
        -- Also explicitly load snippets from the user's config `lua/snippets`
        -- directory to make loading deterministic (covers timing/path edge cases).
        pcall(function()
          loader.load({ paths = vim.fn.stdpath("config") .. "/lua/snippets" })
        end)
      end
    end,
  },

-- Auto-close $...$ in markdown and tex
--   {
--     "windwp/nvim-autopairs",
--     optional = true,
--     config = function(plugin, opts)
--       require("astronvim.plugins.configs.nvim-autopairs")(plugin, opts)
--       local npairs = require("nvim-autopairs")
--       local Rule = require("nvim-autopairs.rule")
--       local cond = require("nvim-autopairs.conds")
--       npairs.add_rules({
--         Rule("$", "$", { "tex", "latex", "markdown" })
--           :with_pair(cond.not_after_regex("%%"))
--           :with_move(cond.none())
--           :with_del(cond.not_after_regex("xx"))
--           :with_cr(cond.none()),
--       })
--     end,
--   },
--
 }
