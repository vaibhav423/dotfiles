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
        loader.lazy_load()
        pcall(function()
          loader.load({ paths = {
            vim.fn.stdpath("config") .. "/lua/snippets",
            vim.fn.stdpath("config") .. "/lua/common/snippets",
          } })
        end)
      end
    end,
  },
}
