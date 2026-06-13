-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.
-- https://docs.astronvim.com/
-- https://astronvim.github.io/astrocommunity/

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- { import = "astrocommunity.pack.lua" },
  -- { import = "astrocommunity.ai.opencode-nvim" },
  -- import/override with your plugins folder
  -- https://github.com/MeanderingProgrammer/render-markdown.nvim
  -- https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/markdown-and-latex/render-markdown-nvim/init.lua
  { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },
  { import = "astrocommunity.recipes.ai" },
  -- https://nvimdev.github.io/lspsaga/
  { import = "astrocommunity.lsp.lspsaga-nvim" },
}
