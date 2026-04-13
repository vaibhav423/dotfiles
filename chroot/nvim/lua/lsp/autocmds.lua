return {
  lsp_codelens_refresh = {
    cond = "textDocument/codeLens",
    {
      event = { "InsertLeave", "BufEnter" },
      desc = "Refresh codelens (buffer)",
      callback = function(args)
        if require("astrolsp").config.features.codelens then
          vim.lsp.codelens.refresh { bufnr = args.buf }
        end
      end,
    },
  },
}
