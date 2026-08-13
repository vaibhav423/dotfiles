-- https://github.com/AstroNvim/astrocommunity/blob/main/lua/astrocommunity/ai/codecompanion-nvim/init.lua
-- https://github.com/olimorris/codecompanion.nvim
-- ~/.local/share/nvim/lazy/codecompanion.nvim/README.md
local prefix = "<Leader>k"

return {
  "olimorris/codecompanion.nvim",
  event = "User AstroFile",
  cmd = {
    "CodeCompanion",
    "CodeCompanionActions",
    "CodeCompanionChat",
    "CodeCompanionCmd",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    interactions = {
      chat = {
        -- adapter = "gemini_cli",
        -- https://codecompanion.olimorris.dev/configuration/adapters-http#github-copilot-free-student
        adapter = "copilot",
        model = "auto",
      },
      inline = {
        -- adapter = "gemini_cli",
        adapter = "copilot",
        model = "auto"
      },
    },
    adapters = {
      -- local Gemini-FastAPI (localhost:8000) via OpenAI-compatible endpoint
      http = {
        gemini_local = function()
          return require("codecompanion.adapters").extend("openai_compatible", {
            env = {
              url = "http://localhost:8000",
              api_key = "gemini-local",
              chat_url = "/v1/chat/completions",
              models_endpoint = "/v1/models",
            },
            headers = {
              ["Content-Type"] = "application/json",
            },
          })
        end,
      },
      -- acp = {
      --   gemini_cli = function()
      --     return require("codecompanion.adapters").extend("gemini_cli", {
      --       commands = {
      --         default = {
      --           "gemini",
      --           "--acp",
      --         },
      --       },
      --       defaults = {
      --         model = "auto-gemini-3",
      --       },
      --     })
      --   end,
      -- },
    },
  },
  specs = {
    {
      "rebelot/heirline.nvim",
      optional = true,

      opts = function(_, opts)
        opts.statusline = opts.statusline or {}
        local spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
        local astroui = require "astroui.status.hl"
        table.insert(opts.statusline, {
          static = {
            n_requests = 0,
            spinner_index = 0,
            spinner_symbols = spinner_symbols,
            done_symbol = "✓",
          },
          init = function(self)
            if self._cc_autocmds then return end
            self._cc_autocmds = true
            vim.api.nvim_create_autocmd("User", {
              pattern = "CodeCompanionRequestStarted",
              callback = function()
                self.n_requests = self.n_requests + 1
                vim.cmd "redrawstatus"
              end,
            })
            vim.api.nvim_create_autocmd("User", {
              pattern = "CodeCompanionRequestFinished",
              callback = function()
                self.n_requests = math.max(0, self.n_requests - 1)
                vim.cmd "redrawstatus"
              end,
            })
          end,
          provider = function(self)
            if not package.loaded["codecompanion"] then return nil end
            local symbol
            if self.n_requests > 0 then
              self.spinner_index = (self.spinner_index % #self.spinner_symbols) + 1
              symbol = self.spinner_symbols[self.spinner_index]
            else
              symbol = self.done_symbol
              self.spinner_index = 0
            end
            return ("%d %s"):format(self.n_requests, symbol)
          end,
          hl = function() return astroui.filetype_color() end,
        })
      end,
    },
    { "AstroNvim/astroui", opts = { icons = { CodeCompanion = "󱙺" } } },
    {
      "AstroNvim/astrocore",
      opts = function(_, opts)
        if not opts.mappings then opts.mappings = {} end
        opts.mappings.n = opts.mappings.n or {}
        opts.mappings.v = opts.mappings.v or {}
        opts.mappings.n[prefix] = { desc = require("astroui").get_icon("CodeCompanion", 1, true) .. "CodeCompanion" }
        opts.mappings.v[prefix] = { desc = require("astroui").get_icon("CodeCompanion", 1, true) .. "CodeCompanion" }
        opts.mappings.n[prefix .. "c"] = { "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle chat" }
        opts.mappings.v[prefix .. "c"] = { "<cmd>CodeCompanionChat Toggle<cr>", desc = "Toggle chat" }
        opts.mappings.n[prefix .. "p"] = { "<cmd>CodeCompanionActions<cr>", desc = "Open action palette" }
        opts.mappings.v[prefix .. "p"] = { "<cmd>CodeCompanionActions<cr>", desc = "Open action palette" }
        opts.mappings.n[prefix .. "q"] = { "<cmd>CodeCompanion<cr>", desc = "Open inline assistant" }
        opts.mappings.v[prefix .. "q"] = { "<cmd>CodeCompanion<cr>", desc = "Open inline assistant" }
        opts.mappings.v[prefix .. "a"] = { "<cmd>CodeCompanionChat Add<cr>", desc = "Add selection to chat" }
      end,
    },
    {
      "MeanderingProgrammer/render-markdown.nvim",
      optional = true,
      opts = function(_, opts)
        if not opts.file_types then opts.file_types = { "markdown" } end
        opts.file_types = require("astrocore").list_insert_unique(opts.file_types, { "codecompanion" })
      end,
    },
  },
}
