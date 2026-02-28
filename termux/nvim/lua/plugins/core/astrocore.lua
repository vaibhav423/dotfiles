-- AstroCore: central configuration for options, mappings, and autocommands.
-- Documentation: `:h astrocore`

-- Filetypes that should not trigger save-on-escape
local ESCAPE_EXCLUDED_FT = {
  "TelescopePrompt", "TelescopeResults", "lazy", "NvimTree",
  "neo-tree", "fzf", "alpha", "packer", "Trouble",
}

-- Returns true if the current buffer should be excluded from save-on-escape
local function escape_excluded()
  if vim.bo.buftype ~= "" then return true end
  for _, ft in ipairs(ESCAPE_EXCLUDED_FT) do
    if vim.bo.filetype == ft then return true end
  end
  return false
end

-- Shared save-on-exit logic (schedules a silent write if the buffer is modified)
local function save_if_modified()
  if not escape_excluded() and not vim.bo.readonly and vim.bo.modifiable and vim.bo.modified then
    vim.schedule(function() vim.cmd("silent! update") end)
  end
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Core feature toggles
    features = {
      large_buf = { size = 1024 * 500, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },

    -- vim.diagnostic.config() values when diagnostics are enabled
    diagnostics = {
      virtual_text = true,
      underline = true,
    },

    -- Vim options
    options = {
      opt = {
        relativenumber = true,
        number = true,
        spell = false,
        signcolumn = "yes",
        wrap = false,
        clipboard = "unnamedplus",
      },
      g = {},
    },

    -- Autocommands
    autocmds = {
      -- Fold persistence (save/restore fold state per buffer)
      fold_persistence = {
        {
          event = { "BufWinLeave", "BufLeave" },
          pattern = "?*",
          desc = "Save fold state when leaving buffer",
          callback = function(args) require("lib.fold_persist").save(args.buf) end,
        },
        {
          event = "BufReadPost",
          pattern = "?*",
          desc = "Clear fold restore flag when buffer is re-read",
          callback = function(args) vim.b[args.buf].folds_restored = nil end,
        },
        {
          event = { "BufWinEnter", "FileType" },
          pattern = "?*",
          desc = "Restore fold state after foldexpr is set up",
          callback = function(args) require("lib.fold_persist").restore(args.buf) end,
        },
      },

      -- Clean up fold-toggle heading cache when a buffer is wiped
      fold_toggle_cleanup = {
        {
          event = "BufWipeout",
          desc = "Clear fold-toggle heading cache for wiped buffer",
          callback = function(args) require("lib.fold_toggle").clear_cache(args.buf) end,
        },
      },
    },

    -- Mappings
    mappings = {
      -- Insert mode
      i = {
        -- Exit insert mode; save if the buffer was modified
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

      -- Terminal mode
      t = {
        -- Exit terminal mode; save if the buffer was modified
        ["<Esc>"] = {
          function()
            local seq = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
            vim.api.nvim_feedkeys(seq, "n", true)
            save_if_modified()
          end,
          desc = "Exit terminal mode and save",
        },
      },

      -- Normal mode
      n = {
        -- Buffer navigation
        ["<Tab>"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["<S-Tab>"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
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
        ["<Leader>rt"] = { ":w<CR>:RunCode<CR>", desc = "Run code (float)" },
        ["<Leader>rb"] = { ":w<CR>:RunFile better_term<CR>", desc = "Run file in terminal" },
        ["<Leader>rf"] = { ":RunFile<CR>", desc = "Run file" },
        ["<Leader>rft"] = { ":RunFile tab<CR>", desc = "Run file (tab)" },
        ["<Leader>rp"] = { ":RunProject<CR>", desc = "Run project" },

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
            require("snacks").picker.files({
              dirs = { "/storage/emulated/0/Documents" },
            })
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
    },
  },
}
