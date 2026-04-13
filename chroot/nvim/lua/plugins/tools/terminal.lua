if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE
-- Terminal and code execution tools


---@type LazySpec
return {

  -- Enhanced terminal with tabs and named sessions
  {
    "CRAG666/betterTerm.nvim",
    opts = {},
    keys = {
      { "<C-;>", function() require("betterTerm").open() end, mode = { "n", "t" }, desc = "Toggle terminal" },
      { "<C-/>", function() require("betterTerm").open(1) end, mode = { "n", "t" }, desc = "Toggle terminal 1" },
      { "<leader>tt", function() require("betterTerm").select() end, desc = "Select terminal" },
      { "<leader>tr", function() require("betterTerm").rename() end, desc = "Rename terminal" },
      { "<leader>tb", function() require("betterTerm").toggle_tabs() end, desc = "Toggle terminal tabs" },
    },
  },

  -- Run code files and projects from within Neovim
  {
    "CRAG666/code_runner.nvim",
    cmd = { "RunCode", "RunFile", "RunProject" },
    config = function()
      require("code_runner").setup({
        mode = "float",
        float = {
          border = "rounded",
          height = 0.4,
          width = 0.6,  
        },
        filetype = {
          python = "python3 -u $file",
          javascript = "node $file",
          typescript = "ts-node $file",
          lua = "lua $file",
          sh = "bash $file",
          c = "gcc $file -o $fileNameWithoutExt && ./$fileNameWithoutExt",
          cpp = "g++ $file -o $fileNameWithoutExt && ./$fileNameWithoutExt",
        },
      })
    end,
  },

}
