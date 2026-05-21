-- termux/nvim/lua/core/unq-mappings.lua
-- Termux-specific keymaps that extend/override common.core.mappings.
-- AstroCore merges this on top of the common table via pcall in common.astro.astrocore.

-- Helpers needed for save-on-escape (must redeclare here since helpers are local to common)
local ESCAPE_EXCLUDED_FT = {
  "TelescopePrompt", "TelescopeResults", "lazy", "NvimTree",
  "neo-tree", "fzf", "alpha", "packer", "Trouble",
}
local function escape_excluded()
  if vim.bo.buftype ~= "" then return true end
  for _, ft in ipairs(ESCAPE_EXCLUDED_FT) do
    if vim.bo.filetype == ft then return true end
  end
  return false
end
local function save_if_modified()
  if not escape_excluded() and not vim.bo.readonly and vim.bo.modifiable and vim.bo.modified then
    vim.schedule(function() vim.cmd("silent! update") end)
  end
end

return {
  -- Insert mode: save on Esc (useful on mobile — no dedicated Esc key)
  i = {
    ["<Esc>"] = {
      function()
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
        if escape_excluded() or vim.bo.readonly or not vim.bo.modifiable then
          vim.api.nvim_feedkeys(esc, "n", true)
          return
        end
        vim.api.nvim_feedkeys(esc, "n", true)
        save_if_modified()
      end,
      desc = "Exit insert and save",
    },
  },

  -- Terminal mode: save on Esc
  t = {
    ["<Esc>"] = {
      function()
        local seq = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
        vim.api.nvim_feedkeys(seq, "n", true)
        save_if_modified()
      end,
      desc = "Exit terminal mode and save",
    },
  },

  n = {
    -- Override: documents live on sdcard in Termux
    ["<Leader>fd"] = {
      function() require("snacks").picker.files({ dirs = { "/sdcard/Documents" } }) end,
      desc = "Find documents files",
    },

    -- Override: LspRestart command name differs in Termux AstroNvim version
    ["<Leader>rl"] = { "<cmd>LspRestart<CR>", desc = "Restart LSP" },

    -- Override: Copilot toggle uses the suggestion API (auto_trigger disabled globally)
    ["<Leader>tc"] = {
      function()
        local ok, suggestion = pcall(require, "copilot.suggestion")
        if not ok then
          vim.notify("Copilot plugin not loaded", vim.log.levels.WARN)
          return
        end
        suggestion.toggle_auto_trigger()
      end,
      desc = "Toggle Copilot auto-trigger",
    },

    -- Code runner (only installed in Termux)
    ["<Leader>rb"]  = { ":w<CR>:RunFile better_term<CR>", desc = "Run file in terminal" },
    ["<Leader>rf"]  = { ":RunFile<CR>",                   desc = "Run file" },
    ["<Leader>rft"] = { ":RunFile tab<CR>",               desc = "Run file (tab)" },
    ["<Leader>rp"]  = { ":RunProject<CR>",                desc = "Run project" },

    -- Tasker broadcast (Android-only)
    ["<Leader>rt"] = {
      ":silent !am broadcast -a net.dinglisch.android.tasker.ACTION_TASK -e task_name youtube_img_url_mode_toggle<CR><CR>",
      desc = "Run Tasker task",
    },

    -- Open gallery path in MixPlorer via Android intent (normal mode)
    ["<Leader>gg"] = {
      function()
        local gallery_line = vim.fn.search("^#\\+\\s\\+\\cgallery\\s*$", "nw")
        if gallery_line == 0 then
          vim.notify("No # gallery heading found", vim.log.levels.WARN)
          return
        end

        local next_heading = vim.fn.search("^#\\+\\s\\+", "nW", gallery_line + 1)
        local end_line = (next_heading > 0) and (next_heading - 1) or -1
        local lines = vim.api.nvim_buf_get_lines(0, gallery_line, end_line, false)

        local rel_path = nil
        for _, line in ipairs(lines) do
          local p = line:match("^%s*path:%s*(.+)%s*$")
          if p then rel_path = p; break end
        end

        if not rel_path then
          vim.notify("No path: found under # gallery heading", vim.log.levels.WARN)
          return
        end

        rel_path = rel_path:gsub("[\r\n%s]+$", "")
        local full_path = vim.fn.getcwd() .. "/" .. rel_path
        local cmd = string.format(
          'am start -a android.intent.action.VIEW -d "file://%s" -t "resource/folder" -f 0x14000000 com.mixplorer',
          full_path
        )
        vim.notify("Opening: " .. full_path)
        vim.fn.jobstart(cmd)
      end,
      desc = "Open gallery path in MixPlorer",
    },
  },

  -- Visual mode
  v = {
    -- Copy visually selected images to tmp dir and open in MixPlorer
    ["<Leader>gg"] = {
      ":<C-u>'<,'>OpenImages<CR>",
      desc = "Copy selected images to tmp dir and open in MixPlorer",
    },
  },
}
