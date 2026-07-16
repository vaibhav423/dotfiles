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
  -- https://github.com/kawre/leetcode.nvim
  -- https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/game/leetcode-nvim/init.lua
  { import = "astrocommunity.game.leetcode-nvim" },
  -- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/code-runner/compiler-nvim/init.lua
  -- https://github.com/Zeioth/compiler.nvim/
  -- { import = "astrocommunity.code-runner.compiler-nvim" },
}
