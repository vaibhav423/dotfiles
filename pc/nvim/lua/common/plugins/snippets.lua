---@type LazySpec
return {
  -- Central LuaSnip config: snippet loading mechanics live here, not in latex.lua
  {
    "L3MON4D3/LuaSnip",
    optional = true,
    config = function(plugin, opts)
      require("astronvim.plugins.configs.luasnip")(plugin, opts)
      local luasnip = require("luasnip")
      -- When editing a markdown file, also load snippets from tex/latex
      -- so that e.g. `\frac` or `ncr` triggers inside markdown math blocks.
      luasnip.filetype_extend("markdown", { "tex", "latex" })
      -- Load user snippets via the from_lua loader
      local ok_loader, loader = pcall(require, "luasnip.loaders.from_lua")
      if ok_loader and loader then
        -- 1. Plugin/runtimepath snippets (lowest priority)
        loader.lazy_load()
        -- 2. User snippets from lua/snippets
        pcall(loader.load, { paths = vim.fn.stdpath("config") .. "/lua/snippets" })
        -- 3. User snippets from lua/common/snippets (highest priority)
        pcall(loader.load, { paths = vim.fn.stdpath("config") .. "/lua/common/snippets" })
      end
    end,
  },
}
