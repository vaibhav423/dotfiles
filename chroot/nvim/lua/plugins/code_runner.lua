return {
  {
    "CRAG666/code_runner.nvim",
    config = function()
      require("code_runner").setup {
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
      }
    end,
  },
}
