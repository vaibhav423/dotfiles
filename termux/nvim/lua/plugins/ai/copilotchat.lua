local prefix = "<Leader>a"
local old_prefix = "<Leader>P"

return {
  -- Model override
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      model = "gpt-5-mini",
    },
  },

  -- Re-register all CopilotChat maps under <Leader>a, clear <Leader>P ones.
  -- Runs after the community spec so it overwrites the prefix community hardcoded.
  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      local maps = assert(opts.mappings)
      local astroui = require "astroui"

      -- Clear old prefix group keys set by community spec
      maps.n[old_prefix] = false
      maps.v[old_prefix] = false
      maps.n[old_prefix .. "o"] = false
      maps.n[old_prefix .. "c"] = false
      maps.n[old_prefix .. "t"] = false
      maps.n[old_prefix .. "r"] = false
      maps.n[old_prefix .. "s"] = false
      maps.n[old_prefix .. "S"] = false
      maps.n[old_prefix .. "L"] = false
      maps.n[old_prefix .. "p"] = false
      maps.v[old_prefix .. "p"] = false
      maps.n[old_prefix .. "q"] = false
      maps.v[old_prefix .. "q"] = false

      -- Re-register under new prefix
      maps.n[prefix] = { desc = astroui.get_icon("CopilotChat", 1, true) .. "CopilotChat" }
      maps.v[prefix] = { desc = astroui.get_icon("CopilotChat", 1, true) .. "CopilotChat" }

      maps.n[prefix .. "o"] = { ":CopilotChatOpen<CR>", desc = "Open Chat" }
      maps.n[prefix .. "c"] = { ":CopilotChatClose<CR>", desc = "Close Chat" }
      maps.n[prefix .. "t"] = { ":CopilotChatToggle<CR>", desc = "Toggle Chat" }
      maps.n[prefix .. "r"] = { ":CopilotChatReset<CR>", desc = "Reset Chat" }
      maps.n[prefix .. "s"] = { ":CopilotChatStop<CR>", desc = "Stop Chat" }

      maps.n[prefix .. "S"] = {
        function()
          vim.ui.input({ prompt = "Save Chat: " }, function(input)
            if input ~= nil and input ~= "" then require("CopilotChat").save(input) end
          end)
        end,
        desc = "Save Chat",
      }

      maps.n[prefix .. "L"] = {
        function()
          local copilot_chat = require "CopilotChat"
          local path = copilot_chat.config.history_path
          local chats = require("plenary.scandir").scan_dir(path, { depth = 1, hidden = true })
          for i, chat in ipairs(chats) do
            chats[i] = chat:sub(#path + 2, -6)
          end
          vim.ui.select(chats, { prompt = "Load Chat: " }, function(selected)
            if selected ~= nil and selected ~= "" then copilot_chat.load(selected) end
          end)
        end,
        desc = "Load Chat",
      }

      local function select_action(selection_type)
        return function()
          require("CopilotChat").select_prompt { selection = require("CopilotChat.select")[selection_type] }
        end
      end

      maps.n[prefix .. "p"] = { select_action "buffer", desc = "Prompt actions" }
      maps.v[prefix .. "p"] = { select_action "visual", desc = "Prompt actions" }

      local function quick_chat(selection_type)
        return function()
          vim.ui.input({ prompt = "Quick Chat: " }, function(input)
            if input ~= nil and input ~= "" then
              require("CopilotChat").ask(input, { selection = require("CopilotChat.select")[selection_type] })
            end
          end)
        end
      end

      maps.n[prefix .. "q"] = { quick_chat "buffer", desc = "Quick Chat" }
      maps.v[prefix .. "q"] = { quick_chat "visual", desc = "Quick Chat" }

      return opts
    end,
  },
}
