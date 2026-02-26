
-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = vim.lsp.protocol.make_client_capabilities()
if cmp_ok and cmp_nvim_lsp and cmp_nvim_lsp.default_capabilities then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end
capabilities = vim.tbl_deep_extend("force", capabilities, {
  workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
})

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
      -- filter = function(client) -- fully override the default formatting function
      --   return true
      -- end
    },
    -- enable servers that you already have installed without mason
    servers = {
      "markdown-oxide"
      -- "pyright"
    },
    -- customize language server configuration options passed to `lspconfig`
    ---@diagnostic disable: missing-fields
    config = {
      ["markdown-oxide"] = vim.tbl_deep_extend("force", {
        cmd = {"/data/data/com.termux/files/home/.cargo/bin/markdown-oxide"},
        filetypes = {"markdown", "md", "mdx"},
        root_dir = function(fname, _)
          return require('lspconfig').util.root_pattern('.git', '.obsidian', '.moxide.toml')(fname)
        end,
      }, { capabilities = capabilities, settings = { markdown_oxide = { keyword_pattern = [[\(\k\| \|\/\|#\)\+]] } } }),
      -- clangd = { capabilities = { offsetEncoding = "utf-8" } },
    },
    -- customize how language servers are attached
    handlers = {
      -- a function without a key is simply the default handler, functions take two parameters, the server name and the configured options table for that server
      -- function(server, opts) require("lspconfig")[server].setup(opts) end

      -- the key is the server that is being setup with `lspconfig`
      -- rust_analyzer = false, -- setting a handler to false will disable the set up of that language server
      -- pyright = function(_, opts) require("lspconfig").pyright.setup(opts) end -- or a custom handler function can be passed
    },
    -- Configure buffer local auto commands to add when attaching a language server
    autocmds = {
      -- first key is the `augroup` to add the auto commands to (:h augroup)
      lsp_codelens_refresh = {
        -- Optional condition to create/delete auto command group
        -- can either be a string of a client capability or a function of `fun(client, bufnr): boolean`
        -- condition will be resolved for each client on each execution and if it ever fails for all clients,
        -- the auto commands will be deleted for that buffer
        cond = "textDocument/codeLens",
        -- cond = function(client, bufnr) return client.name == "lua_ls" end,
        -- list of auto commands to set
        {
          -- events to trigger
          event = { "InsertLeave", "BufEnter" },
          -- the rest of the autocmd options (:h nvim_create_autocmd)
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then vim.lsp.codelens.refresh { bufnr = args.buf } end
          end,
        },
      },
    },
    -- mappings to be set up on attaching of a language server
    mappings = {
      n = {
        -- a `cond` key can provided as the string of a server capability to be required to attach, or a function with `client` and `bufnr` parameters from the `on_attach` that returns a boolean
        gD = {
          function() vim.lsp.buf.declaration() end,
          desc = "Declaration of current symbol",
          cond = "textDocument/declaration",
        },
        ["<Leader>uY"] = {
          function() require("astrolsp.toggles").buffer_semantic_tokens() end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client.supports_method "textDocument/semanticTokens/full" and vim.lsp.semantic_tokens ~= nil
          end,
        },
      },
    },
    -- A custom `on_attach` function to be run after the default `on_attach` function
    -- takes two parameters `client` and `bufnr`  (`:h lspconfig-setup`)
    on_attach = function(client, bufnr)
      -- this would disable semanticTokensProvider for all clients
      -- client.server_capabilities.semanticTokensProvider = nil

      -- Setup markdown-oxide helpers when the server attaches
      if client.name == "markdown_oxide" or client.name == "markdown-oxide" then
        -- create a buffer-local user command `:Daily` that forwards its args to this client
        pcall(vim.api.nvim_buf_create_user_command, bufnr, "Daily", function(opts)
          local input = opts.args
          local params = { command = "jump" }
          if input and input ~= "" then
            params.arguments = { input }
          end

          -- ensure the specific client supports executeCommand/jump
          local exec = client.server_capabilities and client.server_capabilities.executeCommandProvider
          if exec and type(exec.commands) == "table" then
            local has_jump = false
            for _, cmd in ipairs(exec.commands) do
              if cmd == "jump" then has_jump = true; break end
            end
            if not has_jump then
              vim.notify("markdown-oxide server does not expose 'jump' command", vim.log.levels.WARN)
              return
            end
          end

          -- send request directly to the attached client
          pcall(function()
            client.request("workspace/executeCommand", params, function(err, res)
              if err then
                vim.notify(string.format("markdown-oxide executeCommand error (%s): %s", client.name, vim.inspect(err)), vim.log.levels.ERROR)
              end
            end, bufnr)
          end)
        end, { desc = "Open markdown-oxide daily note", nargs = "*" })

        -- buffer-local mapping to open today's daily note quickly (invokes the buffer-local :Daily)
        pcall(vim.keymap.set, "n", "<Leader>od", function()
          vim.cmd("Daily")
        end, { desc = "Open markdown-oxide daily note", buffer = bufnr })
      end
    end,
  },
}
