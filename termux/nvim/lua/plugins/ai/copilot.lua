return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  build = ":Copilot auth",
  event = "BufReadPost",
  opts = {
    suggestion = {
      enabled = true,
      -- default to disabled globally; we'll enable per-buffer for specific filetypes
      auto_trigger = false,
      keymap = {
        accept = false, -- handled by completion engine
        accept_word = false,
        accept_line = false,
        next = false,
        prev = false,
        dismiss = false,
      },
    },
    filetypes = {
      ["*"] = true, -- enable plugin for all filetypes (but not auto_trigger)
    },
  },
  config = function(_, opts)
    require("copilot").setup(opts)

    -- Ensure Copilot's auto_trigger is enabled only for markdown & zsh buffers
    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
      pattern = "*",
      callback = function()
        local ok, suggestion = pcall(require, "copilot.suggestion")
        if not ok then
          return
        end
        local ft = vim.bo.filetype
        local should_enable = (ft == "markdown" or ft == "zsh")
        -- buffer-local state set by copilot is stored in vim.b.copilot_suggestion_auto_trigger
        local current_state = vim.b.copilot_suggestion_auto_trigger
        if should_enable then
          if current_state ~= true then
            suggestion.toggle_auto_trigger()
          end
        else
          if current_state == true then
            suggestion.toggle_auto_trigger()
          end
        end
      end,
    })
  end,
  specs = {
    {
      "AstroNvim/astrocore",
      opts = {
        options = {
          g = {
            -- set the ai_accept function
            ai_accept = function()
              if require("copilot.suggestion").is_visible() then
                require("copilot.suggestion").accept()
                return true
              end
            end,
          },
        },
      },
    },
  },
}
