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
			-- filter = function(client) -- fully override the default formatting function
			--   return true
			-- end
		},
		-- enable servers that you already have installed without mason
		servers = {
			-- "pyright"
			-- "markdown-oxide",
			--    "texlab",
		},
		-- customize language server configuration options passed to `lspconfig`
		---@diagnostic disable: missing-fields
		config = {
			-- clangd = { capabilities = { offsetEncoding = "utf-8" } },
			-- ["markdown-oxide"] = {
			--	cmd = { "markdown-oxide" },
				-- filetypes = { "tex", "bib", "markdown" },
			--	root_dir = require("lspconfig.util").root_pattern(".git", ".obsidian", ".moxide.toml"),
			--},
			--   texlab = {
			--     cmd = { "texlab" }, -- Force Neovim to use the Termux-installed binary
			--     filetypes = { "tex", "bib", "markdown" },
			--     on_attach = function(client, bufnr)
			--       -- Ensure texlab does not provide folding (avoid race conditions)
			--       client.server_capabilities.foldingRangeProvider = false
			--       client.server_capabilities["foldingRangeProvider"] = false
			--       if client.server_capabilities.textDocument then
			--         client.server_capabilities.textDocument.foldingRange = nil
			--       end
			--     end,
			--   },
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
						if require("astrolsp").config.features.codelens then
							vim.lsp.codelens.refresh({ bufnr = args.buf })
						end
					end,
				},
			},

			-- Ensure treesitter folding remains active per-buffer for tex/markdown
			force_treesitter_folds = {
				cond = true,
				{
					event = { "BufEnter", "BufReadPost" },
					desc = "Force treesitter folding for tex/markdown buffers",
					callback = function(args)
						local ok, ft = pcall(vim.api.nvim_buf_get_option, args.buf, "filetype")
						if ok and (ft == "markdown" or ft == "tex") then
							pcall(vim.api.nvim_buf_set_option, args.buf, "foldmethod", "expr")
							pcall(vim.api.nvim_buf_set_option, args.buf, "foldexpr", "nvim_treesitter#foldexpr()")
						end
					end,
				},
			},

			-- Disable folding capabilities from LSPs that override treesitter folds
			disable_lsp_folding = {
				cond = true,
				{
					event = { "LspAttach" },
					desc = "Disable folding from LSPs that override treesitter foldexpr",
					callback = function(args)
						local client = vim.lsp.get_client_by_id(args.data.client_id)
						if not client then
							return
						end
						local lsp_names = { texlab = true, ["markdown-oxide"] = true }
						if lsp_names[client.name] then
							client.server_capabilities.foldingRangeProvider = false
							client.server_capabilities["foldingRangeProvider"] = false
							if client.server_capabilities.textDocument then
								client.server_capabilities.textDocument.foldingRange = nil
							end
							-- Reset folds_restored so fold_persist can re-run after treesitter settles
							vim.b[args.buf].folds_restored = nil
							require("fold_persist").restore(args.buf)
						end
					end,
				},
			},
		},

		-- mappings to be set up on attaching of a language server
		mappings = {
			n = {
				-- a `cond` key can provided as the string of a server capability to be required to attach, or a function with `client` and `bufnr` parameters from the `on_attach` that returns a boolean
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
						return client.supports_method("textDocument/semanticTokens/full")
							and vim.lsp.semantic_tokens ~= nil
					end,
				},
			},
		},
		-- A custom `on_attach` function to be run after the default `on_attach` function
		-- takes two parameters `client` and `bufnr`  (`:h lspconfig-setup`)
		on_attach = function(client, bufnr)
			-- this would disable semanticTokensProvider for all clients
			-- client.server_capabilities.semanticTokensProvider = nil
		end,
	},
}
