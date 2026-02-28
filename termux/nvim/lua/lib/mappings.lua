-- lib/mappings.lua: all global keymaps for astrocore.
-- Add new mappings here. astrocore.lua merges this into opts.mappings.

-- ---------------------------------------------------------------------------
-- Helpers (save-on-escape)
-- ---------------------------------------------------------------------------

-- Filetypes / buftypes that should never trigger save-on-escape
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

-- ---------------------------------------------------------------------------
-- Mappings table (returned for use in astrocore opts.mappings)
-- ---------------------------------------------------------------------------

return {
  -- Insert mode ---------------------------------------------------------------
  i = {
    -- Exit insert mode and save if modified
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

  -- Terminal mode -------------------------------------------------------------
  t = {
    -- Exit terminal mode and save if modified
    ["<Esc>"] = {
      function()
        local seq = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
        vim.api.nvim_feedkeys(seq, "n", true)
        save_if_modified()
      end,
      desc = "Exit terminal mode and save",
    },
  },

  -- Normal mode ---------------------------------------------------------------
  n = {
    -- Buffers
    ["<Tab>"]      = { function() require("astrocore.buffer").nav(vim.v.count1) end,  desc = "Next buffer" },
    ["<S-Tab>"]    = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
    ["<Leader>bd"] = {
      function()
        require("astroui.status.heirline").buffer_picker(
          function(bufnr) require("astrocore.buffer").close(bufnr) end
        )
      end,
      desc = "Close buffer from tabline",
    },

    -- LSP
    ["<Leader>rl"] = { "<cmd>LspRestart<CR>", desc = "Restart LSP" },

    -- Code runner
    ["<Leader>rt"]  = { ":w<CR>:RunCode<CR>",              desc = "Run code (float)" },
    ["<Leader>rb"]  = { ":w<CR>:RunFile better_term<CR>",  desc = "Run file in terminal" },
    ["<Leader>rf"]  = { ":RunFile<CR>",                    desc = "Run file" },
    ["<Leader>rft"] = { ":RunFile tab<CR>",                desc = "Run file (tab)" },
    ["<Leader>rp"]  = { ":RunProject<CR>",                 desc = "Run project" },

    -- Copilot
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

    -- Jeerem reminder
    ["<Leader>jr"] = { "<cmd>Jeerem<CR>", desc = "Insert reminder on first line" },

    -- File finder (documents)
    ["<Leader>fd"] = {
      function()
        require("snacks").picker.files({ dirs = { "/storage/emulated/0/Documents" } })
      end,
      desc = "Find documents files",
    },

    -- Fold level toggles (current window)
    ["z1"] = { function() require("lib.fold_toggle").toggle(1) end, desc = "Toggle fold level 1" },
    ["z2"] = { function() require("lib.fold_toggle").toggle(2) end, desc = "Toggle fold level 2" },
    ["z3"] = { function() require("lib.fold_toggle").toggle(3) end, desc = "Toggle fold level 3" },
    ["z4"] = { function() require("lib.fold_toggle").toggle(4) end, desc = "Toggle fold level 4" },

    -- Fold level toggles (all windows in tabpage)
    ["<Leader>z1"] = { function() require("lib.fold_toggle").toggle_all(1) end, desc = "Toggle fold level 1 (all windows)" },
    ["<Leader>z2"] = { function() require("lib.fold_toggle").toggle_all(2) end, desc = "Toggle fold level 2 (all windows)" },
    ["<Leader>z3"] = { function() require("lib.fold_toggle").toggle_all(3) end, desc = "Toggle fold level 3 (all windows)" },
    ["<Leader>z4"] = { function() require("lib.fold_toggle").toggle_all(4) end, desc = "Toggle fold level 4 (all windows)" },
  },
}
