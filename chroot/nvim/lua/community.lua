-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.
-- link https://astronvim.github.io/astrocommunity/
---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- { import = "astrocommunity.pack.lua" }, -- Disabled: lua-language-server and stylua not supported on this platform
  -- import/override with your plugins folder
  { import = "astrocommunity.recipes.ai" },
  { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },
  -- { import = "astrocommunity.editing-support.copilotchat-nvim" },
  { import = "astrocommunity.completion.cmp-latex-symbols" },
  { import = "astrocommunity.lsp.lspsaga-nvim" },
  { import = "astrocommunity.completion.avante-nvim" },
}
