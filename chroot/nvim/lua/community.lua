-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.
-- https://astronvim.github.io/astrocommunity/
-- https://github.com/sudo-tee/opencode.nvim opencode
-- https://github.com/nickjvandyke/opencode.nvim  opencode-tui
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
  -- https://astronvim.github.io/astrocommunity/#avante-nvim
  -- { import = "astrocommunity.ai.avante-nvim" },
  -- https://astronvim.github.io/astrocommunity/#copilotchat-nvim
  -- { import = "astrocommunity.ai.copilotchat-nvim" },
  -- { import = "astrocommunity.ai.codecompanion-nvim" },
}
