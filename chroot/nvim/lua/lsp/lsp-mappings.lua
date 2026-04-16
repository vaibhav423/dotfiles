return {
  n = {
    gD = {
      function()
        vim.lsp.buf.declaration()
      end,
      desc = "Declaration of current symbol",
      cond = "textDocument/declaration",
    },
    ["<Leader>uY"] = {
      function()
        require("astrolsp.toggles").buffer_semantic_tokens()
      end,
      desc = "Toggle LSP semantic highlight (buffer)",
      cond = function(client)
        return client.supports_method "textDocument/semanticTokens/full" and vim.lsp.semantic_tokens ~= nil
      end,
    },
    ["<Leader>lr"] = {
      "<Cmd>Lspsaga finder<CR>",
      desc = "Search references",
      cond = function(client)
        return client.supports_method "textDocument/references"
          or client.supports_method "textDocument/implementation"
      end,
    },
    ["<Leader>lR"] = {
      "<Cmd>Lspsaga rename<CR>",
      desc = "Rename symbol",
      cond = function(client) return client.supports_method "textDocument/rename" end,
    },
    -- to rewrite la which is modified by community lspsaga pluginn causing error
    ["<Leader>la"] = {
      function() vim.lsp.buf.code_action() end,
      desc = "LSP code action",
      cond = "textDocument/codeAction",
    },
  },
  x = {
    -- to rewrite la which is modified by community lspsaga pluginn causing error
    ["<Leader>la"] = {
      function() vim.lsp.buf.code_action() end,
      desc = "LSP code action",
      cond = "textDocument/codeAction",
    },
  },
}
