return {
    lsp_codelens_refresh = {
    cond = "textDocument/codeLens",
    {
      event = { "InsertLeave", "BufWritePost" },
      desc = "Refresh codelens (buffer)",
      callback = function(args)
        if require("astrolsp").config.features.codelens then
          vim.lsp.codelens.enable(true, { bufnr = bufnr })
        end
      end,
    },
  },
}
