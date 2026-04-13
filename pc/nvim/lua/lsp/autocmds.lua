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
  json_path = {
    cond = "textDocument/documentSymbol",
    {
      event = "BufEnter",
      desc = "JSON path via LSP document symbols",
      callback = function(args)
        if vim.bo[args.buf].filetype ~= "json" then return end
        
        vim.keymap.set("n", "yp", function()
          local bufnr = args.buf
          local cursor = vim.api.nvim_win_get_cursor(0)
          local cursor_line = cursor[1] - 1
          local cursor_col = cursor[2]

          local clients = vim.lsp.get_clients { bufnr = bufnr, method = "textDocument/documentSymbol" }
          if #clients == 0 then
            vim.notify("No LSP client with documentSymbol support", vim.log.levels.WARN)
            return
          end

          local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
          clients[1].request("textDocument/documentSymbol", params, function(err, symbols)
            if err or not symbols then
              vim.notify("LSP error: " .. tostring(err), vim.log.levels.ERROR)
              return
            end

            local path = {}

            local function in_range(range)
              local sl, sc = range.start.line, range.start.character
              local el, ec = range["end"].line, range["end"].character
              if cursor_line < sl or cursor_line > el then return false end
              if cursor_line == sl and cursor_col < sc then return false end
              if cursor_line == el and cursor_col > ec then return false end
              return true
            end

            local function walk(syms)
              for _, sym in ipairs(syms) do
                if in_range(sym.range) then
                  table.insert(path, sym.name)
                  if sym.children and #sym.children > 0 then walk(sym.children) end
                  return
                end
              end
            end

            walk(symbols)

            if #path == 0 then
              vim.notify("No JSON path at cursor", vim.log.levels.WARN)
              return
            end

            local result = "." .. table.concat(path, ".")
            vim.fn.setreg("+", result)
            vim.notify("Copied: " .. result, vim.log.levels.INFO)
          end, bufnr)
        end, { desc = "Copy JSON path", buffer = args.buf })
      end,
    },
  },
}
