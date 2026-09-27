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
    "ravitemer/codecompanion-history.nvim",
  },
  opts = {
    interactions = {
      chat = {
        adapter = "gemini_local",
        model = "auto",
        slash_commands = {
          paste_image = {
            description = "Paste image from clipboard",
            callback = function(chat)
              local dir = vim.fn.expand("~/.cache/codecompanion_images")
              vim.fn.mkdir(dir, "p")

              local filename = os.time() .. ".png"
              local filepath = dir .. "/" .. filename

              local is_wayland = os.getenv("WAYLAND_DISPLAY") ~= nil
              local cmd = is_wayland
                and string.format("wl-paste --type image/png > %s", vim.fn.shellescape(filepath))
                or string.format("xclip -selection clipboard -t image/png -o > %s", vim.fn.shellescape(filepath))

              os.execute(cmd)

              local f = io.open(filepath, "r")
              if not f then
                vim.notify("No image found in clipboard", vim.log.levels.WARN)
                return
              end
              local size = f:seek("end")
              f:close()

              if size == 0 then
                vim.fn.delete(filepath)
                vim.notify("No image found in clipboard", vim.log.levels.WARN)
                return
              end

              chat:add_buf_message({
                role = "user",
                content = string.format("![image](%s)", filepath),
              })
            end,
          },
        },

        roles = {
          llm = function() return "gemini_local" end,
          user = "Me",
        },
      },
      inline = {
        adapter = "copilot",
        model = "auto",
      },
    },
    display = {
      chat = {
        intro_message = "",
      },
    },
    extensions = {
      history = {
        enabled = true,
        opts = {
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion_chats.json",
        },
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
  config = function(_, opts)
    require("codecompanion").setup(opts)

    -- Safely handle `vim.cmd("hide")` in single-window setups to prevent E444
    local shared_ui = require("codecompanion.interactions.shared.ui")
    local orig_hide = shared_ui.hide
    shared_ui.hide = function(winnr, bufnr, layout)
      if vim.api.nvim_get_current_buf() == bufnr then
        pcall(vim.cmd, "hide")
        return
      end
      orig_hide(winnr, bufnr, layout)
    end

    -- Fix Debug:save() not re-rendering the chat buffer + not persisting to history
    local debug = require("codecompanion.interactions.chat.debug")
    local orig_save = debug.save
    debug.save = function(self)
      orig_save(self)
      if self.chat and self.chat.ui and self.chat.ui:is_visible() then
        self.chat.ui:render(self.chat.buffer_context, self.chat.messages)
      end
      -- history extension only autosaves on submit/finish, so persist gd edits explicitly
      pcall(function()
        local cc = require("codecompanion")
        if cc.extensions and cc.extensions.history then
          cc.extensions.history.save_chat(self.chat)
        end
      end)
    end


    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeCompanionChatCreated",
      callback = function(args)
        local chat = require("codecompanion").buf_get_chat(args.data.bufnr)
        local win = vim.fn.bufwinid(args.data.bufnr)
        chat:add_callback("on_before_submit", function()
          if vim.api.nvim_win_is_valid(win) then
            vim.wo[win].winbar = " ⠋ thinking..."
          end
        end)
        chat:add_callback("on_ready", function()
          if vim.api.nvim_win_is_valid(win) then
            vim.wo[win].winbar = ""
          end
        end)
      end,
    })
  end,
  specs = {
    {
      "AstroNvim/astroui",
      opts = { icons = { CodeCompanion = "󱙺" } },
    },
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
