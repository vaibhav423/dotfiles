-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    -- Configuration table of features provided by AstroLSP
    features = {
      codelens = true, -- enable/disable codelens refresh on start
      inlay_hints = false, -- enable/disable inlay hints on start
      semantic_tokens = true, -- enable/disable semantic token highlighting
    },
    -- customize lsp formatting options
    formatting = {
      -- control auto formatting on save
      format_on_save = {
        enabled = true, -- enable or disable format on save globally
        allow_filetypes = { -- enable format on save for specified filetypes only
          -- "go",
        },
        ignore_filetypes = { -- disable format on save for specified filetypes
          -- "python",
        },
      },
      disabled = { -- disable formatting capabilities for the listed language servers
        -- disable lua_ls formatting capability if you want to use StyLua to format your lua code
        -- "lua_ls",
      },
      timeout_ms = 1000, -- default format timeout
    },
    -- enable servers that you already have installed without mason
    servers = {
      "markdown-oxide",
    },
    -- customize language server configuration options passed to `lspconfig`
    config = {
      ["markdown-oxide"] = {
        cmd = { "/data/data/com.termux/files/home/.cargo/bin/markdown-oxide" },
        filetypes = { "markdown", "md", "mdx" },
        root_dir = require("lspconfig.util").root_pattern(".git", ".obsidian", ".moxide.toml"),
        capabilities = {
          workspace = {
            didChangeWatchedFiles = {
              dynamicRegistration = true,
            },
          },
        },
        init_options = {
          keyword_pattern = [[\(\k\| \|\/\|#\)\+]],
        },
      },
    },
    -- customize how language servers are attached
    handlers = {},
    -- Configure buffer local auto commands to add when attaching a language server
    autocmds = {
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
    },
    -- mappings to be set up on attaching of a language server
    mappings = {
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
      },
    },
    -- A custom `on_attach` function to be run after the default `on_attach` function
    on_attach = function(client, bufnr)
      -- Setup markdown-oxide helpers when the server attaches
      if client.name == "markdown-oxide" or client.name == "markdown_oxide" then
        -- create a buffer-local user command `:Daily`
        vim.api.nvim_buf_create_user_command(bufnr, "Daily", function(opts)
          local params = { command = "jump" }
          if opts.args and opts.args ~= "" then
            params.arguments = { opts.args }
          end

          client.request("workspace/executeCommand", params, function(err, _)
            if err then
              vim.notify("markdown-oxide: " .. vim.inspect(err), vim.log.levels.ERROR)
            end
          end, bufnr)
        end, { desc = "Open markdown-oxide daily note", nargs = "*" })

        -- buffer-local mapping to open today's daily note quickly
        vim.keymap.set("n", "<Leader>od", "<cmd>Daily<cr>", { desc = "Open daily note", buffer = bufnr })
      end
    end,
  },
}
